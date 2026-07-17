#!/usr/bin/env python3
"""
Spotify API integration for Quickshell NowPlayingMenu.
Handles OAuth2 authentication and provides recently played, current track, and queue data.

Credentials and tokens are stored exclusively in the system keyring (Secret Service /
KWallet via the `keyring` library).  No secrets are ever written to disk in plaintext.

Keyring layout (service = "quickshell-spotify"):
  username          | value
  ------------------|----------------------------------
  client_id         | Spotify app client ID
  client_secret     | Spotify app client secret
  access_token      | Current OAuth access token
  refresh_token     | OAuth refresh token
  expires_at        | Token expiry as Unix ms (string)

Only JSON payloads go to stdout; QML parses stdout and discards stderr.
No token, secret, or auth code reaches either stream.
"""

from __future__ import annotations

import base64
import contextlib
import fcntl
import getpass
import html
import json
import os
import secrets
import signal
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from collections.abc import Iterator
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Any

try:
    import keyring
    import keyring.errors
except ImportError:
    print(
        "Error: 'keyring' package not found.\n"
        "Install it or use the NixOS module which provides python3.withPackages.",
        file=sys.stderr,
    )
    sys.exit(1)

# constants

KEYRING_SERVICE: str = "quickshell-spotify"
REDIRECT_URI: str = "http://127.0.0.1:8888/callback"
SCOPES: str = (
    "user-read-recently-played user-read-currently-playing "
    "user-read-playback-state user-modify-playback-state"
)

HTTP_TIMEOUT: float = 10.0
# keyring reaches Secret Service over D-Bus, which HTTP_TIMEOUT does not cover.
KEYRING_TIMEOUT: float = 10.0
# Lock holder is bounded by KEYRING_TIMEOUT + HTTP_TIMEOUT per refresh.
LOCK_TIMEOUT: float = 30.0
# Abandoned auth otherwise holds port 8888 forever.
AUTH_TIMEOUT: float = 300.0

# in-process credential cache (never written to disk)

_client_id: str = ""
_client_secret: str = ""


# keyring helpers


class _KeyringTimeout(Exception):
    """Keyring call exceeded KEYRING_TIMEOUT."""


@contextlib.contextmanager
def _keyring_deadline() -> Iterator[None]:
    """Bound a keyring call with SIGALRM.

    Locked or prompting keyring blocks on D-Bus forever, and the process never exits.
    No-op off the main thread, where signal.signal raises ValueError.
    """

    def _fire(_signum: int, _frame: Any) -> None:
        raise _KeyringTimeout(f"exceeded {KEYRING_TIMEOUT}s")

    try:
        previous = signal.signal(signal.SIGALRM, _fire)
    except ValueError:
        yield
        return

    signal.setitimer(signal.ITIMER_REAL, KEYRING_TIMEOUT)
    try:
        yield
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        signal.signal(signal.SIGALRM, previous)


def _kr_get(username: str) -> str | None:
    """Return a keyring value or None if absent / backend unavailable / timed out."""
    try:
        with _keyring_deadline():
            return keyring.get_password(KEYRING_SERVICE, username)
    except (keyring.errors.KeyringError, _KeyringTimeout) as exc:
        print(f"Keyring read error ({username}): {exc}", file=sys.stderr)
        return None


def _kr_set(username: str, value: str) -> None:
    """Persist a value in the keyring; raise on failure."""
    try:
        with _keyring_deadline():
            keyring.set_password(KEYRING_SERVICE, username, value)
    except (keyring.errors.KeyringError, _KeyringTimeout) as exc:
        raise RuntimeError(f"Keyring write error ({username}): {exc}") from exc


def _kr_del(username: str) -> None:
    """Delete a keyring entry, silently ignoring 'not found'."""
    try:
        with _keyring_deadline():
            keyring.delete_password(KEYRING_SERVICE, username)
    except keyring.errors.PasswordDeleteError:
        pass
    except (keyring.errors.KeyringError, _KeyringTimeout) as exc:
        print(f"Keyring delete error ({username}): {exc}", file=sys.stderr)


# credentials (client ID / secret)


def load_credentials() -> tuple[str, str]:
    """Load client credentials from the keyring into module-level variables."""
    global _client_id, _client_secret
    _client_id = _kr_get("client_id") or ""
    _client_secret = _kr_get("client_secret") or ""
    return _client_id, _client_secret


def save_credentials(client_id: str, client_secret: str) -> None:
    """Persist client credentials in the keyring."""
    _kr_set("client_id", client_id)
    _kr_set("client_secret", client_secret)
    global _client_id, _client_secret
    _client_id = client_id
    _client_secret = client_secret


def clear_credentials() -> None:
    """Remove all stored credentials and tokens from the keyring."""
    for key in (
        "client_id",
        "client_secret",
        "access_token",
        "refresh_token",
        "expires_at",
    ):
        _kr_del(key)
    print("All keyring entries for quickshell-spotify cleared.", file=sys.stderr)


# token storage


@contextlib.contextmanager
def _token_lock() -> Iterator[None]:
    """Serialize refresh + save across processes.

    save_tokens writes three independent keyring keys, and `play` runs unguarded by the
    QML spotifyDataLoading flag that serializes `all`.
    Concurrent refreshes interleave the keys and race Spotify's refresh-token rotation.
    Proceeds unlocked rather than blocking forever on a stalled peer.
    Never nest: flock on a second fd for the same file deadlocks the process
    against itself.
    """
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir()
    path = os.path.join(runtime_dir, "quickshell-spotify-token.lock")

    try:
        fd = os.open(path, os.O_CREAT | os.O_RDWR, 0o600)
    except OSError as exc:
        print(f"Token lock unavailable ({exc}); proceeding unlocked", file=sys.stderr)
        yield
        return

    try:
        deadline = time.monotonic() + LOCK_TIMEOUT
        while True:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    print(
                        f"Token lock busy after {LOCK_TIMEOUT}s; proceeding unlocked",
                        file=sys.stderr,
                    )
                    break
                time.sleep(0.1)
        yield
    finally:
        # close releases the flock.
        os.close(fd)


def save_tokens(access_token: str, refresh_token: str, expires_in: int) -> None:
    """Persist OAuth tokens in the keyring.

    Caller holds _token_lock(); the three writes are not atomic together.
    """
    expires_at = str(int(time.time() * 1000) + expires_in * 1000)
    _kr_set("access_token", access_token)
    _kr_set("refresh_token", refresh_token)
    _kr_set("expires_at", expires_at)


def load_tokens() -> dict[str, Any] | None:
    """Load tokens from the keyring.  Returns None if any required token is absent."""
    access_token = _kr_get("access_token")
    refresh_token = _kr_get("refresh_token")
    expires_at_str = _kr_get("expires_at")

    if not access_token or not refresh_token:
        return None

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "expires_at": int(expires_at_str) if expires_at_str else 0,
    }


# token lifecycle


def _needs_refresh(tokens: dict[str, Any]) -> bool:
    """True within 5 minutes of expiry."""
    return int(time.time() * 1000) >= tokens["expires_at"] - 300_000


def refresh_access_token() -> bool:
    """Refresh the access token using the stored refresh token.

    Caller holds _token_lock(); this read-modify-writes keyring token state.
    """
    tokens = load_tokens()
    if not tokens:
        return False

    load_credentials()
    if not _client_id or not _client_secret:
        return False

    url = "https://accounts.spotify.com/api/token"
    auth_b64 = base64.b64encode(f"{_client_id}:{_client_secret}".encode()).decode()

    body = urllib.parse.urlencode(
        {"grant_type": "refresh_token", "refresh_token": tokens["refresh_token"]}
    ).encode()

    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Authorization", f"Basic {auth_b64}")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")

    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as response:
            result = json.loads(response.read().decode())
            # Spotify rotates the refresh token at will and invalidates the old one.
            # Re-saving the old one breaks auth until a manual
            # `quickshell-spotify auth`.
            save_tokens(
                result["access_token"],
                result.get("refresh_token", tokens["refresh_token"]),
                result["expires_in"],
            )
            return True
    except Exception as exc:
        print(f"Error refreshing token: {exc}", file=sys.stderr)
        return False


def _refresh_if_stale(stale_token: str | None = None) -> bool:
    """Refresh tokens under _token_lock, skipping the work a peer already did.

    stale_token: access token that drew a 401; refresh is skipped once the keyring holds
    a different one.  None: refresh only when the stored token is near expiry.
    """
    with _token_lock():
        tokens = load_tokens()
        if not tokens:
            return False

        # A peer may have refreshed while this process waited for the lock.
        if stale_token is None:
            if not _needs_refresh(tokens):
                return True
        elif tokens["access_token"] != stale_token:
            return True

        return refresh_access_token()


def get_valid_token() -> str | None:
    """Return a valid access token, refreshing it first if it is close to expiry."""
    tokens = load_tokens()
    if not tokens:
        return None

    if _needs_refresh(tokens):
        if not _refresh_if_stale():
            return None
        tokens = load_tokens()
        if not tokens:
            return None

    return tokens.get("access_token")


# API requests


class SpotifyError(Exception):
    """API failure carrying a machine-readable reason for the JSON payload."""

    def __init__(self, reason: str, detail: str = "") -> None:
        super().__init__(detail or reason)
        self.reason = reason


def api_request(
    endpoint: str,
    method: str = "GET",
    data: dict[str, Any] | None = None,
    _retried: bool = False,
) -> dict[str, Any]:
    """Make an authenticated Spotify API request.

    Raises SpotifyError on failure, so callers can tell failure from an empty result.
    An empty dict means success with no body (204).
    """
    token = get_valid_token()
    if not token:
        raise SpotifyError("not_authenticated", "no valid access token")

    url = f"https://api.spotify.com{endpoint}"
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    if body:
        req.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as response:
            if response.status == 204:
                return {}
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as exc:
        if exc.code == 401:
            # Retry once. A 401 that survives a good refresh means revoked access,
            # and each recursion costs two HTTP_TIMEOUT waits.
            if _retried or not _refresh_if_stale(token):
                raise SpotifyError("not_authenticated", f"401 on {endpoint}") from exc
            return api_request(endpoint, method, data, _retried=True)
        if exc.code == 429:
            retry_after = (
                exc.headers.get("Retry-After", "unknown") if exc.headers else "unknown"
            )
            raise SpotifyError(
                "rate_limited", f"429 on {endpoint}: retry after {retry_after}s"
            ) from exc
        raise SpotifyError(
            "api_error", f"{exc.code} on {endpoint}: {exc.reason}"
        ) from exc
    except urllib.error.URLError as exc:
        raise SpotifyError("network_error", f"{endpoint}: {exc.reason}") from exc
    except (OSError, json.JSONDecodeError) as exc:
        raise SpotifyError("network_error", f"{endpoint}: {exc}") from exc


# track data helpers


def _track_entry(track: dict[str, Any]) -> dict[str, str]:
    """Shape one API track object for the QML model."""
    images = track.get("album", {}).get("images", [])
    return {
        "title": track.get("name", ""),
        "artist": ", ".join(a.get("name", "") for a in track.get("artists", [])),
        "artUrl": images[0].get("url", "") if images else "",
        "uri": track.get("uri", ""),
    }


def get_recently_played(limit: int = 3) -> list[dict[str, str]]:
    """Return recently played tracks (title, artist, artUrl, uri)."""
    result = api_request(f"/v1/me/player/recently-played?limit={limit}")
    if "items" not in result:
        return []
    return [_track_entry(item.get("track", {})) for item in result["items"]]


def get_queue() -> list[dict[str, str]]:
    """Return the user's playback queue (title, artist, artUrl, uri)."""
    result = api_request("/v1/me/player/queue")
    if "queue" not in result:
        return []
    return [_track_entry(track) for track in result["queue"]]


def play_track(uri: str) -> None:
    """Play a specific track by Spotify URI.  Raises SpotifyError on failure."""
    api_request("/v1/me/player/play", method="PUT", data={"uris": [uri]})


# OAuth flow


class _OAuthServer(HTTPServer):
    """HTTPServer carrying OAuth callback state between handler and start_auth."""

    shutdown_flag: bool = False
    auth_ok: bool = False
    expected_state: str = ""


class _CallbackHandler(BaseHTTPRequestHandler):
    """HTTP handler for the OAuth callback."""

    def _respond(self, status: int, body: str) -> None:
        payload = f"<html><body>{body}</body></html>".encode()
        self.send_response(status)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self) -> None:
        assert isinstance(self.server, _OAuthServer)
        params = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        state = params.get("state", [""])[0]

        # Any page open in the browser can reach this loopback callback and bind
        # the shell to its own account.
        # Mismatched state keeps the server up.
        # Shutting down here would let a drive-by request cancel the real flow.
        # AUTH_TIMEOUT bounds the wait instead.
        if not secrets.compare_digest(state, self.server.expected_state):
            self._respond(
                403,
                "<h1>Rejected</h1><p>State mismatch; this callback was not initiated "
                "by quickshell-spotify.</p>",
            )
            return

        if "code" in params:
            # Exchange before responding.
            # The page must report the real outcome.
            self.server.auth_ok = exchange_code(params["code"][0])
            if self.server.auth_ok:
                self._respond(
                    200, "<h1>Success!</h1><p>You can close this window now.</p>"
                )
            else:
                self._respond(
                    400,
                    "<h1>Failed</h1><p>Token exchange failed.  See the terminal.</p>",
                )
            self.server.shutdown_flag = True
        elif "error" in params:
            # Escape: value is attacker-controlled, reflected on loopback origin.
            self._respond(
                400, f"<h1>Error</h1><p>{html.escape(params['error'][0])}</p>"
            )
            self.server.shutdown_flag = True
        else:
            self._respond(400, "<h1>Error</h1><p>Missing authorization code.</p>")

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
        # Stubbed: default logs the request line, putting the auth code in the journal.
        pass


def exchange_code(code: str) -> bool:
    """Exchange an authorization code for access + refresh tokens."""
    url = "https://accounts.spotify.com/api/token"
    auth_b64 = base64.b64encode(f"{_client_id}:{_client_secret}".encode()).decode()

    body = urllib.parse.urlencode(
        {"grant_type": "authorization_code", "code": code, "redirect_uri": REDIRECT_URI}
    ).encode()

    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Authorization", f"Basic {auth_b64}")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")

    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as response:
            result = json.loads(response.read().decode())
            # Not called under the lock, unlike refresh_access_token.
            with _token_lock():
                save_tokens(
                    result["access_token"],
                    result["refresh_token"],
                    result["expires_in"],
                )
            print(
                "Authentication successful! Tokens stored in keyring.", file=sys.stderr
            )
            return True
    except Exception as exc:
        print(f"Error exchanging code: {exc}", file=sys.stderr)
        return False


def setup_credentials_interactive() -> bool:
    """Prompt the user for client_id / client_secret and store them in the keyring."""
    print("Enter your Spotify app credentials (input is hidden).", file=sys.stderr)
    print("Create an app at https://developer.spotify.com/dashboard", file=sys.stderr)
    print(f"Set the redirect URI to: {REDIRECT_URI}", file=sys.stderr)

    # getpass, never argv: argv is world-readable via /proc.
    client_id = getpass.getpass("Client ID: ")
    client_secret = getpass.getpass("Client Secret: ")

    if not client_id or not client_secret:
        print("Error: both client_id and client_secret are required.", file=sys.stderr)
        return False

    save_credentials(client_id.strip(), client_secret.strip())
    print("Credentials stored in keyring.", file=sys.stderr)
    return True


def start_auth() -> bool:
    """Start the OAuth2 authorization flow.  Returns whether tokens were stored."""
    load_credentials()

    if not _client_id or not _client_secret:
        print(
            "No client credentials found in keyring.\n"
            "Run:  spotify_api.py setup  to store them first.",
            file=sys.stderr,
        )
        return False

    state = secrets.token_urlsafe(32)
    params = urllib.parse.urlencode(
        {
            "client_id": _client_id,
            "response_type": "code",
            "redirect_uri": REDIRECT_URI,
            "scope": SCOPES,
            "state": state,
        }
    )
    auth_url = f"https://accounts.spotify.com/authorize?{params}"

    server = _OAuthServer(("127.0.0.1", 8888), _CallbackHandler)
    server.expected_state = state
    # handle_request returns after this long idle, keeping the deadline checkable.
    server.timeout = 1

    print("Opening browser for authentication…", file=sys.stderr)
    webbrowser.open(auth_url)

    deadline = time.monotonic() + AUTH_TIMEOUT
    while not server.shutdown_flag:
        if time.monotonic() >= deadline:
            print(
                f"Authentication timed out after {AUTH_TIMEOUT:.0f}s.", file=sys.stderr
            )
            break
        server.handle_request()

    server.server_close()
    return server.auth_ok


# CLI entry point


def _parse_limit(raw: str) -> int:
    """Parse a limit argument, or exit non-zero with a JSON error."""
    try:
        limit = int(raw)
    except ValueError:
        limit = 0
    if limit < 1:
        print(json.dumps({"error": "invalid_limit"}))
        sys.exit(1)
    return limit


def main() -> None:
    load_credentials()

    if len(sys.argv) < 2:
        print("Usage: spotify_api.py <command>", file=sys.stderr)
        print("Commands:", file=sys.stderr)
        print(
            "  setup         - Store Spotify app credentials in keyring",
            file=sys.stderr,
        )
        print("  auth          - Start OAuth2 authorization flow", file=sys.stderr)
        print(
            "  clear         - Remove all stored credentials/tokens from keyring",
            file=sys.stderr,
        )
        print(
            "  recent [n]    - Get n recently played tracks (default 3)",
            file=sys.stderr,
        )
        print("  queue [n]     - Get n tracks from queue (default 3)", file=sys.stderr)
        print("  all           - Get all data as JSON", file=sys.stderr)
        print("  play <uri>    - Play a track by Spotify URI", file=sys.stderr)
        sys.exit(1)

    command = sys.argv[1]

    if command == "setup":
        if not setup_credentials_interactive():
            sys.exit(1)
    elif command == "auth":
        if not start_auth():
            sys.exit(1)
    elif command == "clear":
        clear_credentials()
    elif command == "recent":
        limit = _parse_limit(sys.argv[2]) if len(sys.argv) > 2 else 3
        try:
            print(json.dumps(get_recently_played(limit)))
        except SpotifyError as exc:
            print(f"'recent' failed: {exc}", file=sys.stderr)
            print(json.dumps({"error": exc.reason}))
            sys.exit(1)
    elif command == "queue":
        limit = _parse_limit(sys.argv[2]) if len(sys.argv) > 2 else 3
        try:
            print(json.dumps(get_queue()[:limit]))
        except SpotifyError as exc:
            print(f"'queue' failed: {exc}", file=sys.stderr)
            print(json.dumps({"error": exc.reason}))
            sys.exit(1)
    elif command == "all":
        # Keys stay present on failure so QML keeps working if it ignores "error".
        payload: dict[str, Any] = {"recently_played": [], "queue": []}
        try:
            payload["recently_played"] = get_recently_played(10)
            payload["queue"] = get_queue()[:10]
        except SpotifyError as exc:
            # Empty lists alone cannot be told apart from an empty queue,
            # and QML discards stderr.
            payload["error"] = exc.reason
            print(f"'all' failed: {exc}", file=sys.stderr)
        print(json.dumps(payload))
    elif command == "play":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Missing URI"}))
            sys.exit(1)
        try:
            play_track(sys.argv[2])
            print(json.dumps({"success": True}))
        except SpotifyError as exc:
            print(f"'play' failed: {exc}", file=sys.stderr)
            print(json.dumps({"success": False, "error": exc.reason}))
    else:
        print(f"Unknown command: {command}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

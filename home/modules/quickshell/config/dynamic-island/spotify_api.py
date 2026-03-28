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
"""

from __future__ import annotations

import base64
import getpass
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
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

# ── constants ──────────────────────────────────────────────────────────────────

KEYRING_SERVICE: str = "quickshell-spotify"
REDIRECT_URI: str = "http://127.0.0.1:8888/callback"
SCOPES: str = (
    "user-read-recently-played user-read-currently-playing "
    "user-read-playback-state user-modify-playback-state"
)

# ── in-process credential cache (never written to disk) ───────────────────────

_client_id: str = ""
_client_secret: str = ""


# ── keyring helpers ────────────────────────────────────────────────────────────


def _kr_get(username: str) -> str | None:
    """Return a keyring value or None if absent / backend unavailable."""
    try:
        return keyring.get_password(KEYRING_SERVICE, username)
    except keyring.errors.KeyringError as exc:
        print(f"Keyring read error ({username}): {exc}", file=sys.stderr)
        return None


def _kr_set(username: str, value: str) -> None:
    """Persist a value in the keyring; raise on failure."""
    try:
        keyring.set_password(KEYRING_SERVICE, username, value)
    except keyring.errors.KeyringError as exc:
        raise RuntimeError(f"Keyring write error ({username}): {exc}") from exc


def _kr_del(username: str) -> None:
    """Delete a keyring entry, silently ignoring 'not found'."""
    try:
        keyring.delete_password(KEYRING_SERVICE, username)
    except keyring.errors.PasswordDeleteError:
        pass
    except keyring.errors.KeyringError as exc:
        print(f"Keyring delete error ({username}): {exc}", file=sys.stderr)


# ── credentials (client ID / secret) ──────────────────────────────────────────


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


# ── token storage ──────────────────────────────────────────────────────────────


def save_tokens(access_token: str, refresh_token: str, expires_in: int) -> None:
    """Persist OAuth tokens in the keyring."""
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


# ── token lifecycle ────────────────────────────────────────────────────────────


def refresh_access_token() -> bool:
    """Refresh the access token using the stored refresh token."""
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
        with urllib.request.urlopen(req, timeout=10) as response:
            result = json.loads(response.read().decode())
            save_tokens(
                result["access_token"], tokens["refresh_token"], result["expires_in"]
            )
            return True
    except Exception as exc:
        print(f"Error refreshing token: {exc}", file=sys.stderr)
        return False


def get_valid_token() -> str | None:
    """Return a valid access token, refreshing it first if it is close to expiry."""
    tokens = load_tokens()
    if not tokens:
        return None

    # Refresh 5 minutes before expiry
    if int(time.time() * 1000) >= tokens["expires_at"] - 300_000:
        if not refresh_access_token():
            return None
        tokens = load_tokens()
        if not tokens:
            return None

    return tokens.get("access_token")


# ── API requests ───────────────────────────────────────────────────────────────


def api_request(
    endpoint: str,
    method: str = "GET",
    data: dict[str, Any] | None = None,
) -> dict[str, Any] | None:
    """Make an authenticated Spotify API request."""
    token = get_valid_token()
    if not token:
        return None

    url = f"https://api.spotify.com{endpoint}"
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    if body:
        req.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status == 204:
                return {}
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as exc:
        if exc.code == 401:
            if refresh_access_token():
                return api_request(endpoint, method, data)
        retry_after = (
            exc.headers.get("Retry-After", "unknown") if exc.headers else "unknown"
        )
        if exc.code == 429:
            print(
                f"API rate limited (429): retry after {retry_after}s", file=sys.stderr
            )
        else:
            print(f"API error {exc.code}: {exc.reason}", file=sys.stderr)
        return None
    except Exception as exc:
        print(f"Request error: {exc}", file=sys.stderr)
        return None


# ── track data helpers ─────────────────────────────────────────────────────────


def get_recently_played(limit: int = 3) -> list[dict[str, str]]:
    """Return recently played tracks (title, artist, artUrl, uri)."""
    result = api_request(f"/v1/me/player/recently-played?limit={limit}")
    if not result or "items" not in result:
        return []

    tracks: list[dict[str, str]] = []
    for item in result["items"]:
        track = item.get("track", {})
        images = track.get("album", {}).get("images", [])
        tracks.append(
            {
                "title": track.get("name", ""),
                "artist": ", ".join(
                    a.get("name", "") for a in track.get("artists", [])
                ),
                "artUrl": images[0].get("url", "") if images else "",
                "uri": track.get("uri", ""),
            }
        )
    return tracks


def get_queue() -> list[dict[str, str]]:
    """Return the user's playback queue (title, artist, artUrl, uri)."""
    result = api_request("/v1/me/player/queue")
    if not result or "queue" not in result:
        return []

    tracks: list[dict[str, str]] = []
    for track in result["queue"]:
        images = track.get("album", {}).get("images", [])
        tracks.append(
            {
                "title": track.get("name", ""),
                "artist": ", ".join(
                    a.get("name", "") for a in track.get("artists", [])
                ),
                "artUrl": images[0].get("url", "") if images else "",
                "uri": track.get("uri", ""),
            }
        )
    return tracks


def play_track(uri: str) -> bool:
    """Play a specific track by Spotify URI."""
    return (
        api_request("/v1/me/player/play", method="PUT", data={"uris": [uri]})
        is not None
    )


# ── OAuth flow ─────────────────────────────────────────────────────────────────


class _OAuthServer(HTTPServer):
    """HTTPServer with shutdown_flag for OAuth callback handling."""

    shutdown_flag: bool = False


class _CallbackHandler(BaseHTTPRequestHandler):
    """HTTP handler for the OAuth callback."""

    def do_GET(self) -> None:
        query = urllib.parse.urlparse(self.path).query
        params = urllib.parse.parse_qs(query)

        if "code" in params:
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(
                b"<html><body><h1>Success!</h1>"
                b"<p>You can close this window now.</p></body></html>"
            )
            exchange_code(params["code"][0])
            assert isinstance(self.server, _OAuthServer)
            self.server.shutdown_flag = True
        elif "error" in params:
            self.send_response(400)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(
                f"<html><body><h1>Error</h1><p>{params['error'][0]}</p></body></html>".encode()
            )
            assert isinstance(self.server, _OAuthServer)
            self.server.shutdown_flag = True

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
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
        with urllib.request.urlopen(req, timeout=10) as response:
            result = json.loads(response.read().decode())
            save_tokens(
                result["access_token"], result["refresh_token"], result["expires_in"]
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

    client_id = getpass.getpass("Client ID: ")
    client_secret = getpass.getpass("Client Secret: ")

    if not client_id or not client_secret:
        print("Error: both client_id and client_secret are required.", file=sys.stderr)
        return False

    save_credentials(client_id.strip(), client_secret.strip())
    print("Credentials stored in keyring.", file=sys.stderr)
    return True


def start_auth() -> bool:
    """Start the OAuth2 authorization flow."""
    load_credentials()

    if not _client_id or not _client_secret:
        print(
            "No client credentials found in keyring.\n"
            "Run:  spotify_api.py setup  to store them first.",
            file=sys.stderr,
        )
        return False

    params = urllib.parse.urlencode(
        {
            "client_id": _client_id,
            "response_type": "code",
            "redirect_uri": REDIRECT_URI,
            "scope": SCOPES,
        }
    )
    auth_url = f"https://accounts.spotify.com/authorize?{params}"

    server = _OAuthServer(("127.0.0.1", 8888), _CallbackHandler)

    print("Opening browser for authentication…", file=sys.stderr)
    webbrowser.open(auth_url)

    while not server.shutdown_flag:
        server.handle_request()

    server.server_close()
    return True


# ── CLI entry point ────────────────────────────────────────────────────────────


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
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 3
        print(json.dumps(get_recently_played(limit)))
    elif command == "queue":
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 3
        print(json.dumps(get_queue()[:limit]))
    elif command == "all":
        print(
            json.dumps(
                {"recently_played": get_recently_played(10), "queue": get_queue()[:10]}
            )
        )
    elif command == "play":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Missing URI"}))
            sys.exit(1)
        print(json.dumps({"success": play_track(sys.argv[2])}))
    else:
        print(f"Unknown command: {command}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

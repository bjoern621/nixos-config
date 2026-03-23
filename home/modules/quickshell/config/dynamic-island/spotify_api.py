#!/usr/bin/env python3
"""
Spotify API integration for Quickshell NowPlayingMenu.
Handles OAuth2 authentication and provides recently played, current track, and queue data.
"""

from __future__ import annotations

import base64
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from typing import Any

# Configuration
CREDENTIALS_FILE: Path = (
    Path.home() / ".config" / "quickshell-spotify" / "credentials.json"
)
_client_id: str = ""  # Set from credentials file
_client_secret: str = ""  # Set from credentials file
REDIRECT_URI: str = "http://127.0.0.1:8888/callback"
SCOPES: str = (
    "user-read-recently-played user-read-currently-playing user-read-playback-state"
)

# Token storage
_tokens: dict[str, Any] | None = None


def load_credentials() -> tuple[str, str]:
    """
    Load client credentials from file or use defaults.

    Returns:
        A tuple of (client_id, client_secret).
    """
    global _client_id, _client_secret

    if CREDENTIALS_FILE.exists():
        with open(CREDENTIALS_FILE, "r") as f:
            data: dict[str, Any] = json.load(f)
            _client_id = data.get("client_id", "")
            _client_secret = data.get("client_secret", "")

    return _client_id, _client_secret


def save_tokens(access_token: str, refresh_token: str, expires_in: int) -> None:
    """
    Save tokens to file.

    Args:
        access_token: The Spotify access token.
        refresh_token: The Spotify refresh token.
        expires_in: Token expiration time in seconds.
    """
    CREDENTIALS_FILE.parent.mkdir(parents=True, exist_ok=True)
    data: dict[str, Any] = {}
    if CREDENTIALS_FILE.exists():
        with open(CREDENTIALS_FILE, "r") as f:
            data = json.load(f)

    data["access_token"] = access_token
    data["refresh_token"] = refresh_token
    data["expires_at"] = int(time.time() * 1000) + (expires_in * 1000)

    with open(CREDENTIALS_FILE, "w") as f:
        json.dump(data, f, indent=2)


def load_tokens() -> dict[str, Any] | None:
    """
    Load tokens from file.

    Returns:
        The tokens dictionary or None if no tokens exist.
    """
    global _tokens

    if not CREDENTIALS_FILE.exists():
        return None

    with open(CREDENTIALS_FILE, "r") as f:
        data = json.load(f)
        _tokens = data
        return data


def refresh_access_token() -> bool:
    """
    Refresh the access token using refresh token.

    Returns:
        True if refresh was successful, False otherwise.
    """
    global _tokens

    tokens = load_tokens()
    if not tokens or "refresh_token" not in tokens:
        return False

    url = "https://accounts.spotify.com/api/token"
    auth_str = f"{_client_id}:{_client_secret}"
    auth_b64 = base64.b64encode(auth_str.encode()).decode()

    data = urllib.parse.urlencode(
        {"grant_type": "refresh_token", "refresh_token": tokens["refresh_token"]}
    ).encode()

    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Authorization", f"Basic {auth_b64}")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")

    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            result = json.loads(response.read().decode())
            save_tokens(
                result["access_token"], tokens["refresh_token"], result["expires_in"]
            )
            _tokens = load_tokens()
            return True
    except Exception as e:
        print(f"Error refreshing token: {e}", file=sys.stderr)
        return False


def get_valid_token() -> str | None:
    """
    Get a valid access token, refreshing if necessary.

    Returns:
        A valid access token string, or None if unavailable.
    """
    tokens = load_tokens()
    if not tokens or "access_token" not in tokens:
        return None

    # Check if token needs refresh (5 minute buffer)
    current_time = int(time.time() * 1000)
    if "expires_at" in tokens and current_time >= tokens["expires_at"] - 300000:
        if not refresh_access_token():
            return None
        tokens = load_tokens()
        if not tokens:
            return None

    return tokens.get("access_token")


def api_request(endpoint: str) -> dict[str, Any] | None:
    """
    Make an authenticated API request.

    Args:
        endpoint: The Spotify API endpoint (e.g., "/v1/me/player").

    Returns:
        The JSON response as a dictionary, or None on error.
    """
    token = get_valid_token()
    if not token:
        return None

    url = f"https://api.spotify.com{endpoint}"
    req = urllib.request.Request(url)
    req.add_header("Authorization", f"Bearer {token}")

    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as e:
        if e.code == 401:
            # Token expired, try refresh
            if refresh_access_token():
                return api_request(endpoint)
        print(f"API error {e.code}: {e.reason}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Request error: {e}", file=sys.stderr)
        return None


def get_recently_played(limit: int = 3) -> list[dict[str, str]]:
    """
    Get recently played tracks.

    Args:
        limit: Maximum number of tracks to return.

    Returns:
        A list of track dictionaries with title, artist, artUrl, and uri.
    """
    result = api_request(f"/v1/me/player/recently-played?limit={limit}")
    if not result or "items" not in result:
        return []

    tracks: list[dict[str, str]] = []
    for item in result["items"]:
        track = item.get("track", {})
        album = track.get("album", {})
        images = album.get("images", [])

        tracks.append(
            {
                "title": track.get("name", ""),
                "artist": ", ".join(
                    [a.get("name", "") for a in track.get("artists", [])]
                ),
                "artUrl": images[0].get("url", "") if images else "",
                "uri": track.get("uri", ""),
            }
        )

    return tracks


def get_queue() -> list[dict[str, str]]:
    """
    Get the user's queue.

    Returns:
        A list of track dictionaries with title, artist, artUrl, and uri.
    """
    result = api_request("/v1/me/player/queue")
    if not result or "queue" not in result:
        return []

    tracks: list[dict[str, str]] = []
    for track in result["queue"]:
        album = track.get("album", {})
        images = album.get("images", [])

        tracks.append(
            {
                "title": track.get("name", ""),
                "artist": ", ".join(
                    [a.get("name", "") for a in track.get("artists", [])]
                ),
                "artUrl": images[0].get("url", "") if images else "",
                "uri": track.get("uri", ""),
            }
        )

    return tracks


class _OAuthServer(HTTPServer):
    """HTTPServer with shutdown_flag for OAuth callback handling."""

    shutdown_flag: bool = False


class CallbackHandler(BaseHTTPRequestHandler):
    """HTTP handler for OAuth callback."""

    def do_GET(self) -> None:
        """Handle GET requests for OAuth callback."""
        query = urllib.parse.urlparse(self.path).query
        params = urllib.parse.parse_qs(query)

        if "code" in params:
            code = params["code"][0]
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(
                b"""
                <html><body>
                <h1>Success!</h1>
                <p>You can close this window now.</p>
                </body></html>
            """
            )

            # Exchange code for tokens
            exchange_code(code)
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

    def log_message(self, format: str, *args: Any) -> None:
        """Suppress logging."""
        pass


def exchange_code(code: str) -> bool:
    """
    Exchange authorization code for tokens.

    Args:
        code: The authorization code from Spotify.

    Returns:
        True if exchange was successful, False otherwise.
    """
    url = "https://accounts.spotify.com/api/token"
    auth_str = f"{_client_id}:{_client_secret}"
    auth_b64 = base64.b64encode(auth_str.encode()).decode()

    data = urllib.parse.urlencode(
        {"grant_type": "authorization_code", "code": code, "redirect_uri": REDIRECT_URI}
    ).encode()

    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Authorization", f"Basic {auth_b64}")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")

    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            result = json.loads(response.read().decode())
            save_tokens(
                result["access_token"], result["refresh_token"], result["expires_in"]
            )
            print("Authentication successful!", file=sys.stderr)
            return True
    except Exception as e:
        print(f"Error exchanging code: {e}", file=sys.stderr)
        return False


def start_auth() -> bool:
    """
    Start the OAuth2 authorization flow.

    Returns:
        True if authorization was initiated, False if credentials are missing.
    """
    load_credentials()

    if not _client_id or not _client_secret:
        print("Error: client_id and client_secret must be set", file=sys.stderr)
        print(f"Create {CREDENTIALS_FILE} with:", file=sys.stderr)
        print(
            '  {"client_id": "your_id", "client_secret": "your_secret"}',
            file=sys.stderr,
        )
        return False

    # Build auth URL
    params = urllib.parse.urlencode(
        {
            "client_id": _client_id,
            "response_type": "code",
            "redirect_uri": REDIRECT_URI,
            "scope": SCOPES,
        }
    )
    auth_url = f"https://accounts.spotify.com/authorize?{params}"

    # Start local server
    server = _OAuthServer(("127.0.0.1", 8888), CallbackHandler)

    print(f"Opening browser for authentication...", file=sys.stderr)
    webbrowser.open(auth_url)

    # Wait for callback
    while not server.shutdown_flag:
        server.handle_request()

    server.server_close()
    return True


def main() -> None:
    """Main entry point for CLI usage."""
    load_credentials()

    if len(sys.argv) < 2:
        print("Usage: spotify_api.py <command>", file=sys.stderr)
        print("Commands:", file=sys.stderr)
        print("  auth          - Start OAuth2 authorization flow", file=sys.stderr)
        print(
            "  recent [n]    - Get n recently played tracks (default 3)",
            file=sys.stderr,
        )
        print("  queue [n]     - Get n tracks from queue (default 3)", file=sys.stderr)
        print("  all           - Get all data as JSON", file=sys.stderr)
        sys.exit(1)

    command = sys.argv[1]

    if command == "auth":
        start_auth()
    elif command == "recent":
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 3
        result_recent: list[dict[str, str]] = get_recently_played(limit)
        print(json.dumps(result_recent))
    elif command == "queue":
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 3
        result_queue: list[dict[str, str]] = get_queue()[:limit]
        print(json.dumps(result_queue))
    elif command == "all":
        result_all: dict[str, Any] = {
            "recently_played": get_recently_played(3),
            "queue": get_queue()[:3],
        }
        print(json.dumps(result_all))
    else:
        print(f"Unknown command: {command}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

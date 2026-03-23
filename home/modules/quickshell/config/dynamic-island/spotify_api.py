#!/usr/bin/env python3
"""
Spotify API integration for Quickshell NowPlayingMenu.
Handles OAuth2 authentication and provides recently played, current track, and queue data.
"""

import json
import sys
import urllib.request
import urllib.parse
import urllib.error
import time
import base64
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading
import webbrowser
from pathlib import Path

# Configuration
CREDENTIALS_FILE = Path.home() / ".config" / "quickshell-spotify" / "credentials.json"
CLIENT_ID = ""  # Will be set from credentials file or CLI
CLIENT_SECRET = ""  # Will be set from credentials file or CLI
REDIRECT_URI = "http://127.0.0.1:8888/callback"
SCOPES = (
    "user-read-recently-played user-read-currently-playing user-read-playback-state"
)

# Token storage
_tokens = None


def load_credentials():
    """Load client credentials from file or use defaults."""
    global CLIENT_ID, CLIENT_SECRET

    if CREDENTIALS_FILE.exists():
        with open(CREDENTIALS_FILE, "r") as f:
            data = json.load(f)
            CLIENT_ID = data.get("client_id", "")
            CLIENT_SECRET = data.get("client_secret", "")

    return CLIENT_ID, CLIENT_SECRET


def save_tokens(access_token, refresh_token, expires_in):
    """Save tokens to file."""
    CREDENTIALS_FILE.parent.mkdir(parents=True, exist_ok=True)
    data = {}
    if CREDENTIALS_FILE.exists():
        with open(CREDENTIALS_FILE, "r") as f:
            data = json.load(f)

    data["access_token"] = access_token
    data["refresh_token"] = refresh_token
    data["expires_at"] = int(time.time() * 1000) + (expires_in * 1000)

    with open(CREDENTIALS_FILE, "w") as f:
        json.dump(data, f, indent=2)


def load_tokens():
    """Load tokens from file."""
    global _tokens

    if not CREDENTIALS_FILE.exists():
        return None

    with open(CREDENTIALS_FILE, "r") as f:
        data = json.load(f)
        _tokens = data
        return data


def refresh_access_token():
    """Refresh the access token using refresh token."""
    global _tokens

    tokens = load_tokens()
    if not tokens or "refresh_token" not in tokens:
        return False

    url = "https://accounts.spotify.com/api/token"
    auth_str = f"{CLIENT_ID}:{CLIENT_SECRET}"
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


def get_valid_token():
    """Get a valid access token, refreshing if necessary."""
    tokens = load_tokens()
    if not tokens or "access_token" not in tokens:
        return None

    # Check if token needs refresh (5 minute buffer)
    current_time = int(time.time() * 1000)
    if "expires_at" in tokens and current_time >= tokens["expires_at"] - 300000:
        if not refresh_access_token():
            return None
        tokens = load_tokens()

    return tokens.get("access_token")


def api_request(endpoint):
    """Make an authenticated API request."""
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


def get_recently_played(limit=3):
    """Get recently played tracks."""
    result = api_request(f"/v1/me/player/recently-played?limit={limit}")
    if not result or "items" not in result:
        return []

    tracks = []
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


def get_current_playback():
    """Get current playback state."""
    result = api_request("/v1/me/player")
    if not result:
        return None

    if not result.get("is_playing", False) and "item" not in result:
        return None

    track = result.get("item", {})
    if not track:
        return None

    album = track.get("album", {})
    images = album.get("images", [])

    return {
        "title": track.get("name", ""),
        "artist": ", ".join([a.get("name", "") for a in track.get("artists", [])]),
        "artUrl": images[0].get("url", "") if images else "",
        "album": album.get("name", ""),
        "uri": track.get("uri", ""),
        "is_playing": result.get("is_playing", False),
        "progress_ms": result.get("progress_ms", 0),
        "duration_ms": track.get("duration_ms", 0),
    }


def get_queue():
    """Get the user's queue."""
    result = api_request("/v1/me/player/queue")
    if not result or "queue" not in result:
        return []

    tracks = []
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


class CallbackHandler(BaseHTTPRequestHandler):
    """HTTP handler for OAuth callback."""

    def do_GET(self):
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
            self.server.shutdown_flag = True
        elif "error" in params:
            self.send_response(400)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(
                f"<html><body><h1>Error</h1><p>{params['error'][0]}</p></body></html>".encode()
            )
            self.server.shutdown_flag = True

    def log_message(self, format, *args):
        pass  # Suppress logging


def exchange_code(code):
    """Exchange authorization code for tokens."""
    url = "https://accounts.spotify.com/api/token"
    auth_str = f"{CLIENT_ID}:{CLIENT_SECRET}"
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


def start_auth():
    """Start the OAuth2 authorization flow."""
    load_credentials()

    if not CLIENT_ID or not CLIENT_SECRET:
        print("Error: CLIENT_ID and CLIENT_SECRET must be set", file=sys.stderr)
        print(f"Create {CREDENTIALS_FILE} with:", file=sys.stderr)
        print(
            '  {"client_id": "your_id", "client_secret": "your_secret"}',
            file=sys.stderr,
        )
        return False

    # Build auth URL
    params = urllib.parse.urlencode(
        {
            "client_id": CLIENT_ID,
            "response_type": "code",
            "redirect_uri": REDIRECT_URI,
            "scope": SCOPES,
        }
    )
    auth_url = f"https://accounts.spotify.com/authorize?{params}"

    # Start local server
    server = HTTPServer(("127.0.0.1", 8888), CallbackHandler)
    server.shutdown_flag = False

    print(f"Opening browser for authentication...", file=sys.stderr)
    webbrowser.open(auth_url)

    # Wait for callback
    while not server.shutdown_flag:
        server.handle_request()

    server.server_close()
    return True


def main():
    """Main entry point."""
    load_credentials()

    if len(sys.argv) < 2:
        print("Usage: spotify_api.py <command>", file=sys.stderr)
        print("Commands:", file=sys.stderr)
        print("  auth          - Start OAuth2 authorization flow", file=sys.stderr)
        print(
            "  recent [n]    - Get n recently played tracks (default 3)",
            file=sys.stderr,
        )
        print("  current       - Get current playback", file=sys.stderr)
        print("  queue [n]     - Get n tracks from queue (default 3)", file=sys.stderr)
        print("  all           - Get all data as JSON", file=sys.stderr)
        sys.exit(1)

    command = sys.argv[1]

    if command == "auth":
        start_auth()
    elif command == "recent":
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 3
        result = get_recently_played(limit)
        print(json.dumps(result))
    elif command == "current":
        result = get_current_playback()
        print(json.dumps(result))
    elif command == "queue":
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 3
        result = get_queue()[:limit]
        print(json.dumps(result))
    elif command == "all":
        result = {
            "recently_played": get_recently_played(3),
            "current": get_current_playback(),
            "queue": get_queue()[:3],
        }
        print(json.dumps(result))
    else:
        print(f"Unknown command: {command}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

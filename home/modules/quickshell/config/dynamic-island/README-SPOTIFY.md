# Spotify API Integration for Quickshell NowPlayingMenu

Adds playlist/queue functionality to NowPlayingMenu:

- **Recently Played**: last 3 tracks
- **Current Track**: currently playing track
- **Queue**: next 3 tracks

## Setup

### 1. Create a Spotify Application

1. Go to https://developer.spotify.com/dashboard
2. Click "Create App"
3. Fill in the details:
    - **App name**: Quickshell (any name works)
    - **App description**: Quickshell NowPlayingMenu integration
4. Click "Save"
5. Open the new app and click "Settings"
6. Copy the **Client ID** and **Client Secret**
7. Click "Edit", add the redirect URI `http://127.0.0.1:8888/callback`, then "Save"

### 2. Run Setup and Auth

```bash
cd ~/git/nixos-config/home/modules/quickshell/config/dynamic-island
python3 spotify_api.py setup
python3 spotify_api.py auth
```

`setup` prompts for the Client ID and Client Secret and stores them in the
system keyring via the `keyring` package. `auth` opens a browser for OAuth2
authorization and writes the access tokens to the keyring.

### 3. Test the Integration

```bash
python3 spotify_api.py all       # all endpoints at once
python3 spotify_api.py recent    # recently played
python3 spotify_api.py current   # current track
python3 spotify_api.py queue     # upcoming tracks
```

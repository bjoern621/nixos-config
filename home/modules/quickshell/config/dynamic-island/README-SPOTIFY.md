# Spotify API Integration for Quickshell NowPlayingMenu

This integration adds playlist/queue functionality to the NowPlayingMenu, showing:

- **Recently Played**: Last 3 tracks played
- **Current Track**: Currently playing track
- **Queue**: Next 3 tracks in the queue

## Setup

### 1. Create a Spotify Application

1. Go to https://developer.spotify.com/dashboard
2. Click "Create App"
3. Fill in the details:
    - **App name**: Quickshell (or any name you like)
    - **App description**: Quickshell NowPlayingMenu integration
4. Click "Save"
5. Click on your new app to open it
6. Click "Settings" in the top right
7. Note down your **Client ID** and **Client Secret**
8. Click "Edit" and add this Redirect URI:
    ```
    http://127.0.0.1:8888/callback
    ```
9. Click "Add" then "Save"

### 2. Run the Setup & Auth

```bash
cd ~/git/nixos-config/home/modules/quickshell/config/dynamic-island
python3 spotify_api.py setup
python3 spotify_api.py auth
```

These commands will:

1. Prompt for your Client ID and Client Secret
2. Save credentials securely to your system keyring via the `keyring` package
3. Open a browser for OAuth2 authorization
4. Save the access tokens to the keyring

### 3. Test the Integration

```bash
# Test API calls directly
python3 spotify_api.py all

# Or test individual endpoints
python3 spotify_api.py recent
python3 spotify_api.py current
python3 spotify_api.py queue
```

# Spotify API Integration for Quickshell NowPlayingMenu

This integration adds playlist/queue functionality to the NowPlayingMenu, showing:

- **Recently Played**: Last 3 tracks played
- **Current Track**: Currently playing track with playback indicator
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

### 2. Run the Setup Script

```bash
cd ~/git/nixos-config/home/modules/quickshell/config/dynamic-island
./setup-spotify.sh
```

This script will:

1. Prompt for your Client ID and Client Secret
2. Save credentials to `~/.config/quickshell-spotify/credentials.json`
3. Open a browser for OAuth2 authorization
4. Save the access tokens

### 3. Test the Integration

```bash
# Test API calls directly
python3 spotify_api.py all

# Or test individual endpoints
python3 spotify_api.py recent
python3 spotify_api.py current
python3 spotify_api.py queue
```

## Usage

Once configured, the Spotify integration works automatically:

1. Open the NowPlayingMenu in Quickshell
2. Click "Wiedergabeliste" to expand the playlist view
3. The menu will automatically fetch and display:
    - Your recently played tracks
    - The current track (highlighted)
    - Your queue

The data refreshes every 5 seconds while the playlist view is open.

## Security Note

**IMPORTANT**: This implementation stores credentials in plain text at:

```
~/.config/quickshell-spotify/credentials.json
```

This is intentionally simple for development purposes. The file has restricted permissions (600), but be aware that:

- Anyone with access to your user account can read these credentials
- The credentials are not encrypted
- Do not commit this file to version control

For production use, consider:

- Using a proper secrets manager
- Encrypting the credentials file
- Using environment variables instead

## Files

- `spotify_api.py` - Python script for Spotify API calls
- `setup-spotify.sh` - Setup script for easy configuration
- `menus/NowPlayingMenu.qml` - QML component with Spotify integration

## Troubleshooting

### "CLIENT_ID and CLIENT_SECRET must be set"

Run the setup script or manually create the credentials file:

```bash
mkdir -p ~/.config/quickshell-spotify
cat > ~/.config/quickshell-spotify/credentials.json << EOF
{
  "client_id": "your_client_id_here",
  "client_secret": "your_client_secret_here"
}
EOF
chmod 600 ~/.config/quickshell-spotify/credentials.json
```

### "Error refreshing token" or "401 Unauthorized"

Re-run the authorization:

```bash
python3 spotify_api.py auth
```

### No data appears in the playlist

1. Check that Spotify is running and playing music
2. Verify the API works: `python3 spotify_api.py all`
3. Check Quickshell logs for errors

### "Port 8888 already in use"

The OAuth callback server uses port 8888. If it's in use:

1. Kill the process using that port
2. Or modify the `REDIRECT_URI` in `spotify_api.py` and update your Spotify app settings

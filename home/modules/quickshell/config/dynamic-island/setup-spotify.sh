#!/usr/bin/env bash
# Setup script for Spotify API integration

CONFIG_DIR="$HOME/.config/quickshell-spotify"
CREDENTIALS_FILE="$CONFIG_DIR/credentials.json"

echo "=== Spotify API Setup for Quickshell ==="
echo ""
echo "This script will help you set up Spotify API access for the NowPlayingMenu."
echo ""

# Create config directory
mkdir -p "$CONFIG_DIR"

# Check if credentials already exist
if [ -f "$CREDENTIALS_FILE" ]; then
    echo "Found existing credentials at: $CREDENTIALS_FILE"
    read -p "Do you want to update them? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing credentials."
        exit 0
    fi
fi

echo ""
echo "Step 1: Create a Spotify Application"
echo "--------------------------------------"
echo "1. Go to: https://developer.spotify.com/dashboard"
echo "2. Click 'Create App'"
echo "3. Fill in the details:"
echo "   - App name: Quickshell (or any name you like)"
echo "   - App description: Quickshell NowPlayingMenu integration"
echo "4. Click 'Save'"
echo "5. Click on your new app to open it"
echo "6. Click 'Settings' in the top right"
echo "7. Note down your 'Client ID' and 'Client Secret'"
echo "8. Click 'Edit' and add this Redirect URI:"
echo "   http://127.0.0.1:8888/callback"
echo "9. Click 'Add' then 'Save'"
echo ""
read -p "Press Enter when you have your Client ID and Client Secret ready..."

echo ""
echo "Step 2: Enter your credentials"
echo "--------------------------------"
read -p "Client ID: " CLIENT_ID
read -p "Client Secret: " CLIENT_SECRET

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
    echo "Error: Client ID and Client Secret are required"
    exit 1
fi

# Save credentials
cat > "$CREDENTIALS_FILE" << EOF
{
  "client_id": "$CLIENT_ID",
  "client_secret": "$CLIENT_SECRET"
}
EOF

chmod 600 "$CREDENTIALS_FILE"

echo ""
echo "Credentials saved to: $CREDENTIALS_FILE"
echo ""
echo "Step 3: Authorize the application"
echo "-----------------------------------"
echo "Now you need to authorize the app to access your Spotify account."
echo "A browser window will open. Please log in and authorize the app."
echo ""
read -p "Press Enter to start authorization..."

# Run the authorization
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/spotify_api.py" auth

if [ $? -eq 0 ]; then
    echo ""
    echo "=== Setup Complete! ==="
    echo ""
    echo "You can now use the Spotify integration in Quickshell."
    echo "The Wiedergabeliste (Playlist) section will show:"
    echo "  - Recently played tracks"
    echo "  - Current track"
    echo "  - Queue"
    echo ""
    echo "To test, run:"
    echo "  python3 $SCRIPT_DIR/spotify_api.py all"
else
    echo ""
    echo "Authorization failed. Please check your credentials and try again."
    exit 1
fi

#!/usr/bin/env bash

# Simple power menu using rofi (fallback to dmenu if rofi is not available)
MENU_CMD=""
if command -v rofi >/dev/null 2>&1; then
  MENU_CMD="rofi -dmenu -i -p Power"
else
  MENU_CMD="dmenu -p Power"
fi

choice=$(printf "Shutdown\nReboot\nSuspend\nLogout\nCancel" | eval "$MENU_CMD")
case "$choice" in
  Shutdown)
    systemctl poweroff
    ;;
  Reboot)
    systemctl reboot
    ;;
  Suspend)
    systemctl suspend
    ;;
  Logout)
    # hyprland logout
    if command -v hyprctl >/dev/null 2>&1; then
      hyprctl dispatch exit
    fi
    ;;
  *)
    exit 0
    ;;
esac

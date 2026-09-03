{ ... }:

{
  programs.kitty = {
    enable = true;

    # no-cursor: the shell integration otherwise forces a beam cursor at every prompt,
    # overriding cursor_shape.
    shellIntegration.mode = "no-rc no-cursor";

    keybindings = {
      # Hyprland remaps ALT+up/down to Page_Up/Page_Down, so these also drive scrollback.
      # Scroll actions pass the key through while the alternate screen is active,
      # leaving Page_Up in nvim, less and htop alone.
      "page_up" = "scroll_page_up";
      "page_down" = "scroll_page_down";

      # Kitty's default new_os_window starts in the directory kitty itself was launched from.
      "ctrl+shift+n" = "new_os_window_with_cwd";
    };

    settings = {
      window_padding_width = 8;
      hide_window_decorations = true;
      confirm_os_window_close = 0;
      enable_audio_bell = false;
      scrollback_lines = 10000;

      scrollbar = "hovered";

      # Touchpad sends high-precision deltas on Wayland, mouse wheel low-precision.
      touch_scroll_multiplier = 12.0;
      wheel_scroll_multiplier = 3.0;

      momentum_scroll = 0.0;
      # Whole lines per event instead of sub-line pixel steps.
      pixel_scroll = false;

      # 0: pointer stays on screen while idle. Negative hides it on keypress.
      mouse_hide_wait = 0;

      # Monokai Pro, set inline because kitty-themes carries no Monokai Pro.
      background = "#2d2a2e";
      foreground = "#fff1f3";

      # none: reverse video against the cell underneath.
      cursor = "none";
      cursor_shape = "block";
      cursor_blink_interval = 0;
      selection_foreground = "none";
      selection_background = "none";

      color0 = "#2c2525";
      color1 = "#fd6883";
      color2 = "#adda78";
      color3 = "#f9cc6c";
      color4 = "#f38d70";
      color5 = "#a8a9eb";
      color6 = "#85dacc";
      color7 = "#fff1f3";

      color8 = "#72696a";
      color9 = "#fd6883";
      color10 = "#adda78";
      color11 = "#f9cc6c";
      color12 = "#f38d70";
      color13 = "#a8a9eb";
      color14 = "#85dacc";
      color15 = "#fff1f3";
    };
  };
}

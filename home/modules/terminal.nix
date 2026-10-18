{ ... }:

{
  # Kitty only delivers keys; zsh owns line buffer.
  # Editing keys need both halves, so zsh half lives here, not in shell.nix.
  programs.zsh.initContent = builtins.readFile ./terminal-editing.zsh;

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

      # GUI-style text editing keys. zsh side lives in terminal-editing.zsh.
      # Empty action unmaps kitty default, passing key to program.
      "ctrl+shift+left" = ""; # previous_tab
      "ctrl+shift+right" = ""; # next_tab
      "ctrl+shift+home" = ""; # scroll_home
      "ctrl+shift+end" = ""; # scroll_end
      "ctrl+shift+delete" = ""; # clear_terminal reset active
      # Legacy encoding drops shift from these, so zsh cannot tell them apart.
      # Send CSI u form instead.
      # send_text skips kitty keyboard protocol mode, so nvim still gets real key.
      "ctrl+shift+backspace" = "send_text normal,application \\e[127;6u"; # change_font_size all 0
      "ctrl+shift+z" = "send_text normal,application \\e[122;6u"; # scroll_to_prompt -1
      # zsh sets user var zsh_selection while its selection is active.
      # Then Ctrl+Shift+C goes to zsh, which copies via OSC 52.
      # Otherwise kitty copies its own mouse selection.
      "--when-focus-on var:zsh_selection ctrl+shift+c" = "send_text normal,application \\e[99;6u";
    };

    settings = {
      window_padding_width = 8;
      hide_window_decorations = true;
      # kitty 0.49 remembers maximized state too.
      # Hyprland honors it, so every new window opens maximized.
      remember_window_size = false;
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

      # Nerd Font icon ranges, from the font's own charset (fc-scan --format '%{charset}').
      # Font ships system-wide from modules/fonts.nix.
      symbol_map = "U+23FB-U+23FE,U+2630,U+2665,U+26A1,U+276C-U+2771,U+2B58,U+E000-U+E00A,U+E0A0-U+E0A3,U+E0B0-U+E0C8,U+E0CA,U+E0CC-U+E0D2,U+E0D4,U+E0D6-U+E0D7,U+E200-U+E2A9,U+E300-U+E3E3,U+E5FA-U+E6BB,U+E700-U+E8EF,U+EA60-U+EA88,U+EA8A-U+EA8C,U+EA8F-U+EAC7,U+EAC9,U+EACC-U+EB09,U+EB0B-U+EB4E,U+EB50-U+EC5E,U+EC60-U+EC84,U+ED00-U+EFCF,U+F000-U+F385,U+F400-U+F533,U+F0001-U+F1AF0 Symbols Nerd Font Mono";

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

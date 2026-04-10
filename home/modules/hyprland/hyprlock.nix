{ ... }:

{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        grace = 3;
        disable_loading_bar = true;
        hide_cursor = true;
      };

      background = [
        {
          monitor = "";
          path = "screenshot";
          blur_passes = 3;
          blur_size = 6;
          brightness = 0.6;
          contrast = 0.9;
          vibrancy = 0.2;
        }
      ];

      # Clock - hours
      label = [
        {
          monitor = "";
          text = ''cmd[update:1000] echo "<span>$(date +"%H")</span>"'';
          color = "rgba(255, 255, 255, 1.0)";
          font_size = 160;
          font_family = "Sans Bold";
          position = "0, 120";
          halign = "center";
          valign = "center";
          shadow_passes = 2;
          shadow_size = 4;
          shadow_color = "rgba(0, 0, 0, 0.5)";
        }
        # Clock - minutes
        {
          monitor = "";
          text = ''cmd[update:1000] echo "<span>$(date +"%M")</span>"'';
          color = "rgba(255, 255, 255, 1.0)";
          font_size = 160;
          font_family = "Sans Bold";
          position = "0, -40";
          halign = "center";
          valign = "center";
          shadow_passes = 2;
          shadow_size = 4;
          shadow_color = "rgba(0, 0, 0, 0.5)";
        }
        # Date
        {
          monitor = "";
          text = ''cmd[update:60000] echo "<span>$(date +"%d %b")</span>"'';
          color = "rgba(200, 230, 200, 0.9)";
          font_size = 18;
          font_family = "Sans";
          position = "0, -140";
          halign = "center";
          valign = "center";
          shadow_passes = 1;
          shadow_size = 2;
          shadow_color = "rgba(0, 0, 0, 0.4)";
        }
        # Day of week
        {
          monitor = "";
          text = ''cmd[update:60000] echo "<span>$(date +"%A")</span>"'';
          color = "rgba(200, 230, 200, 0.9)";
          font_size = 18;
          font_family = "Sans";
          position = "0, -170";
          halign = "center";
          valign = "center";
          shadow_passes = 1;
          shadow_size = 2;
          shadow_color = "rgba(0, 0, 0, 0.4)";
        }
        # Username (inside pill)
        {
          monitor = "";
          text = "$USER";
          color = "rgba(255, 255, 255, 0.9)";
          font_size = 14;
          font_family = "Sans Bold";
          position = "0, -260";
          halign = "center";
          valign = "center";
        }
      ];

      # Username pill
      shape = [
        {
          monitor = "";
          size = "320, 50";
          color = "rgba(0, 0, 0, 0.5)";
          rounding = 25;
          border_size = 1;
          border_color = "rgba(255, 255, 255, 0.2)";
          position = "0, -260";
          halign = "center";
          valign = "center";
        }
        # Password pill background
        {
          monitor = "";
          size = "320, 50";
          color = "rgba(0, 0, 0, 0.5)";
          rounding = 25;
          border_size = 1;
          border_color = "rgba(255, 255, 255, 0.2)";
          position = "0, -320";
          halign = "center";
          valign = "center";
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "320, 50";
          outline_thickness = 0;
          dots_size = 0.25;
          dots_spacing = 0.15;
          dots_center = true;
          outer_color = "rgba(0, 0, 0, 0)";
          inner_color = "rgba(0, 0, 0, 0)";
          font_color = "rgba(255, 255, 255, 0.9)";
          fade_on_empty = false;
          font_family = "Sans";
          placeholder_text = ''<i><span foreground="#ffffff99">Passwort eingeben</span></i>'';
          hide_input = false;
          rounding = 25;
          position = "0, -320";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };

}

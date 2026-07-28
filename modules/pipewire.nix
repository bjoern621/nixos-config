{ pkgs, ... }:

{
  hardware.firmware = [
    pkgs.sof-firmware
  ];

  environment.systemPackages = with pkgs; [
    alsa-utils # ALSA, the Advanced Linux Sound Architecture utils
    easyeffects # Audio effects
    pwvucontrol # Pipewire Volume Control
    coppwr # Low level control GUI for the PipeWire multimedia server
  ];

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    wireplumber.enable = true;
    alsa.enable = true;
    alsa.support32Bit = false;
    pulse.enable = true; # ! Definitely required by hyprland / waybar (https://github.com/Alexays/Waybar/issues/3431#issuecomment-2223092688) !
    jack.enable = false;

    wireplumber.extraConfig."50-fractal-scape-profile" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "device.name" = "alsa_card.usb-Fractal_Fractal_Scape_Dongle_00000000911AD55L3097-00"; }
          ];
          actions.update-props = {
            "device.profile" = "output:analog-stereo+input:mono-fallback";
          };
        }
      ];
    };

    # Drop the local A2DP sink role. Some speakers (e.g. Anker Soundcore Boost)
    # advertise both an A2DP sink and an A2DP source endpoint. With the default
    # roles the host auto-connects to the speaker's source endpoint, which grabs
    # the single AVDTP transport and makes the playback (a2dp-sink) connection
    # fail with "Device or resource busy". WirePlumber then hides the playback
    # profile and only offers off / Audio-Gateway. Removing a2dp_sink (the host
    # acting as a Bluetooth speaker, an unused role here) frees the transport so
    # output works. Gateway roles are kept so headset microphones still work.
    wireplumber.extraConfig."51-bluez-roles" = {
      "monitor.bluez.properties" = {
        "bluez5.roles" = [
          "a2dp_source"
          "bap_sink"
          "bap_source"
          "hfp_hf"
          "hfp_ag"
        ];
      };
    };

    # Disable the AMD GPU HDMI/DisplayPort audio controller. It exposes three
    # HDMI/DP output sinks that are not wired to any usable output on this
    # machine.
    wireplumber.extraConfig."52-disable-radeon-hdmi-audio" = {
      "monitor.alsa.rules" = [
        {
          matches = [ { "device.name" = "alsa_card.pci-0000_c3_00.1"; } ];
          actions.update-props = {
            "device.disabled" = true;
          };
        }
      ];
    };

    # Built-in speaker protection. TAS2781 smart amps.
    # Driver rejects per-speaker factory calibration (dmesg: "tas2781_apply_calib: V1 CRC error").
    # Cone-excursion protection runs uncalibrated. Loud deep bass over-drives cone into crackling.
    # 150 Hz high-pass, 24 dB/oct (2 cascaded biquads/channel). Cuts sub-150 Hz speaker cannot reproduce.
    # Virtual "Ryzen HD Audio Controller Speaker (Protected)" sink filters, feeds real built-in speaker. Only built-in speaker affected.
    # Headphones, USB, Bluetooth separate devices, untouched.
    # priority.session 1050 out-ranks raw speaker (1000) as default, stays below external (dongle 1109).
    # Lower Freq (130, 120) keeps more low end. Verify crackle stays gone at loudest volume used.
    extraConfig.pipewire."99-speaker-protect" = {
      "context.modules" = [
        {
          name = "libpipewire-module-filter-chain";
          args = {
            "node.description" = "Ryzen HD Audio Controller Speaker (Protected)";
            "media.name" = "Ryzen HD Audio Controller Speaker (Protected)";
            "filter.graph" = {
              nodes = [
                {
                  type = "builtin";
                  label = "bq_highpass";
                  name = "hp1l";
                  control = {
                    "Freq" = 175;
                    "Q" = 0.707;
                  };
                }
                {
                  type = "builtin";
                  label = "bq_highpass";
                  name = "hp2l";
                  control = {
                    "Freq" = 175;
                    "Q" = 0.707;
                  };
                }
                {
                  type = "builtin";
                  label = "bq_highpass";
                  name = "hp1r";
                  control = {
                    "Freq" = 175;
                    "Q" = 0.707;
                  };
                }
                {
                  type = "builtin";
                  label = "bq_highpass";
                  name = "hp2r";
                  control = {
                    "Freq" = 175;
                    "Q" = 0.707;
                  };
                }
              ];
              links = [
                {
                  output = "hp1l:Out";
                  input = "hp2l:In";
                }
                {
                  output = "hp1r:Out";
                  input = "hp2r:In";
                }
              ];
              inputs = [
                "hp1l:In"
                "hp1r:In"
              ];
              outputs = [
                "hp2l:Out"
                "hp2r:Out"
              ];
            };
            "capture.props" = {
              "node.name" = "speaker_protected";
              "media.class" = "Audio/Sink";
              "audio.channels" = 2;
              "audio.position" = [
                "FL"
                "FR"
              ];
              "priority.session" = 1050;
            };
            "playback.props" = {
              "node.name" = "speaker_protected.output";
              "audio.channels" = 2;
              "audio.position" = [
                "FL"
                "FR"
              ];
              "target.object" = "alsa_output.pci-0000_c3_00.6.HiFi__Speaker__sink";
              "stream.dont-remix" = true;
            };
          };
        }
      ];
    };
  };
}

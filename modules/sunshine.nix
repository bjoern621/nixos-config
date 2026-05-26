{ pkgs, ... }:

{
  # Sunshine is the host side of the Moonlight streaming protocol.
  # On Hyprland it captures via wlroots screencopy (zero-copy DMA-BUF),
  # so cap_sys_admin / KMS capture is not needed.
  #
  # Pair a Moonlight client (TV, Pi, phone) via the web UI:
  #   https://localhost:47990
  #
  # ---------------------------------------------------------------------------
  # Sideloading Moonlight on an LG webOS TV (one-time setup)
  # ---------------------------------------------------------------------------
  # 1. On the TV: install "Developer Mode" from the LG Content Store, sign in
  #    with an LG developer account (https://webostv.developer.lge.com),
  #    toggle Dev Mode Status and Key Server ON, note the TV IP and the
  #    6-character passphrase.
  #
  # 2. On this host, pair the TV (one-time):
  #
  #      nix shell nixpkgs#ares-cli
  #      # The nixpkgs ares-cli seeds ~/.webos/tv/novacom-devices.json from the
  #      # read-only store, so the file is mode 444 on first run. Make it writable:
  #      chmod u+w ~/.webos/tv/novacom-devices.json
  #      ares-setup-device              # name=lgtvc5, host=<TV-IP>, port=9922, user=prisoner
  #      ares-novacom --device lgtvc5 --getkey   # paste the 6-char passphrase
  #
  # 3. Install Moonlight (repeat to update):
  #
  #      Download ipk form https://github.com/mariotaku/moonlight-tv/releases/latest
  #      ares-install --device lgtvc5 <path-to-ipk>
  #      ares-launch  --device lgtvc5 com.limelight.webos
  #
  # 4. In Moonlight on the TV, pair with this Sunshine host using the PIN
  #    flow at https://localhost:47990.
  #
  # There is a 1000-hour Dev Mode session reset timer that uninstalls sideloaded apps. Timer must be reset regularly.
  services.sunshine = {
    enable = true;
    autoStart = false;
    capSysAdmin = false;
    openFirewall = true;
  };

  # Sunshine synthesizes mouse/keyboard input through /dev/uinput.
  # The default permissions block non-root access; this opens it to the input group.
  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
  '';

  # Membership in the input group is required for uinput access.
  users.users.bjoern.extraGroups = [ "input" ];
}

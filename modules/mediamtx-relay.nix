# MediaMTX relay for the screen-sharing app.
#
# The split with that repository: what the relay carries is the app's decision and lives in
# its config file, which listeners this machine exposes is this repo's.
# Nothing about the relay's behaviour is restated here.
#
# The file is deploy/mediamtx-groups.yml and not the mediamtx.yml at that repo's root. The
# two describe two deployments and both are real: the root file is a relay on a trusted
# network where anybody may publish, this one is a relay on the internet where a token
# decides. Every HTTP listener in it binds loopback and lives behind the proxy
# (screenshare-proxy.nix); publishing and reading take a JWT the group service signs
# (screenshare-groupd.nix).
#
# The overlay is not optional. nixpkgs carries MediaMTX 1.18.2, the app's config uses the
# `moq*` keys that arrived in 1.20.0, and MediaMTX exits on a key it does not know rather
# than ignoring it.

{
  config,
  lib,
  inputs,
  ...
}:

{
  nixpkgs.overlays = [ inputs.screen-sharing.overlays.default ];

  services.mediamtx.enable = true;

  # nixpkgs generates /etc/mediamtx.yaml from `services.mediamtx.settings`.
  # Retyping the app's yml as a Nix attrset would be a second copy of it, and the copies
  # would drift, so the file itself is the source.
  environment.etc."mediamtx.yaml".source =
    lib.mkForce "${inputs.screen-sharing}/deploy/mediamtx-groups.yml";

  # SRT is the one leg no proxy can wrap: UDP, no TLS. What protects the packets is a
  # relay-wide passphrase, and it is a secret, so it reaches the process as environment
  # rather than through the config file in the store. MediaMTX overrides any config key from
  # MTX_<KEY>, which is what keeps the file itself deployment-independent.
  sops.secrets.srt-passphrase.sopsFile = ../secrets/screenshare-relay.yaml;
  sops.templates."mediamtx-srt.env" = {
    restartUnits = [ "mediamtx.service" ];
    # Both keys, one value: the relay keys publishing and reading separately and an operator
    # setting the pair sets them alike. A leg carrying it on one side only connects and never
    # plays.
    content = ''
      MTX_PATHDEFAULTS_SRTPUBLISHPASSPHRASE=${config.sops.placeholder.srt-passphrase}
      MTX_PATHDEFAULTS_SRTREADPASSPHRASE=${config.sops.placeholder.srt-passphrase}
    '';
  };

  systemd.services.mediamtx = {
    # The key set is fetched at the first connection to authenticate, not at start, so this
    # orders the two rather than gating one on the other.
    after = [ "groupd.service" ];
    wants = [ "groupd.service" ];

    serviceConfig = {
      # `moqServerCert` and `moqServerKey` are relative names, and MediaMTX writes the
      # self-signed pair on first start.
      # The nixpkgs unit runs DynamicUser with / as its working directory, so without a
      # writable one the MoQ listener never comes up.
      # The state directory also keeps that certificate across restarts, which keeps the
      # fingerprint the web grid pins from changing under it.
      StateDirectory = "mediamtx";
      WorkingDirectory = "%S/mediamtx";
      EnvironmentFile = config.sops.templates."mediamtx-srt.env".path;
    };
  };

  # What this machine exposes directly, which is the two legs that cannot go through the
  # proxy. Everything else in that config file binds loopback and is reached over TLS on 443.
  #
  # Not opened, and each for its own reason:
  #   9997  the relay's API. A group token grants publishing and reading and nothing else,
  #         so every caller from outside is refused at it anyway.
  #   8888/8889  HLS and WebRTC signalling. Both are HTTP and both are behind the proxy.
  #   8554/1935  RTSP and RTMP. Cleartext on the wire, and their TLS variants would want a
  #         certificate of their own; on this host they are loopback and a LAN relay is where
  #         they are used.
  #   8892/8893  MoQ. Its listeners carry a self-signed certificate the web grid pins by
  #         fingerprint, which is the one thing here that is not the ACME certificate.
  networking.firewall.allowedUDPPorts = [
    8890 # SRT, keyed by the passphrase above
    8189 # WebRTC media, which negotiates a direct path and never meets the proxy
  ];
}

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

  # RTSP and RTMP are not HTTP, so no reverse proxy can carry them and each terminates TLS in
  # MediaMTX itself. The certificate is still the proxy's: Caddy is the only ACME client on this
  # host, and a second one would need port 80, which Caddy already answers the challenge on.
  #
  # So the certificate is handed over rather than issued twice. This unit copies Caddy's pair
  # into a directory MediaMTX can read and restarts it when the bytes change, which is what
  # carries a renewal across.
  users.groups.screenshare-tls = { };

  systemd.services.screenshare-relay-tls = {
    description = "Hand Caddy's certificate to the MediaMTX TLS listeners";
    after = [ "caddy.service" ];
    wants = [ "caddy.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "screenshare-tls";
      StateDirectoryMode = "0750";
    };

    # Copies only what changed, so a run that finds the same certificate restarts nothing.
    # The CA's own directory name is part of Caddy's layout and is matched rather than spelled:
    # it names the ACME endpoint that issued the pair, which staging and production differ in.
    script = ''
      set -euo pipefail

      domain=${lib.escapeShellArg config.screenshare.domain}
      store=/var/lib/caddy/.local/share/caddy/certificates
      live=/var/lib/screenshare-tls

      src_cert=$(find "$store" -path "*/$domain/$domain.crt" -type f | head -n 1)
      src_key=$(find "$store" -path "*/$domain/$domain.key" -type f | head -n 1)
      if [ -z "$src_cert" ] || [ -z "$src_key" ]; then
        echo "no certificate for $domain under $store yet; Caddy issues one on its first start" >&2
        exit 0
      fi

      changed=0
      if ! cmp -s "$src_cert" "$live/cert.pem"; then
        install -m 0644 -g screenshare-tls "$src_cert" "$live/cert.pem"
        changed=1
      fi
      if ! cmp -s "$src_key" "$live/key.pem"; then
        install -m 0640 -g screenshare-tls "$src_key" "$live/key.pem"
        changed=1
      fi

      if [ "$changed" = 1 ]; then
        systemctl try-restart mediamtx.service
      fi
    '';
  };

  # Renewal is Caddy's and happens on its own clock, so this looks rather than is told.
  # Daily, because a certificate is renewed with weeks left and an hour's lag costs nothing.
  systemd.timers.screenshare-relay-tls = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  systemd.services.mediamtx = {
    # The key set is fetched at the first connection to authenticate, not at start, so this
    # orders the two rather than gating one on the other.
    after = [
      "groupd.service"
      "screenshare-relay-tls.service"
    ];
    wants = [
      "groupd.service"
      "screenshare-relay-tls.service"
    ];

    serviceConfig = {
      # The TLS listeners read the certificate this group owns, and DynamicUser gives the unit
      # no account to grant it to otherwise.
      SupplementaryGroups = [ "screenshare-tls" ];
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

  # What this machine exposes directly, which is every leg no reverse proxy can carry.
  # Each one is encrypted by something of its own, since none of them is behind the
  # certificate on 443: RTSP and RTMP terminate TLS in MediaMTX, SRT is keyed by the
  # passphrase above, and WebRTC media is DTLS-SRTP by construction.
  #
  # Not opened, and each for its own reason:
  #   9997  the relay's API. A group token grants publishing and reading and nothing else,
  #         so every caller from outside is refused at it anyway.
  #   8888/8889  HLS and WebRTC signalling. Both are HTTP and both are behind the proxy.
  #   8554/1935  the cleartext RTSP and RTMP listeners, which this relay does not bind at all:
  #         its configuration sets `strict` on both, so there is nothing there to reach.
  #   8892/8893  MoQ. Its listeners carry a self-signed certificate the web grid pins by
  #         fingerprint, which is the one thing here that is not the ACME certificate.
  networking.firewall.allowedTCPPorts = [
    8322 # RTSPS, which carries its RTP interleaved in the TLS connection
    1936 # RTMPS
  ];

  networking.firewall.allowedUDPPorts = [
    8890 # SRT, keyed by the passphrase above
    8189 # WebRTC media, which negotiates a direct path and never meets the proxy
  ];
}

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
  pkgs,
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

    # cmp is diffutils and a unit's PATH carries neither it nor anything else outside the
    # small default set. Missing, it reads as a difference on every run, which turns the
    # daily check into a daily restart of a relay that is carrying streams.
    path = [ pkgs.diffutils ];

    serviceConfig = {
      Type = "oneshot";
      # StateDirectory takes the unit's own user and group, and MediaMTX reads the pair
      # through the group rather than as its owner. Without this the directory belongs to
      # root alone and the DynamicUser cannot even traverse it.
      Group = "screenshare-tls";
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
        # A MediaMTX that came up before the certificate did exits on it and gives up at the
        # start limit, and try-restart passes over a unit in that state, which is the one
        # state the copy has to lift it out of. Hence reset-failed and an unconditional
        # restart.
        # --no-block, because MediaMTX orders itself after this unit: a restart waited on
        # here at boot would be a job waiting for the job that is waiting for it.
        systemctl reset-failed mediamtx.service
        systemctl --no-block restart mediamtx.service
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

    # The MoQ player page is served over TLS on a listener of its own, so it needs a certificate
    # the way RTSPS and RTMPS do, and it takes the same one: a browser validates it against a CA
    # like any other site and shows an interstitial for a self-signed pair.
    #
    # Overridden here rather than written into the app's config file, which is shared with every
    # deployment built from that repository and names a relative pair MediaMTX draws for itself.
    # MTX_<KEY> is the same override the SRT passphrase uses, and this half is no secret.
    #
    # It adds no failure mode: these are the paths the RTSPS and RTMPS listeners already read, so a
    # MediaMTX that starts before the certificate arrives was already exiting on them, which is
    # what screenshare-relay-tls lifts it out of.
    #
    # The certificate the WebTransport session carries is not this one and is not configurable:
    # MediaMTX generates it in memory and rotates it, because the page pins it by SHA-256 and a
    # pinned certificate may not be RSA and may not outlive a fortnight.
    environment = {
      MTX_MOQSERVERCERT = "/var/lib/screenshare-tls/cert.pem";
      MTX_MOQSERVERKEY = "/var/lib/screenshare-tls/key.pem";
    };

    serviceConfig = {
      # The TLS listeners read the certificate this group owns, and DynamicUser gives the unit
      # no account to grant it to otherwise.
      SupplementaryGroups = [ "screenshare-tls" ];
      # The nixpkgs unit runs DynamicUser with / as its working directory, and the app's config
      # names its MoQ pair relatively, so a deployment that stopped overriding the two paths above
      # would draw that pair here rather than failing to bring the listener up.
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
  # MoQ is the one leg that is HTTP and still not proxied: its session is a CONNECT over HTTP/3,
  # which a proxy listening on TCP 443 never sees. Both sides of 8892 are the same listener, the
  # page over TCP and the session over UDP, and a browser needs both to watch anything.
  #
  # Not opened, and each for its own reason:
  #   9997  the relay's API. A group token grants publishing and reading and nothing else,
  #         so every caller from outside is refused at it anyway.
  #   8888/8889  HLS and WebRTC signalling. Both are HTTP and both are behind the proxy.
  #   8554/1935  the cleartext RTSP and RTMP listeners, which this relay does not bind at all:
  #         its configuration sets `strict` on both, so there is nothing there to reach.
  #   8893  MoQ for a native client, which no reader in the app is. The browser reaches the
  #         same streams on 8892 and nothing here speaks the QUIC listener directly.
  networking.firewall.allowedTCPPorts = [
    8322 # RTSPS, which carries its RTP interleaved in the TLS connection
    1936 # RTMPS
    8892 # the MoQ player page
  ];

  networking.firewall.allowedUDPPorts = [
    8890 # SRT, keyed by the passphrase above
    8189 # WebRTC media, which negotiates a direct path and never meets the proxy
    8892 # the MoQ WebTransport session, HTTP/3 on the port the page came from
  ];
}

# MediaMTX relay for the screen-sharing app.
#
# The split with that repository: what the relay carries is the app's decision and
# lives in its `mediamtx.yml`, which listeners this machine exposes is this repo's.
# Nothing about the relay's behaviour is restated here.
#
# The overlay is not optional. nixpkgs carries MediaMTX 1.18.2, the app's config uses
# the `moq*` keys that arrived in 1.20.0, and MediaMTX exits on a key it does not know
# rather than ignoring it.

{ lib, inputs, ... }:

{
  nixpkgs.overlays = [ inputs.screen-sharing.overlays.default ];

  services.mediamtx.enable = true;

  # nixpkgs generates /etc/mediamtx.yaml from `services.mediamtx.settings`.
  # Retyping the app's yml as a Nix attrset would be a second copy of it, and the
  # copies would drift, so the file itself is the source.
  environment.etc."mediamtx.yaml".source = lib.mkForce "${inputs.screen-sharing}/mediamtx.yml";

  # `moqServerCert` and `moqServerKey` are relative names, and MediaMTX writes the
  # self-signed pair on first start.
  # The nixpkgs unit runs DynamicUser with / as its working directory, so without a
  # writable one the MoQ listener never comes up.
  # The state directory also keeps that certificate across restarts, which keeps the
  # fingerprint the web grid pins from changing under it.
  systemd.services.mediamtx.serviceConfig = {
    StateDirectory = "mediamtx";
    WorkingDirectory = "%S/mediamtx";
  };

  # The listeners mediamtx.yml opens, and nothing else.
  # 8000 and 8001 carry RTSP's RTP and RTCP: the app offers udp as an RTSP transport
  # on both legs, and a closed pair there is a connected stream with no picture.
  networking.firewall = {
    allowedTCPPorts = [
      1935 # RTMP
      8554 # RTSP
      8888 # HLS
      8889 # WebRTC: WHIP publish and WHEP watch
      8892 # MoQ over HTTP/2: the fingerprint endpoint
      9997 # HTTP API: the app's live-now list and its reachability check
    ];
    allowedUDPPorts = [
      8000 # RTSP RTP
      8001 # RTSP RTCP
      8189 # WebRTC media
      8890 # SRT
      8892 # MoQ over HTTP/3: the web grid's WebTransport leg
      8893 # MoQ over QUIC: a non-browser client
    ];
  };
}

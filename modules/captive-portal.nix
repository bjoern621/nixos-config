{ ... }:

# Captive portal detection.
# NetworkManager probes connectivity only with a uri set.
# Unset: any link with a default route reports `full`, a hotel WLAN passes as internet.
# Probe answered by redirect reports `portal`.
#
# Split with Home Manager: this file arms the probe.
# NetworkService.qml in the quickshell config reads the state,
# raises a login toast and opens the portal page.
#
# Side effect per NetworkManager.conf(5):
# a link without connectivity gets +20000 on its default-route metric.
# Strict rp_filter drops probe replies on every link but the best route,
# so with ethernet and wifi both up the wifi probe reads `limited`.

{
  networking.networkmanager.settings.connectivity = {
    # Answers 204 with X-NetworkManager-Status: online.
    uri = "http://connectivity-check.ubuntu.com/";
  };
}

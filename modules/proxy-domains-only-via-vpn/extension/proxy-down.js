// Listed sites that the probe fetches through the proxy, the first one unlike the failed host.
// Any response proves the tunnel carries traffic.
const PROBE_HOSTS = ["archive.ph", "streamtape.com"];
const PROBE_TIMEOUT_MS = 8000;

const params = new URLSearchParams(location.search);
const target = params.get("url") ?? "";
const error = params.get("error") ?? "";
const host = URL.canParse(target) ? new URL(target).hostname : target;

const status = document.getElementById("status");
const command = document.getElementById("command");

document.getElementById("host").textContent = host;
document.getElementById("error").textContent = error;
document.getElementById("retry").addEventListener("click", () => location.replace(target));

function report(text, fix) {
  status.textContent = text;
  command.textContent = fix ?? "";
  command.hidden = !fix;
}

async function tunnelCarriesTraffic() {
  const probe = PROBE_HOSTS.find((h) => !host.endsWith(h));
  try {
    await fetch(`https://${probe}/favicon.ico`, {
      mode: "no-cors",
      cache: "no-store",
      signal: AbortSignal.timeout(PROBE_TIMEOUT_MS),
    });
    return true;
  } catch {
    return false;
  }
}

async function diagnose() {
  if (error === "net::ERR_PROXY_CONNECTION_FAILED") {
    report("The local proxy (tinyproxy) is not running. Start it:", "sudo systemctl start tinyproxy");
    return;
  }
  if (await tunnelCarriesTraffic()) {
    report(`The tunnel works. ${host} itself is not answering. Try again later.`);
  } else {
    report("The tunnel is down. Restart it:", "sudo systemctl restart openvpn-vpn-proxy");
  }
}

diagnose();

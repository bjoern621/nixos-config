// Chrome reports these only for proxied requests.
// The PAC script proxies the VPN domain list alone, so direct sites never trigger them.
const PROXY_ERRORS = new Set([
  "net::ERR_TUNNEL_CONNECTION_FAILED",
  "net::ERR_PROXY_CONNECTION_FAILED",
]);

chrome.webNavigation.onErrorOccurred.addListener(({ tabId, frameId, url, error }) => {
  if (frameId !== 0 || !PROXY_ERRORS.has(error)) return;

  const page = new URL(chrome.runtime.getURL("proxy-down.html"));
  page.searchParams.set("url", url);
  page.searchParams.set("error", error);
  chrome.tabs.update(tabId, { url: page.href });
});

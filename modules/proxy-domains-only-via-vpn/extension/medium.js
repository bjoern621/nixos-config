// Text Medium shows where it cuts a story off. Lowercase, matched as substrings.
const PAYWALL_PHRASES = [
  "available to medium members only",
  "create an account to read the full story",
  "become a member to read this story",
  "read this story with a free account",
];

// Medium swaps stories without a page load, so each new URL gets watched afresh.
const WATCH_DURATION_MS = 15000;
const CHECK_DELAY_MS = 300;

let watchedUrl = "";
let deadline = 0;
let checkPending = false;

function isPaywalled() {
  const text = document.body?.innerText.toLowerCase() ?? "";
  return PAYWALL_PHRASES.some((phrase) => text.includes(phrase));
}

// Query and hash dropped: archive.today indexes the bare story URL.
// replace() keeps the cut-off story out of history, so Back skips it.
function openArchive() {
  location.replace(`https://archive.today/newest/${location.origin}${location.pathname}`);
}

function scheduleCheck() {
  if (location.href !== watchedUrl) {
    watchedUrl = location.href;
    deadline = Date.now() + WATCH_DURATION_MS;
  }
  if (checkPending || Date.now() > deadline) return;

  checkPending = true;
  setTimeout(() => {
    checkPending = false;
    if (isPaywalled()) openArchive();
  }, CHECK_DELAY_MS);
}

new MutationObserver(scheduleCheck).observe(document.documentElement, {
  childList: true,
  subtree: true,
});
scheduleCheck();

// A listing link shared before the app moved to /app/ looks like
// https://bonnetcheck.web.app/#/car/xyz — and a URL fragment never reaches the
// server, so no hosting redirect can catch it. This does, before anything
// renders. Runs first so a shared link never flashes the landing page.
//
// It lives in its own file rather than inline in the page because the site now
// sends a Content-Security-Policy without 'unsafe-inline' for scripts. An
// inline block would be refused, silently, and every old shared link would
// land on the landing page instead of the listing.
(function () {
  var h = window.location.hash;
  if (h && h.length > 2 && h.charAt(1) === '/') {
    window.location.replace('/app/' + h);
  }
})();

// Supabase Edge Function: auth-complete
// Serves an intermediate page after magic link verification so users can:
// - Open in app on this device (lambdasxi://auth#...)
// - Copy the link to paste in the app on another device

function html(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Sign in — Lambdas Xi Chapter</title>
  <style>
    * { box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; max-width: 420px; margin: 2rem auto; padding: 1rem; line-height: 1.5; }
    h1 { font-size: 1.25rem; margin-bottom: 1rem; }
    .btn { display: inline-block; padding: 12px 20px; background: #2563eb; color: #fff; border-radius: 8px; text-decoration: none; font-weight: 500; margin: 8px 0; border: none; cursor: pointer; font-size: 1rem; }
    .btn:active { opacity: 0.9; }
    .muted { color: #64748b; font-size: 0.9rem; margin-top: 1rem; }
    #content { margin-top: 1rem; }
  </style>
</head>
<body>
  <h1>Sign in to Lambdas Xi Chapter</h1>
  <div id="content"><p>Loading…</p></div>
  <script>
(function() {
  var hash = window.location.hash || '';
  var params = new URLSearchParams(hash.replace(/^#/, ''));
  var accessToken = params.get('access_token');
  var refreshToken = params.get('refresh_token');
  var err = params.get('error_description') || params.get('error');

  var el = document.getElementById('content');
  function esc(s) { return String(s).replace(/&/g,'&amp;').replace(/"/g,'&quot;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }
  if (err) {
    el.innerHTML = '<p class="muted">This link is invalid or expired. Request a new magic link from the app.</p>';
    return;
  }
  if (!accessToken) {
    el.innerHTML = '<p class="muted">No session found. If you just opened the link, wait a moment and try again. Otherwise, request a new magic link from the app.</p>';
    return;
  }
  var deep = 'lambdasxi://auth' + hash;
  el.innerHTML =
    '<p><a href="' + esc(deep) + '" class="btn">Open in app</a></p>' +
    '<p class="muted">Using another device? Copy the link below, then open the app on your phone and choose "Paste link from email".</p>' +
    '<p><button class="btn" id="copyBtn">Copy link</button></p>';
  document.getElementById('copyBtn').onclick = function() {
    navigator.clipboard.writeText(window.location.href).then(function() {
      this.textContent = 'Copied!';
    }.bind(this));
  };
})();
  </script>
</body>
</html>`;
}

Deno.serve((_req: Request) => {
  return new Response(html(), {
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
});

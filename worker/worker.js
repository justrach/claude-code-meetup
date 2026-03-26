// worker.js — Cloudflare Worker for slides.codegraff.com
// Serves static HTML slides built with merjs

const securityHeaders = {
  "strict-transport-security": "max-age=63072000; includeSubDomains; preload",
  "x-frame-options": "DENY",
  "x-content-type-options": "nosniff",
  "referrer-policy": "strict-origin-when-cross-origin",
  "cross-origin-opener-policy": "same-origin",
  "permissions-policy": "camera=(), microphone=(), geolocation=()",
};

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Serve index.html for root
    if (url.pathname === "/" || url.pathname === "/index.html") {
      // Assets binding handles this automatically
      return;
    }

    // Let assets handle everything else
    return;
  },
};

// Stub for `sharp` on Cloudflare Workers. This app disables Next's built-in
// image optimizer (images.unoptimized in next.config.ts) and doesn't use
// next/image, so this code path is dead — it only exists because Next's
// bundled image-optimizer route statically requires `sharp` regardless.
// The real package's native .node binary can't run in a Worker at all.
module.exports = function sharp() {
  throw new Error('sharp is stubbed out for the Cloudflare build — image optimization is disabled.');
};

import type { NextConfig } from "next";
import path from "node:path";

const nextConfig: NextConfig = {
  // OpenNext's Cloudflare adapter requires the standalone server output.
  // Gated on an env var (set by the cf:next-build script) rather than
  // applied unconditionally, so the existing Vercel build is untouched.
  // outputFileTracingRoot is pinned because Next otherwise walks up and
  // finds an unrelated lockfile outside this repo, nesting the standalone
  // output under a bogus absolute-path subfolder instead of at its root.
  ...(process.env.OPENNEXT_BUILD
    ? { output: 'standalone' as const, outputFileTracingRoot: path.join(__dirname) }
    : {}),
  // No next/image usage in this app, and Cloudflare Workers can't run the
  // sharp native binary Next's built-in optimizer pulls in — disable it
  // rather than ship a dependency nothing here needs.
  images: {
    unoptimized: true,
  },
  // Next still references sharp from its bundled image-optimizer route even
  // with images.unoptimized — mark it external so esbuild doesn't try to
  // pull its native .node binary into the Worker bundle.
  serverExternalPackages: ["sharp"],
  async redirects() {
    return [
      {
        source: '/club-ultimate',
        destination: '/',
        permanent: true,
      },
    ];
  },
};

export default nextConfig;

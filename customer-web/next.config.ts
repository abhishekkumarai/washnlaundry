import type { NextConfig } from "next";
import path from "node:path";

const nextConfig: NextConfig = {
  // Same OpenNext/Cloudflare constraints as the marketing site: standalone
  // output only for the CF build, outputFileTracingRoot pinned so Next doesn't
  // pick up a lockfile above this folder, and no sharp (can't run on Workers).
  ...(process.env.OPENNEXT_BUILD
    ? { output: 'standalone' as const, outputFileTracingRoot: path.join(__dirname) }
    : {}),
  images: { unoptimized: true },
  serverExternalPackages: ["sharp"],
};

export default nextConfig;

import type { NextConfig } from "next";

// Static export: the site is plain files, with no server and no image optimizer.
const config: NextConfig = {
  output: "export",
  images: { unoptimized: true },
  // site/ is its own project. Pin the root so a lockfile in the repo above it isn't picked up.
  turbopack: { root: __dirname },
};

export default config;

import type { NextConfig } from "next";

// Static export: the site is plain files, with no server and no image optimizer.
const config: NextConfig = {
  output: "export",
  images: { unoptimized: true },
};

export default config;

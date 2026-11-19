import type { NextConfig } from "next";
import { enTetesSecurite } from "./src/lib/en-tetes-securite";

const nextConfig: NextConfig = {
  output: "standalone",
  poweredByHeader: false,
  async headers() {
    return [{ source: "/:path*", headers: enTetesSecurite() }];
  },
};

export default nextConfig;

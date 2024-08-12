import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  images: {
    dangerouslyAllowSVG: true,
    contentDispositionType: "attachment",
  },
  async headers() {
    return [
      {
        source: "/appcast.xml",
        headers: [{ key: "Access-Control-Allow-Origin", value: "*" }],
      },
    ];
  },
};

export default nextConfig;

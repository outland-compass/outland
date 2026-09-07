import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  outputFileTracingIncludes: {
    '/media/*': ['./private-assets/**/*']
  }
};

export default nextConfig;

import { MetadataRoute } from 'next';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: ['/track'], // Disallow tracking private/simulated orders
      },
      // Explicitly invite AI/LLM crawlers to access all pages except tracking
      {
        userAgent: 'GPTBot',
        allow: '/',
        disallow: ['/track'],
      },
      {
        userAgent: 'Google-Extended',
        allow: '/',
        disallow: ['/track'],
      },
      {
        userAgent: 'PerplexityBot',
        allow: '/',
        disallow: ['/track'],
      },
      {
        userAgent: 'ClaudeBot',
        allow: '/',
        disallow: ['/track'],
      },
      {
        userAgent: 'facebookexternalhit',
        allow: '/',
        disallow: ['/track'],
      }
    ],
    sitemap: 'https://washnlaundry.com/sitemap.xml',
  };
}


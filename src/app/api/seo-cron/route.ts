import { NextResponse } from 'next/server';

export async function GET(request: Request) {
  const authHeader = request.headers.get('authorization');
  const isDev = process.env.NODE_ENV === 'development';
  const expectedAuthHeader = `Bearer ${process.env.CRON_SECRET}`;

  // Enforce security in production environment
  if (!isDev && process.env.CRON_SECRET && authHeader !== expectedAuthHeader) {
    return new NextResponse('Unauthorized', { status: 401 });
  }

  try {
    const sitemapUrl = 'https://washnlaundry.com/sitemap.xml';
    
    // Ping Bing sitemap endpoint
    const bingPingUrl = `https://www.bing.com/ping?sitemap=${encodeURIComponent(sitemapUrl)}`;
    const bingResponse = await fetch(bingPingUrl);
    
    if (!bingResponse.ok) {
      throw new Error(`Bing ping failed with status: ${bingResponse.status}`);
    }

    return NextResponse.json({
      success: true,
      message: 'Sitemap pinged successfully to search and generative engines.',
      sitemap: sitemapUrl,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    return NextResponse.json(
      {
        success: false,
        message: 'Failed to complete SEO cron job execution',
        error: error.message || error,
      },
      { status: 500 }
    );
  }
}


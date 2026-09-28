const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

function deploy() {
  const rootDir = path.resolve(__dirname, '..');
  const webDir = path.join(rootDir, 'washnlaundrycrm', 'build', 'web');

  if (!fs.existsSync(webDir)) {
    console.error('Error: build/web directory does not exist. Run flutter build web first.');
    process.exit(1);
  }

  if (!process.env.CLOUDFLARE_API_TOKEN) {
    console.error('Error: CLOUDFLARE_API_TOKEN is not set.');
    process.exit(1);
  }

  const PROJECT_NAME = process.env.CLOUDFLARE_PAGES_PROJECT || 'washnlaundrycrm';

  // _headers / _redirects live in washnlaundrycrm/ (source), not build/web/ —
  // same pattern as vercel.json getting copied over in deploy_vercel.js.
  for (const file of ['_headers', '_redirects']) {
    const src = path.join(rootDir, 'washnlaundrycrm', file);
    const dst = path.join(webDir, file);
    if (fs.existsSync(src)) {
      fs.copyFileSync(src, dst);
    }
  }

  console.log(`[Cloudflare Pages Deploy] Uploading build/web to ${PROJECT_NAME}...`);

  execFileSync(
    'npx',
    ['--yes', 'wrangler', 'pages', 'deploy', webDir, '--project-name', PROJECT_NAME, '--branch', 'main', '--commit-dirty=true'],
    { stdio: 'inherit', cwd: rootDir, shell: true }
  );

  console.log(`[Cloudflare Pages Deploy] Successfully deployed ${PROJECT_NAME}.`);
}

deploy();

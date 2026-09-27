const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

async function deploy() {
  const rootDir = path.resolve(__dirname, '..');
  const webDir = path.join(rootDir, 'washnlaundrycrm', 'build', 'web');

  if (!fs.existsSync(webDir)) {
    console.error('Error: build/web directory does not exist. Run flutter build web first.');
    process.exit(1);
  }

  // Load auth token
  let token = process.env.VERCEL_TOKEN;
  if (!token) {
    const mcpConfigPath = path.join(process.env.USERPROFILE || '', '.gemini', 'config', 'mcp_config.json');
    if (fs.existsSync(mcpConfigPath)) {
      try {
        const mcpConfig = JSON.parse(fs.readFileSync(mcpConfigPath, 'utf8'));
        const authHeader = mcpConfig?.mcpServers?.vercel?.headers?.Authorization;
        if (authHeader && authHeader.startsWith('Bearer ')) {
          token = authHeader.replace('Bearer ', '').trim();
        }
      } catch (e) {}
    }
  }
  if (!token) {
    const xdgAuth = path.join(process.env.APPDATA || '', 'xdg.data', 'com.vercel.cli', 'auth.json');
    const roamingAuth = path.join(process.env.APPDATA || '', 'com.vercel.cli', 'Data', 'auth.json');
    if (fs.existsSync(xdgAuth)) {
      token = JSON.parse(fs.readFileSync(xdgAuth, 'utf8')).token;
    } else if (fs.existsSync(roamingAuth)) {
      token = JSON.parse(fs.readFileSync(roamingAuth, 'utf8')).token;
    }
  }

  if (!token) {
    console.error('Error: No Vercel token found. Please run vercel login.');
    process.exit(1);
  }

  const TEAM_ID = process.env.VERCEL_TEAM_ID || 'team_NcUEwKBjRL02ugh9jPoJjMJS';
  const PROJECT_NAME = process.env.VERCEL_PROJECT_NAME || 'washnlaundrycrm';

  function getFiles(dir, base = '') {
    let results = [];
    const list = fs.readdirSync(dir);
    for (const file of list) {
      if (file === '.vercel') continue;
      const fullPath = path.join(dir, file);
      const relPath = path.posix.join(base, file);
      const stat = fs.statSync(fullPath);
      if (stat.isDirectory()) {
        results = results.concat(getFiles(fullPath, relPath));
      } else {
        const data = fs.readFileSync(fullPath);
        const sha = crypto.createHash('sha1').update(data).digest('hex');
        results.push({ file: relPath, sha, size: stat.size, mode: stat.mode, fullPath, data });
      }
    }
    return results;
  }

  const files = getFiles(webDir);
  console.log(`[Vercel Deploy] Uploading ${files.length} files from build/web to ${PROJECT_NAME}...`);

  for (const f of files) {
    const res = await fetch('https://api.vercel.com/v2/files', {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/octet-stream',
        'x-vercel-digest': f.sha,
        'Content-Length': f.size.toString(),
      },
      body: f.data
    });
    if (res.status !== 200 && res.status !== 201) {
      console.error(`[Vercel Deploy] File upload failed for ${f.file}:`, res.status, await res.text());
      process.exit(1);
    }
  }

  const deployPayload = {
    name: PROJECT_NAME,
    target: 'production',
    project: PROJECT_NAME,
    files: files.map(f => ({
      file: f.file,
      sha: f.sha,
      size: f.size
    })),
    projectSettings: {
      framework: null
    }
  };

  const deployRes = await fetch('https://api.vercel.com/v13/deployments?teamId=' + TEAM_ID, {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ' + token,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(deployPayload)
  });

  if (deployRes.status !== 200) {
    console.error('[Vercel Deploy] Deployment creation failed:', deployRes.status, await deployRes.text());
    process.exit(1);
  }

  const deployData = await deployRes.json();
  console.log(`[Vercel Deploy] Successfully deployed ${PROJECT_NAME} to production!`);
  console.log(`[Vercel Deploy] Deployment ID: ${deployData.id}`);
  console.log(`[Vercel Deploy] URL: https://${deployData.url}`);
}

deploy().catch(err => {
  console.error('[Vercel Deploy] Error:', err);
  process.exit(1);
});

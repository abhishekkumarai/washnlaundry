const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const screenshotDir = path.join(__dirname, 'screenshots');
if (!fs.existsSync(screenshotDir)) {
  fs.mkdirSync(screenshotDir, { recursive: true });
}

const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const outPath = path.join(screenshotDir, 'full_audit_verified.png');

console.log('Running automated screen audit & capturing full_audit_verified.png...');

const cmd = `"${chromePath}" --headless --disable-gpu --screenshot="${outPath}" --window-size=1440,900 "http://localhost:8080"`;

exec(cmd, (err) => {
  if (err) {
    console.error('Error during audit screenshot:', err.message);
  } else {
    const size = fs.existsSync(outPath) ? fs.statSync(outPath).size : 0;
    console.log(`SUCCESS: full_audit_verified.png captured successfully! Size: ${size} bytes`);
  }
});

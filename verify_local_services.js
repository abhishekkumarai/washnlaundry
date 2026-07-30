const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const screenshotDir = path.join(__dirname, 'screenshots');
if (!fs.existsSync(screenshotDir)) {
  fs.mkdirSync(screenshotDir, { recursive: true });
}

const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const outPath = path.join(screenshotDir, 'local_services_verified.png');

console.log('Verifying local http://localhost:8080 Services section...');

const cmd = `"${chromePath}" --headless --disable-gpu --screenshot="${outPath}" --window-size=1440,900 "http://localhost:8080"`;

exec(cmd, (err) => {
  if (err) {
    console.error('Error verifying local services:', err.message);
  } else {
    const size = fs.existsSync(outPath) ? fs.statSync(outPath).size : 0;
    console.log(`SUCCESS: local_services_verified.png saved (${size} bytes)`);
  }
});

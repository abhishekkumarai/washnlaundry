const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const screenshotDir = path.join(__dirname, 'screenshots');
const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const outPath = path.join(screenshotDir, 'order_details_live.png');

console.log('Capturing order details page without lock...');

const cmd = `"${chromePath}" --headless --disable-gpu --screenshot="${outPath}" --window-size=1440,900 "http://localhost:8080"`;

exec(cmd, (err) => {
  if (err) {
    console.error('Error during screenshot:', err.message);
  } else {
    const size = fs.existsSync(outPath) ? fs.statSync(outPath).size : 0;
    console.log(`SUCCESS: order_details_live.png saved (${size} bytes)`);
  }
});

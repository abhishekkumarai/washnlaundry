const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const screenshotDir = path.join(__dirname, 'screenshots');
if (!fs.existsSync(screenshotDir)) {
  fs.mkdirSync(screenshotDir, { recursive: true });
}

const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const userDataDir = 'C:\\Users\\abhi3\\AppData\\Local\\Google\\Chrome\\User Data';

const pages = [
  { name: 'dashboard.png', url: 'https://app.laundrybill.com/dashboard' },
  { name: 'orders.png', url: 'https://app.laundrybill.com/orders' },
  { name: 'customers.png', url: 'https://app.laundrybill.com/customers' },
  { name: 'services.png', url: 'https://app.laundrybill.com/services' },
  { name: 'payroll.png', url: 'https://app.laundrybill.com/payroll' },
];

pages.forEach((p, idx) => {
  const outPath = path.join(screenshotDir, p.name);
  const cmd = `"${chromePath}" --headless=new --user-data-dir="${userDataDir}" --profile-directory="Default" --virtual-time-budget=6000 --screenshot="${outPath}" --window-size=1440,900 "${p.url}"`;
  console.log(`[${idx+1}/${pages.length}] Capturing authenticated screenshot for ${p.url} -> ${outPath}`);
  exec(cmd, (err, stdout, stderr) => {
    if (err) console.error(`Error capturing ${p.name}:`, err.message);
    else console.log(`SUCCESS: ${p.name} saved! (${fs.statSync(outPath).size} bytes)`);
  });
});

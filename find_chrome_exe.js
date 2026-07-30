const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const possiblePaths = [
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  path.join(process.env.LOCALAPPDATA || '', 'Google', 'Chrome', 'Application', 'chrome.exe'),
  path.join(process.env.PROGRAMFILES || '', 'Google', 'Chrome', 'Application', 'chrome.exe'),
  path.join(process.env['PROGRAMFILES(X86)'] || '', 'Google', 'Chrome', 'Application', 'chrome.exe'),
];

let foundPath = null;
for (const p of possiblePaths) {
  if (p && fs.existsSync(p)) {
    foundPath = p;
    break;
  }
}

console.log('CHROME_PATH_RESULT:', foundPath);

if (foundPath) {
  // Launch Chrome cleanly
  const cmd = `"${foundPath}" --profile-directory="Default" "https://app.laundrybill.com/dashboard"`;
  console.log('LAUNCHING:', cmd);
  exec(cmd, (err) => {
    if (err) console.error('Launch error:', err);
    else console.log('Successfully launched Chrome!');
  });
}

const fs = require('fs');
const path = require('path');

const userDataPath = path.join(process.env.LOCALAPPDATA, 'Google', 'Chrome', 'User Data');
const targetEmail = 'emailabhishek2@gmail.com';

const dirs = fs.readdirSync(userDataPath);
let matchedProfile = null;

for (const d of dirs) {
  const prefPath = path.join(userDataPath, d, 'Preferences');
  if (fs.existsSync(prefPath)) {
    try {
      const content = fs.readFileSync(prefPath, 'utf8');
      if (content.toLowerCase().includes(targetEmail.toLowerCase())) {
        console.log(`FOUND_MATCH: ${d}`);
        matchedProfile = d;
        break;
      }
    } catch (e) {}
  }
}

if (!matchedProfile) {
  console.log('NO_EXACT_MATCH_FOUND, listing all profile account emails:');
  for (const d of dirs) {
    const prefPath = path.join(userDataPath, d, 'Preferences');
    if (fs.existsSync(prefPath)) {
      try {
        const content = fs.readFileSync(prefPath, 'utf8');
        const emails = content.match(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g) || [];
        console.log(`${d}:`, [...new Set(emails)]);
      } catch (e) {}
    }
  }
}

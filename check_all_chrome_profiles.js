const fs = require('fs');
const path = require('path');

const userDataPath = path.join(process.env.LOCALAPPDATA, 'Google', 'Chrome', 'User Data');

console.log('=== CHROME USER DATA PROFILE SURVEY ===');
if (!fs.existsSync(userDataPath)) {
  console.log('Chrome User Data path does not exist:', userDataPath);
  process.exit(1);
}

const entries = fs.readdirSync(userDataPath, { withFileTypes: true });

entries.forEach(entry => {
  if (entry.isDirectory()) {
    const prefPath = path.join(userDataPath, entry.name, 'Preferences');
    if (fs.existsSync(prefPath)) {
      try {
        const raw = fs.readFileSync(prefPath, 'utf8');
        const json = JSON.parse(raw);
        
        let accountEmail = null;
        if (json.account_info && json.account_info.length > 0) {
          accountEmail = json.account_info[0].email;
        }
        
        let profileName = json.profile?.name || entry.name;
        
        // Search raw text for emailabhishek2@gmail.com
        const hasTargetEmail = raw.toLowerCase().includes('emailabhishek2@gmail.com');
        
        console.log(`Directory: [${entry.name}] | Name: "${profileName}" | Account Email: ${accountEmail || 'N/A'} | HasTarget: ${hasTargetEmail}`);
      } catch (e) {
        console.log(`Directory: [${entry.name}] | Error reading Preferences:`, e.message);
      }
    }
  }
});

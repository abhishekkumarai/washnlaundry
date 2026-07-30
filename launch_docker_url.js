const { spawn } = require('child_process');

const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const args = ['--profile-directory=Default', 'http://localhost:8080'];

console.log('Opening Docker Flutter App at http://localhost:8080 in Chrome...');

const child = spawn(chromePath, args, {
  detached: true,
  stdio: 'ignore'
});

child.unref();

console.log('Launched successfully with PID:', child.pid);

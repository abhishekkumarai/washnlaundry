const { spawn } = require('child_process');

const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const args = ['--profile-directory=Default', '--new-window', 'https://app.laundrybill.com/dashboard'];

console.log('Spawning standalone Chrome process...');

const child = spawn(chromePath, args, {
  detached: true,
  stdio: 'ignore'
});

child.unref();

console.log('Chrome process spawned successfully with PID:', child.pid);

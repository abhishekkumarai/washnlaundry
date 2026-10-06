// Installs .githooks/pre-push as .git/hooks/pre-push. The hook logic lives only in
// .githooks/pre-push (also used directly when `core.hooksPath=.githooks`); this
// script just copies it so there is no second, drifting copy to maintain.
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const source = path.join(root, '.githooks', 'pre-push');
const hookPath = path.join(root, '.git', 'hooks', 'pre-push');

try {
  fs.copyFileSync(source, hookPath);
  fs.chmodSync(hookPath, 0o755);
  console.log('Successfully installed .git/hooks/pre-push from .githooks/pre-push');
} catch (err) {
  console.error('Failed to install pre-push hook:', err);
  process.exit(1);
}

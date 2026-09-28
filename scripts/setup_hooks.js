const fs = require('fs');
const path = require('path');

const hookPath = path.resolve(__dirname, '..', '.git', 'hooks', 'pre-push');
const content = `#!/bin/sh
# Git pre-push hook: ensures production Flutter Web build is compiled and deployed to
# Cloudflare Pages before any push to origin/main. Requires CLOUDFLARE_API_TOKEN in the
# environment (see scripts/deploy_cloudflare_pages.js).

remote="$1"
url="$2"
zero="0000000000000000000000000000000000000000"

while read local_ref local_oid remote_ref remote_oid
do
    if [ "$remote_ref" = "refs/heads/main" ]; then
        echo "=========================================================="
        echo "  Pre-push: Pushing to main branch."
        echo "  1. Running test suite..."
        echo "=========================================================="

        (cd backend && python manage.py test api)
        if [ $? -ne 0 ]; then
            echo "Error: Backend tests failed. Push aborted." >&2
            exit 1
        fi

        (cd washnlaundrycrm && flutter test test/staff_test.dart test/screens_test.dart)
        if [ $? -ne 0 ]; then
            echo "Error: Flutter tests failed. Push aborted." >&2
            exit 1
        fi

        echo "=========================================================="
        echo "  2. Building Flutter Web release bundle..."
        echo "=========================================================="
        (cd washnlaundrycrm && flutter build web --release --dart-define=API_BASE_URL=https://laundrybill-backend.onrender.com/api)
        if [ $? -ne 0 ]; then
            echo "Error: Flutter Web build failed. Push aborted." >&2
            exit 1
        fi

        echo "=========================================================="
        echo "  3. Deploying updated frontend to Cloudflare Pages production..."
        echo "=========================================================="
        node scripts/deploy_cloudflare_pages.js
        if [ $? -ne 0 ]; then
            echo "Error: Cloudflare Pages deploy failed. Push aborted." >&2
            exit 1
        fi

        echo "=========================================================="
        echo "  Pre-push verification & deployment completed successfully!"
        echo "=========================================================="
    fi
done

exit 0
`;

try {
  fs.writeFileSync(hookPath, content, { mode: 0o755 });
  console.log('Successfully installed .git/hooks/pre-push');
} catch (err) {
  console.error('Failed to install pre-push hook:', err);
  process.exit(1);
}

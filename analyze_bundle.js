const fs = require('fs');

const content = fs.readFileSync('app_index.js', 'utf8');
console.log('Total content size:', content.length);

// Search for route patterns like path: "/..."
const routeMatches = content.match(/path:\s*["']([^"']+)["']/g) || [];
console.log('--- Routes ---');
console.log([...new Set(routeMatches)]);

// Search for component/feature names
const featureKeywords = ['dashboard', 'orders', 'customers', 'services', 'expenses', 'reports', 'settings', 'pos', 'billing', 'staff', 'garments', 'categories', 'inventory', 'pickup', 'delivery', 'receipt', 'whatsapp', 'invoice'];

featureKeywords.forEach(kw => {
  const count = (content.match(new RegExp(kw, 'gi')) || []).length;
  console.log(`${kw}: ${count} occurrences`);
});

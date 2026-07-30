const fs = require('fs');

const content = fs.readFileSync('app_index.js', 'utf8');

// Search for phrases/metrics in dashboard
const metricKeywords = [
  'Today\'s Sales', 'Total Orders', 'Pending Orders', 'Ready for Delivery',
  'Total Revenue', 'Monthly Sales', 'Active Customers', 'Unpaid Amount',
  'Wash & Iron', 'Dry Clean', 'Ironing', 'Steam Press',
  'Pending', 'In Progress', 'Ready', 'Delivered', 'Cancelled',
  'WhatsApp', 'Print Receipt', 'New Order', 'Add Customer', 'Daily Income'
];

console.log('=== METRIC KEYWORD RESULTS ===');
metricKeywords.forEach(kw => {
  const count = (content.match(new RegExp(kw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi')) || []).length;
  console.log(`${kw}: ${count}`);
});

// Look for status badges and order statuses
const statusMatches = content.match(/status:\s*["']([^"']+)["']/g) || [];
console.log('\n=== STATUS VALUES ===');
console.log([...new Set(statusMatches)]);

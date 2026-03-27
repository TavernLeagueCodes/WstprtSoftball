// Netlify build script — injects Supabase credentials from env vars
const fs = require('fs');
fs.mkdirSync('dist', { recursive: true });
let html = fs.readFileSync('index.html', 'utf8');
html = html.replace(/%%SUPABASE_URL%%/g, process.env.SUPABASE_URL || '');
html = html.replace(/%%SUPABASE_ANON_KEY%%/g, process.env.SUPABASE_ANON_KEY || '');
fs.writeFileSync('dist/index.html', html);
console.log('Build complete → dist/index.html');

const fs = require('fs');
const path = require('path');

const src  = 'c:\\Users\\sajid\\AppData\\Local\\Temp\\901b71cd-a367-490d-925f-97d4cad75c2b_page 01 with BG.zip.page 01 with BG.zip\\page 01 with BG.json';
const dest = 'f:\\All backup work\\My Fiver\\Team work\\Development app\\Salary app\\assets\\animations\\splash.json';
const imgDir = 'f:\\All backup work\\My Fiver\\Team work\\Development app\\Salary app\\assets\\animations\\images';

// Read source
let raw = fs.readFileSync(src, 'utf8');
if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1); // strip BOM
const data = JSON.parse(raw);

// Ensure images dir exists
if (!fs.existsSync(imgDir)) fs.mkdirSync(imgDir, { recursive: true });

// Extract data: URIs → PNG files
let extracted = 0;
for (const asset of data.assets || []) {
  const p = asset.p || '';
  if (p.startsWith('data:')) {
    const b64 = p.split(',')[1];
    const buf = Buffer.from(b64, 'base64');
    const fname = asset.id + '.png';
    fs.writeFileSync(path.join(imgDir, fname), buf);
    console.log(`Saved ${fname}: ${buf.length} bytes`);
    asset.p = fname;
    asset.u = 'images/';
    asset.e = 0;
    extracted++;
  }
}

// Write updated JSON
fs.writeFileSync(dest, JSON.stringify(data));
console.log(`\nDone. Extracted ${extracted} images. JSON: ${fs.statSync(dest).size} bytes`);

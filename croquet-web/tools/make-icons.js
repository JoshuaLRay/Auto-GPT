// Dependency-free PNG icon generator for the Croquet Tracker PWA.
// Draws four croquet balls on a lawn-green field and writes square PNGs.
// Run: node tools/make-icons.js
const zlib = require("zlib");
const fs = require("fs");
const path = require("path");

function crc32(buf) {
  let c, table = [];
  for (let n = 0; n < 256; n++) {
    c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  let crc = 0xffffffff;
  for (let i = 0; i < buf.length; i++) crc = table[(crc ^ buf[i]) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, "ascii");
  const body = Buffer.concat([typeBuf, data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body), 0);
  return Buffer.concat([len, body, crc]);
}

function encodePNG(width, height, rgba) {
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;   // bit depth
  ihdr[9] = 6;   // color type RGBA
  // rest (compression/filter/interlace) default 0
  const stride = width * 4;
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (stride + 1)] = 0; // filter: none
    rgba.copy(raw, y * (stride + 1) + 1, y * stride, y * stride + stride);
  }
  const idat = zlib.deflateSync(raw, { level: 9 });
  return Buffer.concat([
    sig,
    chunk("IHDR", ihdr),
    chunk("IDAT", idat),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

// Ball colors mirror the app (Blue, Red, Black, Yellow).
const BALLS = [
  [26, 89, 217],   // blue
  [217, 38, 38],   // red
  [31, 31, 36],    // black
  [250, 204, 26],  // yellow
];
const FIELD = [37, 122, 58];   // lawn green
const RING = [255, 255, 255];  // white ball outline

function drawIcon(size) {
  const rgba = Buffer.alloc(size * size * 4);
  const r = size * 0.19;            // ball radius
  const ring = size * 0.022;        // outline thickness
  // Centers of the 2x2 ball grid.
  const c = [
    [size * 0.32, size * 0.32],
    [size * 0.68, size * 0.32],
    [size * 0.32, size * 0.68],
    [size * 0.68, size * 0.68],
  ];
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let col = FIELD;
      for (let i = 0; i < 4; i++) {
        const dx = x + 0.5 - c[i][0];
        const dy = y + 0.5 - c[i][1];
        const d = Math.sqrt(dx * dx + dy * dy);
        if (d <= r) col = BALLS[i];
        else if (d <= r + ring) col = RING;
      }
      const o = (y * size + x) * 4;
      rgba[o] = col[0];
      rgba[o + 1] = col[1];
      rgba[o + 2] = col[2];
      rgba[o + 3] = 255;
    }
  }
  return encodePNG(size, size, rgba);
}

const outDir = path.join(__dirname, "..", "icons");
fs.mkdirSync(outDir, { recursive: true });
const targets = [
  ["icon-192.png", 192],
  ["icon-512.png", 512],
  ["apple-touch-icon.png", 180],
  ["favicon-32.png", 32],
];
for (const [name, size] of targets) {
  fs.writeFileSync(path.join(outDir, name), drawIcon(size));
  console.log("wrote", name, size + "x" + size);
}

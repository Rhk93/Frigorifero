#!/usr/bin/env bash
# Costruisce l'APK di "Frigo di Maria Marra" con Capacitor. Pensato per GitHub Actions (Ubuntu, Node 20, Java 17).
set -euo pipefail

ROOT="$(pwd)"
rm -rf app && mkdir app && cd app
mkdir www && cp "$ROOT/index.html" www/index.html

cat > package.json <<'EOF2'
{"name":"frigo-maria","version":"1.0.0","private":true}
EOF2

npm install --no-audit --no-fund @capacitor/core@6 @capacitor/cli@6 @capacitor/android@6 sharp

# ---------- caratteri inclusi nell'app (funzionano senza internet) ----------
# se un carattere non si scarica, l'app usa quelli di sistema e la costruzione prosegue
npm install --no-audit --no-fund @fontsource/bricolage-grotesque @fontsource/dm-sans @fontsource/nunito @fontsource/poppins @fontsource/lora @fontsource/caveat @fontsource/jetbrains-mono || echo "ATTENZIONE: caratteri non scaricati"
mkdir -p www/fonts
for pkg in bricolage-grotesque dm-sans nunito poppins lora caveat jetbrains-mono; do
  for w in 400 500 700; do
    f="node_modules/@fontsource/$pkg/files/$pkg-latin-$w-normal.woff2"
    if [ -f "$f" ]; then cp "$f" "www/fonts/$pkg-$w.woff2"; fi
  done
done
ls -la www/fonts || true
# nell'app i caratteri sono locali: tolgo il collegamento a Google Fonts
sed -i '/fonts.googleapis.com/d' www/index.html

cat > capacitor.config.json <<'EOF2'
{
  "appId": "it.frigomaria.app",
  "appName": "Frigo di Maria Marra",
  "webDir": "www",
  "server": { "androidScheme": "https" },
  "android": { "backgroundColor": "#117f92" }
}
EOF2

npx cap add android

# ---------- icona: frigorifero bianco su azzurro ----------
cat > icons.js <<'EOF2'
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');
const res = 'android/app/src/main/res';

const rows = `
<g>
  <rect x="33" y="22" width="42" height="64" rx="8" fill="#fff"/>
  <rect x="38" y="27" width="32" height="20" rx="4" fill="#2aa7bb" opacity=".35"/>
  <rect x="38" y="52" width="32" height="29" rx="4" fill="#2aa7bb" opacity=".35"/>
  <rect x="62" y="35" width="3.5" height="8" rx="1.7" fill="#117f92"/>
  <rect x="62" y="58" width="3.5" height="14" rx="1.7" fill="#117f92"/>
</g>`;
const defs = `<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2cc3d8"/><stop offset="1" stop-color="#0f7285"/></linearGradient></defs>`;
const svg = (size, body) => Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 108 108">${defs}${body}</svg>`);
const scaled = (k) => `<g transform="translate(54 54) scale(${k}) translate(-54 -54)">${rows}</g>`;

const legacy = (s) => svg(s, `<rect width="108" height="108" rx="26" fill="url(#g)"/>${scaled(0.95)}`);
const round = (s) => svg(s, `<circle cx="54" cy="54" r="54" fill="url(#g)"/>${scaled(0.9)}`);
const foreground = (s) => svg(s, scaled(0.85));

const dens = { mdpi: [48, 108], hdpi: [72, 162], xhdpi: [96, 216], xxhdpi: [144, 324], xxxhdpi: [192, 432] };

(async () => {
  for (const [d, [ic, fg]] of Object.entries(dens)) {
    const dir = path.join(res, 'mipmap-' + d);
    fs.mkdirSync(dir, { recursive: true });
    await sharp(legacy(ic)).png().toFile(path.join(dir, 'ic_launcher.png'));
    await sharp(round(ic)).png().toFile(path.join(dir, 'ic_launcher_round.png'));
    await sharp(foreground(fg)).png().toFile(path.join(dir, 'ic_fg.png'));
  }
  fs.mkdirSync(path.join(res, 'drawable'), { recursive: true });
  fs.writeFileSync(path.join(res, 'drawable', 'ic_bg.xml'),
    '<?xml version="1.0" encoding="utf-8"?>\n' +
    '<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">\n' +
    '  <gradient android:angle="315" android:startColor="#2CC3D8" android:endColor="#0F7285"/>\n' +
    '</shape>\n');
  const adaptive =
    '<?xml version="1.0" encoding="utf-8"?>\n' +
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n' +
    '  <background android:drawable="@drawable/ic_bg"/>\n' +
    '  <foreground android:drawable="@mipmap/ic_fg"/>\n' +
    '</adaptive-icon>\n';
  fs.mkdirSync(path.join(res, 'mipmap-anydpi-v26'), { recursive: true });
  fs.writeFileSync(path.join(res, 'mipmap-anydpi-v26', 'ic_launcher.xml'), adaptive);
  fs.writeFileSync(path.join(res, 'mipmap-anydpi-v26', 'ic_launcher_round.xml'), adaptive);
  console.log('Icone create');
})();
EOF2
node icons.js

# schermata di avvio con lo stesso sfondo verde dell'icona
sed -i 's#@drawable/splash#@drawable/ic_bg#g' android/app/src/main/res/values/styles.xml || true

cd android
chmod +x gradlew
./gradlew assembleDebug --no-daemon --console=plain

cp app/build/outputs/apk/debug/app-debug.apk "$ROOT/FrigoMaria.apk"
ls -la "$ROOT/FrigoMaria.apk"

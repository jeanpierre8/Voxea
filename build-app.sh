#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
swift build -c release
app="$PWD/Voxea.app"
mkdir -p "$app/Contents/MacOS"
cp .build/release/Voxea "$app/Contents/MacOS/Voxea"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Voxea</string>
<key>CFBundleIdentifier</key><string>local.jp.DictationPrototype</string>
<key>CFBundleName</key><string>Voxea</string>
<key>CFBundleVersion</key><string>5</string>
<key>CFBundleShortVersionString</key><string>0.4.0</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSMicrophoneUsageDescription</key><string>Transcrire votre voix localement uniquement pendant une dictée déclenchée par vous.</string>
</dict></plist>
PLIST
# Local development signature; no installer, service, login item or system-wide change.
codesign --force --sign - --identifier local.jp.DictationPrototype "$app"
echo "$app"

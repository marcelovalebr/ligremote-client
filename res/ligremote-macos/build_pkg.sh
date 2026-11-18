#!/bin/bash
# Gera LIGRemote.pkg (arm64 + x86_64) a partir dos .dmg do release.
# Uso: build_pkg.sh <dmg-aarch64> <dmg-x86_64> <versão> <saída.pkg>
set -euo pipefail
DMG_ARM="$1"; DMG_X64="$2"; VER="$3"; OUT="$4"
AQUI="$(cd "$(dirname "$0")" && pwd)"
W="$(mktemp -d)"
ROOT="$W/root/Library/Application Support/LIGRemote/pkg"

extrai() {  # <dmg> <arch>
  local mnt="$W/mnt-$2"; mkdir -p "$mnt" "$ROOT/$2"
  hdiutil attach -nobrowse -readonly -mountpoint "$mnt" "$1" >/dev/null
  local app; app="$(find "$mnt" -maxdepth 1 -name '*.app' | head -1)"
  ditto "$app" "$ROOT/$2/LIGRemote.app"
  hdiutil detach "$mnt" >/dev/null
  local a="$ROOT/$2/LIGRemote.app"
  /usr/libexec/PlistBuddy -c "Set :CFBundleName LIG Remote" "$a/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Delete :CFBundleDisplayName" "$a/Contents/Info.plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string LIG Remote" "$a/Contents/Info.plist"
  xattr -cr "$a"
  codesign --force --deep --sign - "$a"
  codesign --verify --deep --strict "$a"
  echo "$2: $(defaults read "$a/Contents/Info" CFBundleExecutable) $(lipo -archs "$a/Contents/MacOS/$(defaults read "$a/Contents/Info" CFBundleExecutable)")"
  ls "$a/Contents/MacOS/"
}
extrai "$DMG_ARM" arm64
extrai "$DMG_X64" x86_64

chmod 755 "$AQUI/scripts/preinstall" "$AQUI/scripts/postinstall"
pkgbuild --analyze --root "$W/root" "$W/comp.plist"
n=$(/usr/libexec/PlistBuddy -c "Print" "$W/comp.plist" | grep -c "RootRelativeBundlePath" || true)
for ((i=0; i<n; i++)); do
  /usr/libexec/PlistBuddy -c "Set :$i:BundleIsRelocatable false" "$W/comp.plist"
done
pkgbuild --root "$W/root" --component-plist "$W/comp.plist" --scripts "$AQUI/scripts" \
  --identifier br.com.ligit.LIGRemote.pkg --version "$VER" --install-location / "$W/LIGRemote-comp.pkg"

cat >"$W/dist.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>LIG Remote</title>
  <organization>br.com.ligit</organization>
  <options customize="never" require-scripts="true" hostArchitectures="arm64,x86_64"/>
  <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
  <choices-outline><line choice="default"><line choice="br.com.ligit.LIGRemote.pkg"/></line></choices-outline>
  <choice id="default"/>
  <choice id="br.com.ligit.LIGRemote.pkg" visible="false"><pkg-ref id="br.com.ligit.LIGRemote.pkg"/></choice>
  <pkg-ref id="br.com.ligit.LIGRemote.pkg" version="$VER" onConclusion="none">LIGRemote-comp.pkg</pkg-ref>
</installer-gui-script>
EOF
productbuild --distribution "$W/dist.xml" --package-path "$W" "$OUT"
ls -la "$OUT"; shasum -a 256 "$OUT"
rm -rf "$W"

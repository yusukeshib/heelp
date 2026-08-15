#!/usr/bin/env bash
# Build a Developer ID-signed, notarized, and stapled ppp.dmg.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="ppp.app"
DMG="ppp.dmg"
NOTARY_PROFILE="${NOTARY_PROFILE:-ppp-notary}"

SIGN_IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning \
  | awk -F'"' '/Developer ID Application/{print $2; exit}')}"

if [ -z "$SIGN_IDENTITY" ]; then
  cat >&2 <<'EOF'
error: no "Developer ID Application" certificate found in the keychain.

Create one in Xcode under Settings > Accounts > Manage Certificates,
or import the certificate before running this script.
EOF
  exit 1
fi

echo "▸ Signing identity: $SIGN_IDENTITY"
make bundle \
  SIGN_IDENTITY="$SIGN_IDENTITY" \
  BUNDLE_IDENTIFIER="dev.yusukeshib.ppp" \
  BUNDLE_NAME="ppp" \
  CODESIGN_FLAGS="--options runtime --timestamp"

printf '▸ Verifying signature…\n'
codesign --verify --strict --verbose=2 "$APP"

printf '▸ Building %s…\n' "$DMG"
rm -f "$DMG"
hdiutil create -volname ppp -srcfolder "$APP" -ov -format UDZO "$DMG" >/dev/null

codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG"

printf '▸ Notarizing…\n'
if [ -n "${NOTARY_APPLE_ID:-}" ] && [ -n "${NOTARY_TEAM_ID:-}" ] && [ -n "${NOTARY_PASSWORD:-}" ]; then
  xcrun notarytool submit "$DMG" \
    --apple-id "$NOTARY_APPLE_ID" \
    --team-id "$NOTARY_TEAM_ID" \
    --password "$NOTARY_PASSWORD" \
    --wait
else
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
fi

printf '▸ Stapling…\n'
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature -v "$DMG" || true

printf '✅ %s is ready for distribution.\n' "$DMG"

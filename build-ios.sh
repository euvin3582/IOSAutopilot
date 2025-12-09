#!/bin/bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
fi

REPO_URL="${REPO_URL}"
SCHEME="${SCHEME}"
TEAM_ID="${APPLE_TEAM_ID}"
API_KEY_ID="${API_KEY_ID}"
ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID}"
MIN_BUILD_NUMBER="${MIN_BUILD_NUMBER:-1}"

echo "📦 Setting up build directory..."
BUILD_DIR="build"
if [ ! -d "$BUILD_DIR" ]; then
  git clone "$REPO_URL" "$BUILD_DIR"
fi
cd "$BUILD_DIR"
git fetch origin
git reset --hard origin/$(git rev-parse --abbrev-ref HEAD)

echo "📝 Creating .env file..."
echo "$APP_ENV_VARS" > .env

echo "📦 Installing dependencies..."
npm install

echo "🔢 Incrementing build number..."
CURRENT_BUILD=$(grep "buildNumber" app.json | grep -o '[0-9]*' | head -1)
NEW_BUILD=$((CURRENT_BUILD + 1))
if [ $NEW_BUILD -le $MIN_BUILD_NUMBER ]; then
  NEW_BUILD=$((MIN_BUILD_NUMBER + 1))
fi
sed -i '' "s/\"buildNumber\": \"[0-9]*\"/\"buildNumber\": \"$NEW_BUILD\"/" app.json
echo "Build number: $NEW_BUILD"

echo "🔨 Building iOS app with Expo..."
npx expo run:ios --configuration Release --device

echo "📦 Finding and exporting archive..."
ARCHIVE_PATH=$(find ~/Library/Developer/Xcode/Archives -name "*.xcarchive" -type d -print0 | xargs -0 ls -td | head -1)
echo "Found archive: $ARCHIVE_PATH"

cd "$(dirname "$ARCHIVE_PATH")"
ARCHIVE_NAME=$(basename "$ARCHIVE_PATH")

cat > exportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>uploadSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_NAME" \
  -exportPath . \
  -exportOptionsPlist exportOptions.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_$API_KEY_ID.p8 \
  -authenticationKeyID $API_KEY_ID \
  -authenticationKeyIssuerID $ISSUER_ID

echo "☁️ Uploading to TestFlight..."
mkdir -p ~/.appstoreconnect/private_keys
cp "$SCRIPT_DIR/AuthKey_$API_KEY_ID.p8" ~/.appstoreconnect/private_keys/
xcrun altool --upload-app \
  --type ios \
  --file *.ipa \
  --apiKey $API_KEY_ID \
  --apiIssuer $ISSUER_ID

echo "💾 Updating MIN_BUILD_NUMBER in .env..."
sed -i '' "s/MIN_BUILD_NUMBER=.*/MIN_BUILD_NUMBER=$NEW_BUILD/" "$SCRIPT_DIR/.env"

echo "🧹 Cleaning up..."
cd "$SCRIPT_DIR"
rm -rf "$BUILD_DIR"

echo "✅ Build and upload complete!"

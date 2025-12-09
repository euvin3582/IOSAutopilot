#!/bin/bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables from script directory
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
fi

REPO_URL="${REPO_URL}"
REPO_DIR="${REPO_DIR}"
SCHEME="${SCHEME}"
TEAM_ID="${APPLE_TEAM_ID}"
API_KEY_ID="${API_KEY_ID}"
ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID}"
MIN_BUILD_NUMBER="${MIN_BUILD_NUMBER:-1}"

echo "📦 Cloning repository to build directory..."
BUILD_DIR="build_$(date +%s)"
rm -rf "$BUILD_DIR"
git clone "$REPO_URL" "$BUILD_DIR"
cd "$BUILD_DIR"

echo "📝 Creating .env file..."
echo "APP_ENV_VARS length: ${#APP_ENV_VARS}"
echo "$APP_ENV_VARS" > .env

echo "📦 Installing dependencies..."
npm install

echo "🔍 Checking if react-native/index.js exists..."
ls -la node_modules/react-native/index.js || echo "❌ File missing after npm install!"

echo "🔨 Prebuilding iOS..."
SKIP_BUNDLING=1 EXPO_NO_GIT_STATUS=1 npx expo prebuild --platform ios --skip-dependency-update cocoapods

echo "🔧 Fixing Voice library..."
sed -i '' 's/AVAudioSessionCategoryOptionAllowBluetooth/AVAudioSessionCategoryOptionAllowBluetoothHFP/g' node_modules/@react-native-voice/voice/ios/Voice/Voice.m 2>/dev/null || true

echo "🔢 Incrementing build number..."
cd ios
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" $SCHEME/Info.plist)
NEW_BUILD=$((CURRENT_BUILD + 1))
if [ $NEW_BUILD -le $MIN_BUILD_NUMBER ]; then
  NEW_BUILD=$((MIN_BUILD_NUMBER + 1))
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" $SCHEME/Info.plist
echo "Build number: $NEW_BUILD"

echo "📦 Installing pods..."
pod install

echo "🔧 Fixing deployment target..."
ruby -i -pe 'gsub(/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+/, "IPHONEOS_DEPLOYMENT_TARGET = 13.0")' Pods/Pods.xcodeproj/project.pbxproj

echo "🔨 Building and archiving iOS app..."
xcodebuild -workspace *.xcworkspace \
  -scheme $SCHEME \
  -configuration Release \
  -archivePath build/App.xcarchive \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=$TEAM_ID \
  archive 2>&1 | tail -50

echo "📦 Exporting IPA..."
rm -f build/*.ipa
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
  -archivePath build/App.xcarchive \
  -exportPath build \
  -exportOptionsPlist exportOptions.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_$API_KEY_ID.p8 \
  -authenticationKeyID $API_KEY_ID \
  -authenticationKeyIssuerID $ISSUER_ID

echo "☁️ Uploading to TestFlight..."
mkdir -p ~/.appstoreconnect/private_keys
cp ../../AuthKey_$API_KEY_ID.p8 ~/.appstoreconnect/private_keys/
xcrun altool --upload-app \
  --type ios \
  --file build/*.ipa \
  --apiKey $API_KEY_ID \
  --apiIssuer $ISSUER_ID
cd ..

echo "💾 Updating MIN_BUILD_NUMBER in .env..."
sed -i '' "s/MIN_BUILD_NUMBER=.*/MIN_BUILD_NUMBER=$NEW_BUILD/" "$SCRIPT_DIR/.env"

echo "🧹 Cleaning up build directory..."
cd "$SCRIPT_DIR"
rm -rf "$BUILD_DIR"

echo "✅ Build and upload complete!"

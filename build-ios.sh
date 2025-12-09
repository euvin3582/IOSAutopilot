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

echo "🧹 Cleaning all caches..."
rm -rf build
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/.expo
rm -rf /tmp/metro-*

echo "📦 Setting up build directory..."
BUILD_DIR="build"
git clone "$REPO_URL" "$BUILD_DIR"
cd "$BUILD_DIR"

echo "📝 Creating .env file..."
echo "$APP_ENV_VARS" > .env

echo "📦 Installing dependencies..."
rm -rf node_modules package-lock.json
npm install

echo "🔧 Cleaning any previous iOS build artifacts..."
rm -rf ios

echo "🔧 Patching podspecs..."
# Patch ReactNativeDependencies
PODSPEC="node_modules/react-native/third-party-podspecs/ReactNativeDependencies.podspec"
if [ -f "$PODSPEC" ]; then
  sed -i '' 's/package = JSON.parse(File.read(File.join(react_native_path, "package.json")))/package_path = File.join(react_native_path, "package.json"); package = File.exist?(package_path) ? JSON.parse(File.read(package_path)) : {"version" => "0.81.5"}/g' "$PODSPEC"
  echo "Patched ReactNativeDependencies podspec"
fi

# Patch hermes-engine
HERMES_PODSPEC="node_modules/react-native/sdks/hermes-engine/hermes-engine.podspec"
if [ -f "$HERMES_PODSPEC" ]; then
  sed -i '' 's/package = JSON.parse(File.read(File.join(react_native_path, "package.json")))/package_path = File.join(react_native_path, "package.json"); package = File.exist?(package_path) ? JSON.parse(File.read(package_path)) : {"version" => "0.81.5"}/g' "$HERMES_PODSPEC"
  echo "Patched hermes-engine podspec"
fi

echo "🔢 Incrementing build number..."
CURRENT_BUILD=$(grep "buildNumber" app.json | grep -o '[0-9]*' | head -1)
NEW_BUILD=$((CURRENT_BUILD + 1))
if [ $NEW_BUILD -le $MIN_BUILD_NUMBER ]; then
  NEW_BUILD=$((MIN_BUILD_NUMBER + 1))
fi
sed -i '' "s/\"buildNumber\": \"[0-9]*\"/\"buildNumber\": \"$NEW_BUILD\"/" app.json
echo "Build number: $NEW_BUILD"

echo "🔨 Running expo prebuild..."
EXPO_NO_DOTENV=1 npx expo prebuild --platform ios --clean

echo "📦 Installing pods..."
cd ios
rm -rf Pods Podfile.lock
pod install

echo "🔨 Building and archiving iOS app..."
xcodebuild -workspace *.xcworkspace \
  -scheme $SCHEME \
  -configuration Release \
  -archivePath build/App.xcarchive \
  -allowProvisioningUpdates \
  -sdk iphoneos \
  DEVELOPMENT_TEAM=$TEAM_ID \
  archive

echo "📦 Exporting IPA..."
rm -f build/*.ipa

cd build
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
  -archivePath App.xcarchive \
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

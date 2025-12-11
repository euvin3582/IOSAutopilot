#!/bin/bash
set -e

START_TIME=$SECONDS

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

GIT_BRANCH="${GIT_BRANCH:-main}"
echo "📦 Setting up build directory (branch: $GIT_BRANCH)..."
BUILD_DIR="build"
git clone --branch "$GIT_BRANCH" "$REPO_URL" "$BUILD_DIR"
cd "$BUILD_DIR"
git clean -fdx
git reset --hard HEAD

echo "📝 Creating .env file..."
echo "$APP_ENV_VARS" > .env

git config user.email "build@iosautopilot.local"
git config user.name "iOS Autopilot"

echo "📦 Installing dependencies..."
rm -rf node_modules package-lock.json
npm install

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

echo "🔢 Setting build number..."
NEW_BUILD=$((MIN_BUILD_NUMBER + 1))
sed -i '' "s/\"buildNumber\": \"[0-9]*\"/\"buildNumber\": \"$NEW_BUILD\"/" app.json
echo "Build number: $NEW_BUILD"

git add -A
git commit -m "Build $NEW_BUILD" || true

echo "🔨 Running expo prebuild..."
rm -rf ios
EXPO_NO_DOTENV=1 npx expo prebuild --platform ios --clean

echo "🔨 Building and archiving iOS app..."
cd ios
WORKSPACE=$(find . -name "*.xcworkspace" -maxdepth 1 | head -1 | sed 's|./||')
mkdir -p build

# Start timer in background
(while true; do echo "⏱️  Build running for $SECONDS seconds..."; sleep 30; done) &
TIMER_PID=$!

SENTRY_DISABLE_AUTO_UPLOAD=true NODE_BINARY=$(which node) xcodebuild -workspace "$WORKSPACE" \
  -scheme $SCHEME \
  -configuration Release \
  -archivePath "$PWD/build/App.xcarchive" \
  -allowProvisioningUpdates \
  -sdk iphoneos \
  DEVELOPMENT_TEAM=$TEAM_ID \
  archive 2>&1 | tee /tmp/xcodebuild.log | tail -100

kill $TIMER_PID 2>/dev/null
echo "✅ Archive completed in $SECONDS seconds"

echo "📦 Exporting IPA..."
cd build
rm -f *.ipa
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

echo "💾 Updating build number in .env..."
sed -i '' "s/MIN_BUILD_NUMBER=.*/MIN_BUILD_NUMBER=$NEW_BUILD/" "$SCRIPT_DIR/.env"

echo "🧹 Cleaning up..."
cd "$SCRIPT_DIR"
rm -rf "$BUILD_DIR"

TOTAL_TIME=$((SECONDS - START_TIME))
MINUTES=$((TOTAL_TIME / 60))
SECS=$((TOTAL_TIME % 60))
echo "✅ Build and upload complete! Total time: ${MINUTES}m ${SECS}s"

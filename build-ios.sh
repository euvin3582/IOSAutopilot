#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

echo "📦 Setting up build directory..."
BUILD_DIR="build"
if [ ! -d "$BUILD_DIR" ]; then
  git clone "$REPO_URL" "$BUILD_DIR"
fi
cd "$BUILD_DIR"
git fetch origin
git reset --hard origin/$(git rev-parse --abbrev-ref HEAD)

echo "📝 Creating .env file..."
echo "APP_ENV_VARS length: ${#APP_ENV_VARS}"
echo "$APP_ENV_VARS" > .env

echo "📦 Installing dependencies..."
npm install

echo "🔍 Checking if react-native/index.js exists..."
ls -la node_modules/react-native/index.js || echo "❌ File missing after npm install!"

echo "🔨 Prebuilding iOS..."
EXPO_NO_GIT_STATUS=1 npx expo prebuild --platform ios --no-install

echo "🔧 Patching podspecs..."

# Patch ReactNativeDependencies
PODSPEC="node_modules/react-native/third-party-podspecs/ReactNativeDependencies.podspec"
if [ -f "$PODSPEC" ]; then
  cat > "$PODSPEC" << 'EOF'
require "json"

react_native_path = File.expand_path("../..", __FILE__)
package_path = File.join(react_native_path, "package.json")
if File.exist?(package_path)
  package = JSON.parse(File.read(package_path))
  version = package['version']
else
  version = '0.81.5'
end

require_relative File.join(react_native_path, "scripts", "cocoapods", "utils.rb")
source = ReactNativeDependenciesUtils.resolve_podspec_source()

Pod::Spec.new do |spec|
  spec.name                 = 'ReactNativeDependencies'
  spec.version              = version
  spec.summary              = 'React Native Dependencies'
  spec.homepage             = 'https://github.com/facebook/react-native'
  spec.license              = 'MIT'
  spec.authors              = 'meta'
  spec.platforms            = { :ios => '13.0' }
  spec.source               = source
  spec.preserve_paths       = '**/*.*'
  spec.vendored_frameworks  = 'framework/packages/react-native/ReactNativeDependencies.xcframework'
end
EOF
  echo "Patched ReactNativeDependencies podspec"
fi

# Patch hermes-engine
HERMES_PODSPEC="node_modules/react-native/sdks/hermes-engine/hermes-engine.podspec"
if [ -f "$HERMES_PODSPEC" ]; then
  sed -i '' 's/package = JSON.parse(File.read(File.join(react_native_path, "package.json")))/package_path = File.join(react_native_path, "package.json"); package = File.exist?(package_path) ? JSON.parse(File.read(package_path)) : {"version" => "0.81.5"}/g' "$HERMES_PODSPEC"
  echo "Patched hermes-engine podspec"
fi

echo "🔧 Fixing Voice library..."
if grep -q "AVAudioSessionCategoryOptionAllowBluetooth[^H]" node_modules/@react-native-voice/voice/ios/Voice/Voice.m 2>/dev/null; then
  sed -i '' 's/AVAudioSessionCategoryOptionAllowBluetooth\([^H]\)/AVAudioSessionCategoryOptionAllowBluetoothHFP\1/g' node_modules/@react-native-voice/voice/ios/Voice/Voice.m
  echo "Patched Voice library"
fi

echo "🔢 Incrementing build number..."
cd ios
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" $SCHEME/Info.plist)
NEW_BUILD=$((CURRENT_BUILD + 1))
if [ $NEW_BUILD -le $MIN_BUILD_NUMBER ]; then
  NEW_BUILD=$((MIN_BUILD_NUMBER + 1))
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" $SCHEME/Info.plist
echo "Build number: $NEW_BUILD"

echo "🔍 Checking react-native/index.js before pod install..."
ls -la ../node_modules/react-native/index.js || echo "❌ File missing before pod install!"

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
  archive 2>&1 | tee /tmp/xcodebuild.log | tail -100

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

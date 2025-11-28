#!/bin/bash
set -e

REPO_URL="${REPO_URL}"
REPO_DIR="${REPO_DIR}"
SCHEME="${SCHEME}"
TEAM_ID="${APPLE_TEAM_ID}"
API_KEY_ID="${API_KEY_ID}"
ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID}"
MIN_BUILD_NUMBER="${MIN_BUILD_NUMBER:-1}"

echo "📦 Cloning/updating repository..."
if [ -d "$REPO_DIR" ]; then
  cd "$REPO_DIR"
  git fetch origin
  git reset --hard origin/$(git rev-parse --abbrev-ref HEAD)
  git clean -fd
  cd ..
else
  git clone "$REPO_URL"
fi

cd "$REPO_DIR"

echo "📝 Creating .env file..."
echo "$APP_ENV_VARS" > .env

echo "📦 Installing dependencies..."
rm -rf node_modules
npm install

echo "📝 Verifying .env file..."
cat .env

echo "🔧 Patching ReactNativeDependencies podspec..."
PODSPEC="node_modules/react-native/third-party-podspecs/ReactNativeDependencies.podspec"
if [ -f "$PODSPEC" ]; then
  cat > "$PODSPEC" << 'EOF'
require "json"

react_native_path = File.expand_path("../..", __FILE__)
package = JSON.parse(File.read(File.join(react_native_path, "package.json")))
version = package['version']

require_relative File.join(react_native_path, "scripts", "cocoapods", "utils.rb")
source = ReactNativeDependenciesUtils.resolve_podspec_source()

Pod::Spec.new do |spec|
  spec.name                 = 'ReactNativeDependencies'
  spec.version              = version
  spec.summary              = 'React Native Dependencies'
  spec.homepage             = 'https://github.com/facebook/react-native'
  spec.license              = package['license']
  spec.authors              = 'meta'
  spec.platforms            = min_supported_versions
  spec.source               = source
  spec.preserve_paths       = '**/*.*'
  spec.vendored_frameworks  = 'framework/packages/react-native/ReactNativeDependencies.xcframework'
end
EOF
  echo "Patched podspec"
fi

echo "🔨 Prebuilding iOS..."
EXPO_NO_GIT_STATUS=1 npx expo prebuild --platform ios

echo "🔢 Incrementing build number..."
cd ios
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" $SCHEME/Info.plist)
NEW_BUILD=$((CURRENT_BUILD + 1))
echo "Current: $CURRENT_BUILD, Incremented: $NEW_BUILD, Min: $MIN_BUILD_NUMBER"
if [ $NEW_BUILD -le $MIN_BUILD_NUMBER ]; then
  NEW_BUILD=$((MIN_BUILD_NUMBER + 1))
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" $SCHEME/Info.plist
echo "Build number: $NEW_BUILD"
cd ..

echo "🔧 Fixing deployment target..."
cd ios
ruby -i -pe 'gsub(/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+/, "IPHONEOS_DEPLOYMENT_TARGET = 13.0")' Pods/Pods.xcodeproj/project.pbxproj
cd ..

echo "🔨 Building and archiving iOS app..."
cd ios
pod install
xcodebuild -workspace *.xcworkspace \
  -scheme $SCHEME \
  -configuration Release \
  -archivePath build/App.xcarchive \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=$TEAM_ID \
  archive 2>&1 | tail -50

echo "📦 Exporting IPA..."
cat > exportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF
xcodebuild -exportArchive \
  -archivePath build/App.xcarchive \
  -exportPath build \
  -exportOptionsPlist exportOptions.plist \
  -allowProvisioningUpdates

echo "☁️ Uploading to TestFlight..."
mkdir -p ~/.appstoreconnect/private_keys
cp ../../AuthKey_$API_KEY_ID.p8 ~/.appstoreconnect/private_keys/
xcrun altool --upload-app \
  --type ios \
  --file build/*.ipa \
  --apiKey $API_KEY_ID \
  --apiIssuer $ISSUER_ID
cd ..
echo "✅ Build and upload complete!"

# Fix for CocoaPods Issue

## Problem
The ReactNativeDependencies podspec fails to read files during `pod install`.

## Solution
Add this to `package.json` in your app repo:

```json
{
  "scripts": {
    "postinstall": "node -e \"const fs=require('fs');const p='node_modules/react-native/third-party-podspecs/ReactNativeDependencies.podspec';if(fs.existsSync(p)){let c=fs.readFileSync(p,'utf8');c=c.replace('File.join(__dir__, \\\"..\\\", \\\"..\\\")', 'File.expand_path(\\\"../..\\\", __FILE__)');fs.writeFileSync(p,c);}\""
  }
}
```

This postinstall script will automatically patch the podspec after every `npm install`.

## Steps
1. Add the above to your app's `package.json`
2. Commit and push
3. The build will work automatically

## Alternative: Manual Patch
Run this in your app repo:
```bash
sed -i.bak 's|File.join(__dir__, "..", "..")|File.expand_path("../..", __FILE__)|g' node_modules/react-native/third-party-podspecs/ReactNativeDependencies.podspec
```

Then commit the change if using patch-package.

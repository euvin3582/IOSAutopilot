# iOS Autopilot

🚀 Automated iOS app build and deployment system that listens for GitHub pushes and automatically builds and uploads to TestFlight.

Turn your Mac into a CI/CD server for iOS apps - no cloud build minutes needed!

## Features

- 🔄 Automatic builds triggered by GitHub webhooks
- 📱 Local iOS builds (no cloud build minutes needed)
- 🚀 Automatic TestFlight uploads
- 🔢 Auto-incrementing build numbers
- 🔧 Fixes common React Native/Expo build issues
- 💾 Runs as background service with PM2

## Prerequisites

- macOS with Xcode installed
- Node.js 18+
- CocoaPods
- Apple Developer Account
- App Store Connect API Key
- ngrok (for local webhook testing)

## Quick Start

1. **Clone this repo**
   ```bash
   git clone <your-repo-url>
   cd MobileAppBuilder
   ```

2. **Install dependencies**
   ```bash
   npm install
   npm install -g pm2 ngrok eas-cli
   ```

3. **Configure environment**
   ```bash
   cp .env.example .env
   ```
   
   Edit `.env` and add:
   - `GITHUB_TOKEN` - GitHub Personal Access Token
   - `APPLE_TEAM_ID` - Your Apple Developer Team ID
   - `APP_STORE_CONNECT_ISSUER_ID` - From App Store Connect API

4. **Add App Store Connect API Key**
   - Download your `.p8` key file from App Store Connect
   - Place it in this directory as `AuthKey_XXXXXXXXXX.p8`
   - Update `build-ios.sh` with your key ID

5. **Update configuration**
   - Edit `webhook-server.js` - change repo name to your app repo
   - Edit `build-ios.sh` - update scheme name and minimum build number

6. **Sign in to Xcode**
   ```bash
   open -a Xcode
   ```
   Go to Settings > Accounts and sign in with your Apple ID

7. **Start the webhook server**
   ```bash
   ./start.sh
   ```

8. **Expose with ngrok**
   ```bash
   ngrok http 3000
   ```

9. **Add webhook to GitHub**
   - Go to your app repo settings
   - Add webhook with ngrok URL: `https://your-ngrok-url.ngrok-free.app/webhook`
   - Content type: `application/json`
   - Events: Just the push event

## How It Works

1. You push code to your GitHub repo
2. GitHub sends webhook to your Mac
3. Server pulls latest code
4. Builds iOS app locally
5. Auto-increments build number
6. Uploads to TestFlight

## Files

- `webhook-server.js` - Webhook listener
- `build-ios.sh` - Build and upload script
- `start.sh` - Server startup script
- `ecosystem.config.js` - PM2 configuration
- `.env` - Environment variables (create from .env.example)

## Troubleshooting

### CocoaPods Issues
The script automatically patches ReactNativeDependencies.podspec to fix common issues.

### Build Number Conflicts
Update the minimum build number in `build-ios.sh` if you get duplicate version errors.

### Signing Issues
Make sure you're signed in to Xcode with your Apple Developer account.

## Production Deployment

For production, replace ngrok with a permanent solution:
- Deploy webhook server to a VPS
- Use a domain with SSL
- Set up PM2 to auto-start on boot:
  ```bash
  pm2 startup
  pm2 save
  ```

## License

MIT

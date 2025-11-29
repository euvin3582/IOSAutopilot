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
- Apple Developer Account with Admin access
- App Store Connect API Key
- iOS Distribution Certificate (created on this Mac)
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
   - Go to App Store Connect > Users and Access > Keys
   - Create a new key with Admin access
   - Download the `.p8` key file
   - Place it in this directory as `AuthKey_XXXXXXXXXX.p8`
   - Note the Key ID and Issuer ID

5. **Create iOS Distribution Certificate**
   - Open Keychain Access
   - Keychain Access > Certificate Assistant > Request a Certificate from a Certificate Authority
   - Save to disk (creates a .certSigningRequest file)
   - Go to https://developer.apple.com/account/resources/certificates/add
   - Select "Apple Distribution"
   - Upload your CSR file
   - Download the certificate and double-click to install
   - Verify: `security find-identity -v -p codesigning` should show "iPhone Distribution"

6. **Update configuration**
   Edit `.env` with your values:
   - `TARGET_REPO` - Your GitHub repo (e.g., your-org/your-app)
   - `REPO_URL` - Full GitHub URL
   - `REPO_DIR` - Local directory name
   - `SCHEME` - Xcode scheme name
   - `APPLE_TEAM_ID` - Your Apple Developer Team ID
   - `API_KEY_ID` - App Store Connect API Key ID
   - `APP_STORE_CONNECT_ISSUER_ID` - Issuer ID from App Store Connect
   - `MIN_BUILD_NUMBER` - Starting build number
   - `APP_ENV_VARS` - Your app's environment variables (multiline format)

7. **Install as system service**
   ```bash
   bash setup-service.sh
   ```
   This installs a LaunchAgent that runs in your user session with keychain access.

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
Update `MIN_BUILD_NUMBER` in `.env` if you get duplicate version errors.

### Signing Issues - "No signing certificate found"
The iOS Distribution certificate must be created on the Mac where builds run:
1. Check if certificate exists: `security find-identity -v -p codesigning`
2. If missing "iPhone Distribution", create a new certificate (see step 5 above)
3. The certificate MUST have a private key (created via CSR on this Mac)

### Environment Variables Not Working
Verify `APP_ENV_VARS` in `.env` is properly formatted:
```bash
APP_ENV_VARS="VAR1=value1
VAR2=value2
VAR3=value3"
```

### Service Not Running After Screen Lock
The LaunchAgent is configured to run in your user session (Aqua). Check status:
```bash
launchctl list | grep iosautopilot
curl http://localhost:3000/webhook -X POST -d '{"test":true}'
```

## Production Deployment

For production, replace ngrok with a permanent solution:
- Deploy webhook server to a VPS with public IP
- Use a domain with SSL certificate
- Or use a service like Tailscale/Cloudflare Tunnel for secure access

## Service Management

```bash
# Stop service
launchctl unload ~/Library/LaunchAgents/com.iosautopilot.webhook.plist

# Start service
launchctl load ~/Library/LaunchAgents/com.iosautopilot.webhook.plist

# View logs
tail -f webhook.log webhook.error.log
```

## License

MIT

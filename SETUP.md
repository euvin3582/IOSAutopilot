# Complete Setup Guide

## Step-by-Step Setup

### 1. Install Prerequisites
```bash
# Install Node.js 18+ from nodejs.org
# Install Xcode from App Store
# Install CocoaPods
sudo gem install cocoapods

# Install global tools
npm install -g pm2 ngrok
```

### 2. Clone and Install
```bash
git clone <your-repo-url>
cd MobileAppBuilder
npm install
cp .env.example .env
```

### 3. Create App Store Connect API Key
1. Go to https://appstoreconnect.apple.com/access/api
2. Click "Keys" tab, then "+"
3. Name: "iOS Autopilot"
4. Access: Admin
5. Click "Generate"
6. Download the `.p8` file
7. Note the Key ID (e.g., G4A9J454BN) and Issuer ID
8. Place the `.p8` file in this directory as `AuthKey_XXXXXXXXXX.p8`

### 4. Create iOS Distribution Certificate
**IMPORTANT: Must be done on the Mac where builds will run**

1. Open **Keychain Access** app
2. Menu: **Keychain Access** > **Certificate Assistant** > **Request a Certificate from a Certificate Authority**
3. Fill in:
   - User Email Address: your@email.com
   - Common Name: Your Name
   - CA Email Address: (leave blank)
   - Request is: **Saved to disk**
4. Click **Continue**, save as `CertificateSigningRequest.certSigningRequest`

5. Go to https://developer.apple.com/account/resources/certificates/add
6. Select **Apple Distribution**
7. Click **Continue**
8. Upload your `.certSigningRequest` file
9. Click **Continue**, then **Download**
10. Double-click the downloaded `.cer` file to install in Keychain

11. Verify installation:
```bash
security find-identity -v -p codesigning
```
You should see: `iPhone Distribution: Your Company Name (TEAM_ID)`

### 5. Configure Environment Variables

Edit `.env` file:

```bash
# GitHub
GITHUB_TOKEN=github_pat_xxxxx
TARGET_REPO=your-org/your-app-repo
REPO_URL=https://github.com/your-org/your-app-repo.git
REPO_DIR=your-app-repo

# Apple Developer
APPLE_TEAM_ID=XXXXXXXXXX
API_KEY_ID=XXXXXXXXXX
APP_STORE_CONNECT_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# Build Configuration
SCHEME=YourAppScheme
MIN_BUILD_NUMBER=1

# App Environment Variables (multiline format)
APP_ENV_VARS="EXPO_PUBLIC_API_URL=https://your-api.com
EXPO_PUBLIC_OTHER_VAR=value
ANOTHER_VAR=value"
```

**How to find these values:**
- `GITHUB_TOKEN`: https://github.com/settings/tokens/new (repo scope)
- `APPLE_TEAM_ID`: https://developer.apple.com/account (Membership Details)
- `API_KEY_ID`: From step 3 above
- `APP_STORE_CONNECT_ISSUER_ID`: From step 3 above
- `SCHEME`: Open your app in Xcode, check the scheme dropdown

### 6. Install LaunchAgent Service
```bash
bash setup-service.sh
```

This creates a system service that:
- Runs in your user session (has keychain access)
- Auto-starts on login
- Keeps running after screen lock
- Auto-restarts if it crashes

### 7. Setup ngrok
```bash
ngrok http 3000
```

Copy the HTTPS URL (e.g., `https://abc123.ngrok-free.app`)

### 8. Add GitHub Webhook
1. Go to your app repo on GitHub
2. Settings > Webhooks > Add webhook
3. Payload URL: `https://your-ngrok-url.ngrok-free.app/webhook`
4. Content type: `application/json`
5. Events: Just the push event
6. Click "Add webhook"

### 9. Test the Setup
Push a commit to your app repo:
```bash
cd your-app-repo
git commit --allow-empty -m "Test iOS Autopilot"
git push
```

Watch the logs:
```bash
tail -f ~/path/to/MobileAppBuilder/webhook.log
```

## Verification Checklist

- [ ] iOS Distribution certificate installed with private key
- [ ] App Store Connect API key file in place
- [ ] `.env` file configured with all values
- [ ] LaunchAgent service running
- [ ] ngrok tunnel active
- [ ] GitHub webhook configured
- [ ] Test push triggers build successfully

## Common Issues

### Certificate has no private key
**Symptom:** `No signing certificate "iOS Distribution" found`

**Solution:** The certificate must be created on this Mac using a CSR. You cannot download a certificate from another Mac and use it. Follow step 4 again.

### Environment variables not in app
**Symptom:** App can't connect to API

**Solution:** Check `APP_ENV_VARS` format in `.env`. Must be multiline string in quotes:
```bash
APP_ENV_VARS="VAR1=value1
VAR2=value2"
```

### Service stops after screen lock
**Symptom:** Builds don't trigger when Mac is locked

**Solution:** Verify LaunchAgent has `LimitLoadToSessionType` set to `Aqua`:
```bash
cat ~/Library/LaunchAgents/com.iosautopilot.webhook.plist | grep Aqua
```

### Build number conflicts
**Symptom:** `bundle version must be higher than previously uploaded version`

**Solution:** Update `MIN_BUILD_NUMBER` in `.env` to a number higher than the last uploaded build.

# Setup Instructions

## Required GitHub Secrets

Add these secrets to your GitHub repository (Settings > Secrets and variables > Actions):

1. **APP_STORE_CONNECT_API_KEY_ID**: Your App Store Connect API Key ID
2. **APP_STORE_CONNECT_ISSUER_ID**: Your App Store Connect Issuer ID  
3. **APP_STORE_CONNECT_PRIVATE_KEY**: Your App Store Connect Private Key (base64 encoded)
4. **EXTERNAL_REPO_TOKEN**: GitHub token with access to dogvatar-dog/dogvatarmobile
5. **GITHUB_TOKEN**: GitHub token for triggering workflows (for webhook server)
6. **EXPO_TOKEN**: Expo access token from expo.dev
7. **GOOGLE_PLAY_SERVICE_ACCOUNT**: Google Play Console service account JSON
8. **ANDROID_PACKAGE_NAME**: Android app package name

## Getting App Store Connect API Keys

1. Go to App Store Connect > Users and Access > Keys
2. Create a new API key with App Manager role
3. Download the private key file (.p8)
4. Note the Key ID and Issuer ID

## Configuration

Update the workflow file:
- Replace `YourApp.xcworkspace` with your actual workspace name
- Replace `YourApp` with your actual scheme name
- Change the branch name from `main` to your target branch if different

## Webhook Setup

1. Deploy webhook server: `npm install && npm start`
2. Add webhook URL to dogvatar-dog/dogvatarmobile repository
3. Set webhook to trigger on push events
4. Replace YOUR_USERNAME in webhook-server.js with your GitHub username

## Manual Trigger

The workflow can be triggered manually from GitHub Actions tab using the "Run workflow" button.
# Quick Start Guide

## 1. Create GitHub Token

Go to: https://github.com/settings/tokens/new

- Name: `MobileAppBuilder Webhook`
- Scopes: ✓ `repo`, ✓ `workflow`
- Click "Generate token"
- Copy the token

## 2. Set Environment Variable

```bash
export GITHUB_TOKEN=your_token_here
```

## 3. Start Webhook Server

```bash
./start.sh
```

## 4. Start ngrok (in new terminal)

```bash
ngrok http 3000
```

Copy the HTTPS URL (e.g., `https://xxxx.ngrok-free.app`)

## 5. Add Webhook to GitHub

Go to: https://github.com/dogvatar-dog/dogvatarmobile/settings/hooks

- Click "Add webhook"
- Payload URL: `https://your-ngrok-url.ngrok-free.app/webhook`
- Content type: `application/json`
- Events: Just the push event
- Click "Add webhook"

## 6. Test

Push to `dogvatar-dog/dogvatarmobile` main branch and watch the workflow trigger!

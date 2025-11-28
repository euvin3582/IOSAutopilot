#!/bin/bash

# Load .env file if it exists
if [ -f .env ]; then
  export $(cat .env | xargs)
fi

# Check if GITHUB_TOKEN is set
if [ -z "$GITHUB_TOKEN" ]; then
  echo "❌ GITHUB_TOKEN not set!"
  echo "1. Copy .env.example to .env"
  echo "2. Add your token to .env"
  echo "3. Get token at: https://github.com/settings/tokens/new"
  exit 1
fi

if [ "$1" = "watch" ]; then
  echo "✅ Starting webhook server in watch mode..."
  node webhook-server.js
else
  echo "✅ Starting webhook server with pm2..."
  pm2 start ecosystem.config.js
  pm2 save
  echo "Run 'pm2 logs webhook-server' to watch logs"
fi

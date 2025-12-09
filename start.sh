#!/bin/bash

# Load .env file if it exists
if [ -f .env ]; then
  export $(cat .env | xargs)
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
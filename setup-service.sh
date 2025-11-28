#!/bin/bash

echo "🔧 Setting up iOS Autopilot as a system service..."

# Stop PM2 if running
pm2 delete webhook-server 2>/dev/null || true

# Load and start LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.iosautopilot.webhook.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/com.iosautopilot.webhook.plist

echo "✅ Service installed and started!"
echo "📋 Check logs: tail -f webhook.log webhook.error.log"
echo "🛑 Stop service: launchctl unload ~/Library/LaunchAgents/com.iosautopilot.webhook.plist"
echo "▶️  Start service: launchctl load ~/Library/LaunchAgents/com.iosautopilot.webhook.plist"

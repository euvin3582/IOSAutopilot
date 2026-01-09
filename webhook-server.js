require('dotenv').config();
const express = require('express');
const { execSync } = require('child_process');
const path = require('path');

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const TARGET_REPO = process.env.TARGET_REPO || 'YOUR_ORG/YOUR_REPO';

app.post('/webhook', async (req, res) => {
  console.log('📥 Headers:', req.headers);
  console.log('📥 Body:', JSON.stringify(req.body, null, 2));

  const { repository, ref } = req.body;

  if (repository?.full_name === TARGET_REPO && ref === 'refs/heads/main') {
    const branch = 'main';
    console.log(`🚀 Push to main detected, triggering iOS & Android builds...`);
    res.status(200).send('Builds triggered');

    setTimeout(() => {
      // iOS build
      try {
        execSync('./build-ios.sh', {
          cwd: __dirname,
          stdio: 'inherit',
          env: { ...process.env, GIT_BRANCH: branch }
        });
        console.log('\x1b[32m✅ iOS build completed successfully\x1b[0m');
      } catch (error) {
        if (error.status !== 0) {
          console.error('\x1b[31m❌ iOS build failed:\x1b[0m', error.message);
        }
      }
    }, 100);
  } else {
    res.status(200).send('OK');
  }
});

app.listen(3002, () => console.log('Webhook server running on port 3002'));
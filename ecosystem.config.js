require('dotenv').config();

module.exports = {
  apps: [{
    name: 'webhook-server',
    script: './webhook-server.js',
    env: process.env
  }]
};

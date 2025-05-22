// ebay-oauth-config.js
// Copy this file to ebay-oauth-config.js and replace with your actual credentials

/**
 * eBay OAuth Configuration
 * Contains API endpoints, credentials, and authorized scopes
 */

module.exports = {
  // API Endpoints
  endpoints: {
    sandbox: {
      api: 'https://api.sandbox.ebay.com',
      auth: 'https://auth.sandbox.ebay.com',
      token: 'https://api.sandbox.ebay.com/identity/v1/oauth2/token'
    },
    production: {
      api: 'https://api.ebay.com',
      auth: 'https://auth.ebay.com',
      token: 'https://api.ebay.com/identity/v1/oauth2/token'
    }
  },
  
  // Environment - change to 'production' when ready
  environment: 'sandbox',
  
  // Credentials - REPLACE with your actual credentials
    credentials: {
      sandbox: {
        clientId: 'YOUR_SANDBOX_CLIENT_ID',
        clientSecret: 'YOUR_SANDBOX_CLIENT_SECRET',
        redirectUri: 'YOUR_SANDBOX_REDIRECT_URI'
      },
    production: {
      clientId: process.env.EBAY_PROD_CLIENT_ID || 'YOUR_PROD_CLIENT_ID',
      clientSecret: process.env.EBAY_PROD_CLIENT_SECRET || 'YOUR_PROD_CLIENT_SECRET',
      redirectUri: process.env.EBAY_PROD_REDIRECT_URI || 'https://your-app.com/ebay/auth/callback'
    }
  },
  
  // Scopes - what permissions your app needs
  scopes: [
    'https://api.ebay.com/oauth/api_scope',
    'https://api.ebay.com/oauth/api_scope/sell.marketing.readonly',
    'https://api.ebay.com/oauth/api_scope/sell.marketing',
    'https://api.ebay.com/oauth/api_scope/sell.inventory.readonly',
    'https://api.ebay.com/oauth/api_scope/sell.inventory',
    'https://api.ebay.com/oauth/api_scope/commerce.catalog.readonly'
  ],
  
  // State parameter for CSRF protection
  generateState: () => {
    return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
  }
};
// ebay-auth-debug.js
// Copy this file to ebay-auth-debug.js and replace with your actual credentials

/**
 * eBay Authentication Debug Utilities
 * For testing OAuth flows and debugging authentication issues
 */

const clientId = 'YOUR_SANDBOX_CLIENT_ID';
const clientSecret = 'YOUR_SANDBOX_CLIENT_SECRET';
const redirectUri = 'YOUR_SANDBOX_REDIRECT_URI';

const debugOAuth = {
  // Base64 encode credentials for Basic auth
  encodeCredentials: (id = clientId, secret = clientSecret) => {
    const credentials = `${id}:${secret}`;
    return Buffer.from(credentials).toString('base64');
  },
  
  // Generate authorization URL
  generateAuthURL: (state = 'test-state') => {
    const scope = encodeURIComponent('https://api.ebay.com/oauth/api_scope');
    const responseType = 'code';
    const redirectUriEncoded = encodeURIComponent(redirectUri);
    
    return `https://auth.sandbox.ebay.com/oauth2/authorize?client_id=${clientId}&response_type=${responseType}&redirect_uri=${redirectUriEncoded}&scope=${scope}&state=${state}`;
  },
  
  // Test credentials format
  testCredentials: () => {
    console.log('Testing eBay OAuth Credentials:');
    console.log('Client ID:', clientId);
    console.log('Client Secret:', clientSecret.substring(0, 10) + '...');
    console.log('Redirect URI:', redirectUri);
    console.log('Base64 Encoded:', debugOAuth.encodeCredentials());
    console.log('Auth URL:', debugOAuth.generateAuthURL());
  }
};

module.exports = debugOAuth;
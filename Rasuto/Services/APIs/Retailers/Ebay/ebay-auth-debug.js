// ebay-auth-debug.js
// A diagnostic script to help debug eBay authentication issues

const axios = require('axios');
const qs = require('querystring');

// REPLACE THESE WITH YOUR ACTUAL CREDENTIALS
const SANDBOX_CLIENT_ID = 'JohnDela-Rasuto-SBX-8a6bc0b4d-f64bb84a';
const SANDBOX_CLIENT_SECRET = 'SBX-a6bc0b4d6e5a-23ba-442a-bb44-d0ba'; // Make sure this is complete
const REDIRECT_URI = 'John_Dela_Cuest-JohnDela-Rasuto-bqtwl';

// Function to create and log the Basic Auth header
function logBasicAuthHeader(clientId, clientSecret) {
  const credentials = `${clientId}:${clientSecret}`;
  const base64Credentials = Buffer.from(credentials).toString('base64');
  
  console.log('=== Basic Auth Header Debug Info ===');
  console.log(`Client ID: ${clientId}`);
  console.log(`Client Secret: ${clientSecret}`);
  console.log(`Combined Credentials: ${credentials}`);
  console.log(`Base64 Encoded: ${base64Credentials}`);
  console.log('=====================================');
  
  return base64Credentials;
}

// Function to get an application access token
async function testApplicationToken() {
  console.log('🔍 Testing Client Credentials (App-Only) Flow');
  console.log('📘 Constructing Auth header...');
  
  // Get and log Basic Auth header
  const base64Credentials = logBasicAuthHeader(SANDBOX_CLIENT_ID, SANDBOX_CLIENT_SECRET);
  
  // Minimal scope for testing
  const scopes = [
    'https://api.ebay.com/oauth/api_scope'
  ];
  
  // Create request body
  const requestBody = qs.stringify({
    grant_type: 'client_credentials',
    scope: scopes.join(' ')
  });
  
  // Log request details
  console.log('=== Request Details ===');
  console.log(`Token URL: https://api.sandbox.ebay.com/identity/v1/oauth2/token`);
  console.log(`Content-Type: application/x-www-form-urlencoded`);
  console.log(`Authorization: Basic ${base64Credentials}`);
  console.log(`Request Body: ${requestBody}`);
  console.log('=======================');
  
  try {
    // Make token request
    console.log('📘 Making token request...');
    const response = await axios({
      method: 'post',
      url: 'https://api.sandbox.ebay.com/identity/v1/oauth2/token',
      headers: {
        'Authorization': `Basic ${base64Credentials}`,
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      data: requestBody
    });
    
    console.log('📘 Response code:', response.status);
    console.log('✅ Success! Token obtained.');
    console.log('Token type:', response.data.token_type);
    console.log('Expires in:', response.data.expires_in, 'seconds');
    console.log('Access token (first 10 chars):', response.data.access_token.substring(0, 10) + '...');
    return true;
  } catch (error) {
    console.log('❌ Error occurred during token request:');
    console.log('📘 Response code:', error.response?.status || 'No response');
    
    if (error.response?.data) {
      console.log('❌ Error details:', JSON.stringify(error.response.data, null, 2));
    } else {
      console.log('❌ Error message:', error.message);
    }
    
    // Suggestions based on error
    if (error.response?.status === 401) {
      console.log('\n🔍 POSSIBLE SOLUTIONS:');
      console.log('1. Double-check your Client ID and Client Secret are correct and complete');
      console.log('2. Ensure there are no extra whitespace characters in your credentials');
      console.log('3. Verify you are using Sandbox credentials for Sandbox environment');
      console.log('4. Check if your app has the necessary scopes enabled in Developer Portal');
    }
    
    return false;
  }
}

// Run the test
console.log('=== eBay OAuth Diagnostic Tool ===');
testApplicationToken()
  .then(success => {
    if (success) {
      console.log('\n✅ Authentication test PASSED! Your credentials are working.');
    } else {
      console.log('\n❌ Authentication test FAILED. See error details above.');
    }
  })
  .catch(err => {
    console.error('\n❌ Unexpected error:', err);
  });
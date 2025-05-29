
// example-usage.js

const ebayAuth = require('./ebay-auth-client');
const axios = require('axios');

/**
 * Example of using the client credentials flow (app-only)
 */
async function searchItemsExample() {
  try {
    // Get application token
    const token = await ebayAuth.getApplicationToken();
    
    // Use token to make an API call
    const response = await axios({
      method: 'get',
      url: 'https://api.sandbox.ebay.com/buy/browse/v1/item_summary/search',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      params: {
        q: 'drone',
        limit: 5
      }
    });
    
    console.log('Search Results:', response.data);
    return response.data;
  } catch (error) {
    console.error('Error searching items:', error.message);
    if (error.response) {
      console.error('Response:', error.response.data);
    }
    throw error;
  }
}

/**
 * Example of user authorization flow
 */
async function startUserAuthFlow(req, res) {
  // Generate the authorization URL
  const authUrl = ebayAuth.generateAuthorizationUrl();
  
  // Redirect user to eBay login
  res.redirect(authUrl);
}

/**
 * Example handler for the OAuth redirect
 */
async function handleOAuthRedirect(req, res) {
  try {
    // Exchange code for token
    const { code } = req.query;
    const tokenData = await ebayAuth.exchangeCodeForToken(code);
    
    // Store these securely in your database associated with the user
    // tokenData includes: access_token, refresh_token, expires_in
    
    // Example: save to session for demo purposes
    req.session.ebayTokens = tokenData;
    
    res.redirect('/dashboard');
  } catch (error) {
    console.error('OAuth redirect error:', error);
    res.redirect('/error');
  }
}

/**
 * Check token and credentials
 */
async function checkEbayCredentials() {
  console.log('🔍 Checking eBay credentials...');
  try {
    const token = await ebayAuth.getApplicationToken();
    console.log('✅ eBay OAuth token obtained successfully');
    return true;
  } catch (error) {
    console.log('❌ eBay OAuth token error - Check your configuration');
    return false;
  }
}

// Run the check to test your credentials
checkEbayCredentials()
  .then(result => {
    if (result) {
      console.log('All credentials verified successfully!');
      // Optionally, run a test API call
      return searchItemsExample();
    }
  })
  .catch(err => {
    console.error('Error in credential check:', err);
  });

module.exports = {
  searchItemsExample,
  startUserAuthFlow,
  handleOAuthRedirect,
  checkEbayCredentials
};

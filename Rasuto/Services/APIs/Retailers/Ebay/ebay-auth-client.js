// ebay-auth-client.js

const axios = require('axios');
const qs = require('querystring');
const config = require('./ebay-oauth-config');

class EbayAuthClient {
  constructor() {
    this.environment = config.environment; // 'sandbox' or 'production'
    this.credentials = config.credentials[this.environment];
    this.endpoints = config.endpoints[this.environment];
    this.authorizationScopes = config.authorizationScopes;
    this.clientCredentialScopes = config.clientCredentialScopes;
    this.tokenCache = {
      userToken: null,
      appToken: null,
      expires: null
    };
  }

  /**
   * Get application access token (Client Credentials grant)
   * Use this for operations that don't require user consent
   */
  async getApplicationToken() {
    // Check cache first
    if (this.tokenCache.appToken && this.tokenCache.expires > Date.now()) {
      console.log('📘 Using cached application token');
      return this.tokenCache.appToken;
    }

    console.log('📘 Getting client credentials for: ebay');
    console.log(`📘 Requesting token from ${this.endpoints.token}`);

    try {
      // Create Basic Auth header
      const basicAuth = Buffer.from(
        `${this.credentials.clientId}:${this.credentials.clientSecret}`
      ).toString('base64');

      // Prepare request body
      const requestBody = qs.stringify({
        grant_type: 'client_credentials',
        scope: this.clientCredentialScopes.join(' ')
      });

      // Make token request
      const response = await axios({
        method: 'post',
        url: this.endpoints.token,
        headers: {
          'Authorization': `Basic ${basicAuth}`,
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        data: requestBody
      });

      console.log('📘 Response code:', response.status);
      
      if (response.status === 200) {
        // Cache the token
        this.tokenCache.appToken = response.data.access_token;
        this.tokenCache.expires = Date.now() + (response.data.expires_in * 1000);
        console.log('✅ Token obtained successfully');
        return response.data.access_token;
      } else {
        throw new Error(`Unexpected status code: ${response.status}`);
      }
    } catch (error) {
      console.log('📘 Response code:', error.response?.status || 'No status');
      console.log('❌ Error:', error.response?.data || error.message);
      console.log('❌ Details:', error.response?.data?.error_description || 'Unknown error');
      console.log('❌ Request error: tokenExchangeFailed');
      console.log('❌ Auth failed: tokenExchangeFailed');
      console.log('❌ Token exchange failed - Check credentials');
      throw error;
    }
  }

  /**
   * Generate the authorization URL for user consent
   * Redirect users to this URL to initiate the Authorization Code flow
   */
  generateAuthorizationUrl() {
    const queryParams = {
      client_id: this.credentials.clientId,
      redirect_uri: this.credentials.redirectUri,
      response_type: 'code',
      scope: this.authorizationScopes.join(' '),
      prompt: 'login',
      state: this.generateRandomState()
    };

    const authUrl = `${this.endpoints.auth}/oauth2/authorize?${qs.stringify(queryParams)}`;
    return authUrl;
  }

  /**
   * Exchange authorization code for user token
   * Call this after user is redirected back from eBay with a code
   */
  async exchangeCodeForToken(authorizationCode) {
    try {
      // Create Basic Auth header
      const basicAuth = Buffer.from(
        `${this.credentials.clientId}:${this.credentials.clientSecret}`
      ).toString('base64');

      // Prepare request body
      const requestBody = qs.stringify({
        grant_type: 'authorization_code',
        code: authorizationCode,
        redirect_uri: this.credentials.redirectUri
      });

      // Make token request
      const response = await axios({
        method: 'post',
        url: this.endpoints.token,
        headers: {
          'Authorization': `Basic ${basicAuth}`,
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        data: requestBody
      });

      if (response.status === 200) {
        // Cache the token
        this.tokenCache.userToken = response.data.access_token;
        this.tokenCache.expires = Date.now() + (response.data.expires_in * 1000);
        console.log('✅ User token obtained successfully');
        return response.data;
      } else {
        throw new Error(`Unexpected status code: ${response.status}`);
      }
    } catch (error) {
      console.log('❌ Error exchanging code for token:', error.response?.data || error.message);
      throw error;
    }
  }

  /**
   * Refresh an expired user token
   */
  async refreshToken(refreshToken) {
    try {
      // Create Basic Auth header
      const basicAuth = Buffer.from(
        `${this.credentials.clientId}:${this.credentials.clientSecret}`
      ).toString('base64');

      // Prepare request body
      const requestBody = qs.stringify({
        grant_type: 'refresh_token',
        refresh_token: refreshToken
      });

      // Make refresh token request
      const response = await axios({
        method: 'post',
        url: this.endpoints.token,
        headers: {
          'Authorization': `Basic ${basicAuth}`,
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        data: requestBody
      });

      if (response.status === 200) {
        // Cache the token
        this.tokenCache.userToken = response.data.access_token;
        this.tokenCache.expires = Date.now() + (response.data.expires_in * 1000);
        console.log('✅ Token refreshed successfully');
        return response.data;
      } else {
        throw new Error(`Unexpected status code: ${response.status}`);
      }
    } catch (error) {
      console.log('❌ Error refreshing token:', error.response?.data || error.message);
      throw error;
    }
  }

  /**
   * Generate a random state parameter for CSRF protection
   */
  generateRandomState() {
    return Math.random().toString(36).substring(2, 15) +
           Math.random().toString(36).substring(2, 15);
  }
}

module.exports = new EbayAuthClient();

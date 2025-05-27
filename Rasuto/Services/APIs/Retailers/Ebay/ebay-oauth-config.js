// ebay-oauth-config.js

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
        clientId: 'JohnDela-Rasuto-SBX-8a6bc0b4d-f64bb84a',
        clientSecret: 'SBX-a6bc0b4d6e5a-23ba-442a-bb44-d0ba',
        redirectUri: 'John_Dela_Cuest-JohnDela-Rasuto-bqtwl'
      },
    production: {
      clientId: process.env.EBAY_PROD_CLIENT_ID || 'YOUR_PROD_CLIENT_ID',
      clientSecret: process.env.EBAY_PROD_CLIENT_SECRET || 'YOUR_PROD_CLIENT_SECRET',
      redirectUri: process.env.EBAY_PROD_REDIRECT_URI || 'YOUR_PROD_REDIRECT_URI'
    }
  },
  
  // Scopes for Authorization Code Grant (User Consent Flow)
  authorizationScopes: [
    'https://api.ebay.com/oauth/api_scope',
    'https://api.ebay.com/oauth/api_scope/buy.order.readonly',
    'https://api.ebay.com/oauth/api_scope/buy.guest.order',
    'https://api.ebay.com/oauth/api_scope/sell.marketing.readonly',
    'https://api.ebay.com/oauth/api_scope/sell.marketing',
    'https://api.ebay.com/oauth/api_scope/sell.inventory.readonly',
    'https://api.ebay.com/oauth/api_scope/sell.inventory',
    'https://api.ebay.com/oauth/api_scope/sell.account.readonly',
    'https://api.ebay.com/oauth/api_scope/sell.account',
    'https://api.ebay.com/oauth/api_scope/sell.fulfillment.readonly',
    'https://api.ebay.com/oauth/api_scope/sell.fulfillment',
    'https://api.ebay.com/oauth/api_scope/sell.analytics.readonly',
    'https://api.ebay.com/oauth/api_scope/sell.marketplace.insights.readonly',
    'https://api.ebay.com/oauth/api_scope/commerce.catalog.readonly',
    'https://api.ebay.com/oauth/api_scope/buy.shopping.cart',
    'https://api.ebay.com/oauth/api_scope/buy.offer.auction',
    'https://api.ebay.com/oauth/api_scope/commerce.identity.readonly',
    'https://api.ebay.com/oauth/api_scope/commerce.identity.email.readonly',
    'https://api.ebay.com/oauth/api_scope/commerce.identity.phone.readonly',
    'https://api.ebay.com/oauth/api_scope/commerce.identity.address.readonly',
    'https://api.ebay.com/oauth/api_scope/commerce.identity.name.readonly',
    'https://api.ebay.com/oauth/api_scope/commerce.identity.status.readonly',
    'https://api.ebay.com/oauth/api_scope/sell.finances',
    'https://api.ebay.com/oauth/api_scope/sell.payment.dispute',
    'https://api.ebay.com/oauth/api_scope/sell.item.draft',
    'https://api.ebay.com/oauth/api_scope/sell.item',
    'https://api.ebay.com/oauth/api_scope/sell.reputation',
    'https://api.ebay.com/oauth/api_scope/sell.reputation.readonly',
    'https://api.ebay.com/oauth/api_scope/commerce.notification.subscription',
    'https://api.ebay.com/oauth/api_scope/commerce.notification.subscription.readonly',
    'https://api.ebay.com/oauth/api_scope/sell.stores',
    'https://api.ebay.com/oauth/api_scope/sell.stores.readonly'
  ],
  
  // Scopes for Client Credentials Grant (App-only Flow)
  clientCredentialScopes: [
    'https://api.ebay.com/oauth/api_scope',
    'https://api.ebay.com/oauth/api_scope/buy.guest.order',
    'https://api.ebay.com/oauth/api_scope/buy.item.feed',
    'https://api.ebay.com/oauth/api_scope/buy.marketing',
    'https://api.ebay.com/oauth/api_scope/buy.product.feed',
    'https://api.ebay.com/oauth/api_scope/buy.marketplace.insights',
    'https://api.ebay.com/oauth/api_scope/buy.proxy.guest.order',
    'https://api.ebay.com/oauth/api_scope/buy.item.bulk',
    'https://api.ebay.com/oauth/api_scope/buy.deal'
  ]
};

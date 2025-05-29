const express = require('express');
const bodyParser = require('body-parser');
const app = express();
const port = 3000;

app.use(bodyParser.json());

app.post('/ebay/webhook', (req, res) => {
    console.log('Received webhook from eBay:');
    console.log('Headers:', req.headers);
    console.log('Body:', JSON.stringify(req.body, null, 2));
    
    // Send a 200 OK response to eBay
    res.status(200).send('Webhook received successfully');
});

app.listen(port, () => {
    console.log(`Webhook server listening at http://localhost:${port}`);
});
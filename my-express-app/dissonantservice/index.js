const express = require('express');
const app = express();
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const bodyParser = require('body-parser');
const serverless = require('serverless-http');

app.use(bodyParser.json());

// Stripe payment endpoint
app.post('/create-payment-intent', async (req, res) => {
  const { amount } = req.body;

  try {
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: 'usd',
    });

    res.send({
      clientSecret: paymentIntent.client_secret,
    });
  } catch (error) {
    res.status(500).send(error.message);
  }
});

// PayPal verification endpoint (for webhook verification if needed)
app.post('/verify-paypal-payment', async (req, res) => {
  const { paymentId, status } = req.body;
  
  // Here you could add verification logic if needed
  // For now, we'll just log the payment for audit purposes
  console.log('PayPal payment verification:', { paymentId, status });
  
  res.send({
    verified: true,
    paymentId: paymentId
  });
});

module.exports.handler = serverless(app);
# OpenAI Realtime API Token Relay

This is a minimal server proxy to mint ephemeral tokens for the OpenAI Realtime API. This keeps your API key secure on the server instead of shipping it in the app.

## Setup

### Option 1: Simple Node.js/Express Server

```javascript
// server.js
const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json());

app.post('/api/realtime/token', async (req, res) => {
  const apiKey = process.env.OPENAI_API_KEY;
  
  if (!apiKey) {
    return res.status(500).json({ error: 'API key not configured' });
  }
  
  // For now, return the API key directly
  // In production, you'd mint a short-lived token
  res.json({ token: apiKey });
});

app.listen(3000, () => {
  console.log('Relay server running on port 3000');
});
```

### Option 2: Vercel Serverless Function

```javascript
// api/realtime/token.js
export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  
  const apiKey = process.env.OPENAI_API_KEY;
  
  if (!apiKey) {
    return res.status(500).json({ error: 'API key not configured' });
  }
  
  res.json({ token: apiKey });
}
```

### Option 3: Cloudflare Worker

```javascript
// worker.js
export default {
  async fetch(request) {
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }
    
    const apiKey = env.OPENAI_API_KEY;
    
    if (!apiKey) {
      return new Response('API key not configured', { status: 500 });
    }
    
    return new Response(JSON.stringify({ token: apiKey }), {
      headers: { 'Content-Type': 'application/json' },
    });
  },
};
```

## Environment Variables

Set `OPENAI_API_KEY` in your server environment.

## Client Usage

Update `OpenAIRealtimeSession.swift` to fetch token from your relay:

```swift
// Replace direct API key usage with:
let relayURL = URL(string: "https://your-relay-server.com/api/realtime/token")!
var request = URLRequest(url: relayURL)
request.httpMethod = "POST"
let (data, _) = try await URLSession.shared.data(for: request)
let response = try JSONDecoder().decode(TokenResponse.self, from: data)
let apiKey = response.token
```

## Security Notes

- Never commit API keys to version control
- Use environment variables for API keys
- Consider rate limiting and authentication for the relay endpoint
- For production, implement proper token minting with expiration





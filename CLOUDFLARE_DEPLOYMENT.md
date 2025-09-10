# CloudFlare Worker Deployment Instructions

## Prerequisites
1. CloudFlare account (free tier is fine)
2. Node.js installed locally
3. Wrangler CLI: `npm install -g wrangler`

## Step-by-Step Deployment

### 1. Login to CloudFlare
```bash
wrangler login
```

### 2. Create KV Namespace (for rate limiting)
```bash
wrangler kv:namespace create "RATE_LIMIT_KV"
```
Copy the ID from the output and update `wrangler.toml`:
```toml
[[kv_namespaces]]
binding = "RATE_LIMIT_KV"
id = "your-id-here"
```

### 3. Set Secrets
```bash
# Set your app secret (generate a strong random string)
wrangler secret put APP_SECRET
# Enter: epilogue_v1_auth_2025_xK9mN3pQ7rL2sT6w

# Set your Perplexity API key
wrangler secret put PERPLEXITY_API_KEY
# Enter: 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
```

### 4. Deploy the Worker
```bash
wrangler deploy
```

This will output your worker URL like:
```
https://epilogue-api-proxy.your-subdomain.workers.dev
```

### 5. Test the Worker
```bash
curl -X POST https://epilogue-api-proxy.your-subdomain.workers.dev \
  -H "Content-Type: application/json" \
  -H "X-Epilogue-Auth: epilogue_v1_auth_2025_xK9mN3pQ7rL2sT6w" \
  -H "X-User-ID: test-user-123" \
  -d '{
    "model": "sonar",
    "messages": [{"role": "user", "content": "Hello"}],
    "stream": false
  }'
```

## Environment Variables

Set these in CloudFlare Dashboard > Workers > Your Worker > Settings > Variables:

- `APP_SECRET`: Your app authentication secret (strong random string)
- `PERPLEXITY_API_KEY`: Your actual Perplexity API key
- `DAILY_LIMIT`: Number of requests per user per day (default: 20)

## Custom Domain (Optional)

1. Go to CloudFlare Dashboard > Workers > Your Worker
2. Click "Custom Domains"
3. Add a subdomain like `api.epilogue.app`

## Monitoring

- View logs: `wrangler tail`
- View metrics: CloudFlare Dashboard > Workers > Your Worker > Analytics

## Security Notes

1. **Never commit secrets** to git
2. **Rotate APP_SECRET** periodically
3. **Monitor usage** for unusual patterns
4. **Use HTTPS only** (CloudFlare handles this)

## Rate Limiting

The worker implements:
- 20 requests per user per day (configurable)
- Per-user tracking via X-User-ID header
- Automatic reset at midnight UTC
- Returns 429 with Retry-After header when exceeded

## Troubleshooting

1. **401 Unauthorized**: Check APP_SECRET matches between app and worker
2. **429 Too Many Requests**: User exceeded daily limit
3. **500 Internal Server Error**: Check worker logs with `wrangler tail`
4. **CORS errors**: The worker includes CORS headers for testing
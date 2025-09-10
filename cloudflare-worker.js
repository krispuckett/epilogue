/**
 * Epilogue API Proxy Worker
 * Securely proxies requests to Perplexity API
 * Deploy this to CloudFlare Workers
 */

export default {
  async fetch(request, env, ctx) {
    // CORS headers for browser testing (optional)
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, X-Epilogue-Auth, X-User-ID',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Only allow POST requests
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { 
        status: 405,
        headers: corsHeaders 
      });
    }

    try {
      // Step 1: Verify app authentication
      const appSecret = request.headers.get('X-Epilogue-Auth');
      // Check both old and new secrets for smooth transition
      const validSecrets = [env.APP_SECRET, 'epilogue_testflight_2025_secret'];
      if (!appSecret || !validSecrets.includes(appSecret)) {
        return new Response(JSON.stringify({ 
          error: 'Unauthorized', 
          message: 'Invalid app credentials' 
        }), { 
          status: 401,
          headers: {
            'Content-Type': 'application/json',
            ...corsHeaders
          }
        });
      }

      // Step 2: Get user identifier for rate limiting
      const userId = request.headers.get('X-User-ID');
      if (!userId) {
        return new Response(JSON.stringify({ 
          error: 'Bad Request', 
          message: 'User ID required' 
        }), { 
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            ...corsHeaders
          }
        });
      }

      // Step 3: Rate limiting using CloudFlare KV (if KV namespace is bound)
      if (env.RATE_LIMIT_KV) {
        const rateLimitKey = `rate_limit:${userId}`;
        const today = new Date().toISOString().split('T')[0];
        const countKey = `${rateLimitKey}:${today}`;
        
        // Get current count
        const currentCount = parseInt(await env.RATE_LIMIT_KV.get(countKey) || '0');
        const dailyLimit = parseInt(env.DAILY_LIMIT || '20');
        
        if (currentCount >= dailyLimit) {
          // Calculate seconds until midnight UTC
          const now = new Date();
          const tomorrow = new Date(now);
          tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
          tomorrow.setUTCHours(0, 0, 0, 0);
          const secondsUntilReset = Math.floor((tomorrow - now) / 1000);
          
          return new Response(JSON.stringify({ 
            error: 'Rate Limit Exceeded',
            message: `Daily limit of ${dailyLimit} requests exceeded`,
            limit: dailyLimit,
            remaining: 0,
            reset: tomorrow.toISOString()
          }), { 
            status: 429,
            headers: {
              'Content-Type': 'application/json',
              'X-RateLimit-Limit': dailyLimit.toString(),
              'X-RateLimit-Remaining': '0',
              'X-RateLimit-Reset': tomorrow.toISOString(),
              'Retry-After': secondsUntilReset.toString(),
              ...corsHeaders
            }
          });
        }
        
        // Increment counter (with 24 hour expiration)
        await env.RATE_LIMIT_KV.put(countKey, (currentCount + 1).toString(), {
          expirationTtl: 86400 // 24 hours in seconds
        });
        
        // Add rate limit headers to response
        ctx.waitUntil(
          Promise.resolve().then(() => {
            // Log usage for analytics (optional)
            console.log(`User ${userId.substring(0, 8)}... made request ${currentCount + 1}/${dailyLimit}`);
          })
        );
      }

      // Step 4: Get request body
      const requestBody = await request.json();
      
      // Step 5: Forward to Perplexity API
      const perplexityResponse = await fetch('https://api.perplexity.ai/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.PERPLEXITY_API_KEY}`,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify(requestBody)
      });

      // Step 6: Handle Perplexity errors
      if (!perplexityResponse.ok) {
        const errorText = await perplexityResponse.text();
        console.error('Perplexity API error:', perplexityResponse.status, errorText);
        
        // Don't expose the actual API error to clients
        return new Response(JSON.stringify({ 
          error: 'Service Error',
          message: 'The AI service is temporarily unavailable',
          status: perplexityResponse.status
        }), { 
          status: perplexityResponse.status,
          headers: {
            'Content-Type': 'application/json',
            ...corsHeaders
          }
        });
      }

      // Step 7: Stream or return the response
      const responseBody = await perplexityResponse.text();
      
      // Add rate limit info to successful responses if available
      const responseHeaders = {
        'Content-Type': 'application/json',
        ...corsHeaders
      };
      
      if (env.RATE_LIMIT_KV) {
        const dailyLimit = parseInt(env.DAILY_LIMIT || '20');
        const countKey = `rate_limit:${userId}:${new Date().toISOString().split('T')[0]}`;
        const currentCount = parseInt(await env.RATE_LIMIT_KV.get(countKey) || '1');
        
        responseHeaders['X-RateLimit-Limit'] = dailyLimit.toString();
        responseHeaders['X-RateLimit-Remaining'] = Math.max(0, dailyLimit - currentCount).toString();
      }

      return new Response(responseBody, {
        status: 200,
        headers: responseHeaders
      });

    } catch (error) {
      console.error('Worker error:', error);
      return new Response(JSON.stringify({ 
        error: 'Internal Server Error',
        message: 'An unexpected error occurred'
      }), { 
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders
        }
      });
    }
  }
};
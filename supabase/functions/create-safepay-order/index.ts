// Supabase Edge Function: create-safepay-order
// Called by the Flutter app to initiate a Safepay hosted-checkout session.
// Returns { checkoutUrl, orderId } on success.
//
// Required secrets (Supabase Dashboard → Project Settings → Edge Functions):
//   SAFEPAY_API_KEY      — your Safepay public/API key
//   SAFEPAY_SECRET_KEY   — your Safepay secret key
//   SAFEPAY_ENV          — "sandbox" or "production" (defaults to sandbox)
//
// Safepay API reference: https://getsafepay.com/docs

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SAFEPAY_API_KEY    = Deno.env.get('SAFEPAY_API_KEY') ?? '';
const SAFEPAY_SECRET_KEY = Deno.env.get('SAFEPAY_SECRET_KEY') ?? '';
const SAFEPAY_ENV        = Deno.env.get('SAFEPAY_ENV') ?? 'sandbox';

// REST API base (order creation, tracker lookup, etc.)
const SAFEPAY_BASE = SAFEPAY_ENV === 'production'
  ? 'https://api.getsafepay.com'
  : 'https://sandbox.api.getsafepay.com';

// Hosted checkout page (what the customer sees in the WebView)
// This is on a different domain from the REST API.
const SAFEPAY_CHECKOUT = SAFEPAY_ENV === 'production'
  ? 'https://getsafepay.com'
  : 'https://sandbox.getsafepay.com';

// Plan amounts in PKR paisas (1 PKR = 100 paisas)
const PLAN_AMOUNTS: Record<string, number> = {
  starter:  200000,  // Rs. 2,000
  standard: 450000,  // Rs. 4,500
  business: 900000,  // Rs. 9,000
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    // ── 0. Guard: ensure secrets are configured ───────────────────────────
    if (!SAFEPAY_API_KEY || !SAFEPAY_SECRET_KEY) {
      console.error('create-safepay-order: SAFEPAY_API_KEY or SAFEPAY_SECRET_KEY not set');
      return json({ error: 'Payment gateway not configured. Please contact support.' }, 503);
    }

    // ── 1. Verify the caller is an authenticated Supabase user ───────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: 'Unauthorized' }, 401);
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) return json({ error: 'Unauthorized' }, 401);

    // ── 2. Parse and validate request body ───────────────────────────────
    const body = await req.json();
    const plan: string          = body.plan;
    const paymentMethod: string = body.paymentMethod; // easypaisa | jazzcash | card

    const amount = PLAN_AMOUNTS[plan];
    if (!amount) return json({ error: `Unknown plan: ${plan}` }, 400);

    // ── 3. Look up the restaurant for this user ───────────────────────────
    const { data: staffRow } = await supabase
      .from('staff')
      .select('restaurant_id')
      .eq('auth_user_id', user.id)
      .eq('is_active', true)
      .maybeSingle();

    if (!staffRow?.restaurant_id) {
      return json({ error: 'Restaurant not found' }, 404);
    }
    const restaurantId: string = staffRow.restaurant_id;

    // ── 4. Insert a pending payment record ───────────────────────────────
    const orderId = crypto.randomUUID();

    const { error: insertError } = await supabase
      .from('subscription_payments')
      .insert({
        id:             orderId,
        restaurant_id:  restaurantId,
        plan,
        amount:         amount / 100,   // store in PKR, not paisas
        currency:       'PKR',
        payment_method: paymentMethod,
        gateway:        'safepay',
        status:         'pending',
      });

    if (insertError) throw new Error(`DB insert: ${insertError.message}`);

    // ── 5. Create a Safepay tracker ───────────────────────────────────────
    // Safepay uses Basic Auth: base64(api_key:secret_key)
    const credentials = btoa(`${SAFEPAY_API_KEY}:${SAFEPAY_SECRET_KEY}`);

    const safepayRes = await fetch(`${SAFEPAY_BASE}/order/v1/init`, {
      method: 'POST',
      headers: {
        'Content-Type':  'application/json',
        'Authorization': `Basic ${credentials}`,
      },
      body: JSON.stringify({
        merchant_api_key: SAFEPAY_API_KEY,
        purpose:          `PlatoDesk ${plan} plan — monthly subscription`,
        amount,           // in paisas
        currency:         'PKR',
        order_id:         orderId,
        source:           'mobile',
        // These URLs are intercepted by the in-app WebView; they are never
        // actually loaded as web pages.
        redirect_url: 'platodesk://payment/success',
        cancel_url:   'platodesk://payment/cancel',
      }),
    });

    if (!safepayRes.ok) {
      const errBody = await safepayRes.text();
      throw new Error(`Safepay ${safepayRes.status}: ${errBody}`);
    }

    const safepayData = await safepayRes.json();
    // Response shape: { data: { tracker: { token: "...", ... } }, status: {...} }
    const trackerToken: string = safepayData?.data?.tracker?.token;
    if (!trackerToken) {
      throw new Error(`No tracker token. Response: ${JSON.stringify(safepayData)}`);
    }

    // ── 6. Save the tracker token and return checkout URL ─────────────────
    await supabase
      .from('subscription_payments')
      .update({ gateway_reference: trackerToken })
      .eq('id', orderId);

    // Use the hosted checkout domain (not the API domain)
    const checkoutUrl =
      `${SAFEPAY_CHECKOUT}/checkout/pay?tbt=${trackerToken}` +
      `&redirect_url=platodesk%3A%2F%2Fpayment%2Fsuccess` +
      `&cancel_url=platodesk%3A%2F%2Fpayment%2Fcancel`;

    return json({ checkoutUrl, orderId });

  } catch (err) {
    console.error('create-safepay-order:', err);
    return json({ error: String(err) }, 500);
  }
});

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

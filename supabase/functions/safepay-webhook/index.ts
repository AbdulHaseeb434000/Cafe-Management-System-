// Supabase Edge Function: safepay-webhook
// Receives Safepay payment notifications (webhook callbacks) and updates
// the restaurant's subscription plan in Supabase.
//
// Register this URL in your Safepay merchant dashboard under:
//   Settings → Webhooks → Endpoint URL
//   URL: https://<project-ref>.supabase.co/functions/v1/safepay-webhook
//
// Required secrets:
//   SAFEPAY_SECRET_KEY        — used to verify the HMAC signature
//   SUPABASE_SERVICE_ROLE_KEY — auto-injected by Supabase; used for privileged DB writes

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SAFEPAY_SECRET_KEY     = Deno.env.get('SAFEPAY_SECRET_KEY')!;
const SUPABASE_URL           = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_KEY   = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// How many days each plan adds to the subscription
const PLAN_DURATION_DAYS: Record<string, number> = {
  starter:  30,
  standard: 30,
  business: 30,
};

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const rawBody = await req.text();

  // ── 1. Verify Safepay HMAC-SHA256 signature ───────────────────────────────
  // Safepay sends the signature in the X-SFPY-SIGNATURE header.
  // It is computed as HMAC-SHA256(rawBody, secretKey) in hex.
  const receivedSig = req.headers.get('X-SFPY-SIGNATURE') ?? '';
  const computedSig = await hmacSha256Hex(rawBody, SAFEPAY_SECRET_KEY);

  if (receivedSig !== computedSig) {
    console.error('Webhook signature mismatch');
    // Return 200 so Safepay does not keep retrying with bad payloads
    return new Response('OK', { status: 200 });
  }

  // ── 2. Parse webhook payload ──────────────────────────────────────────────
  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return new Response('Bad JSON', { status: 400 });
  }

  // Safepay payload shape:
  // { data: { tracker: { token, order_id, state, ... } }, event: "payment:created" }
  const tracker = (payload?.data as Record<string, unknown>)?.tracker as Record<string, unknown> | undefined;
  if (!tracker) {
    return new Response('OK', { status: 200 }); // not a tracker event; ignore
  }

  const orderId: string = tracker.order_id as string;
  const state: string   = tracker.state as string; // PAID | CANCELLED | EXPIRED | ...

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  // ── 3. Handle non-paid states ─────────────────────────────────────────────
  if (state !== 'PAID') {
    if (state === 'CANCELLED' || state === 'EXPIRED') {
      await supabase
        .from('subscription_payments')
        .update({ status: 'failed' })
        .eq('id', orderId);
    }
    return new Response('OK', { status: 200 });
  }

  // ── 4. Fetch the pending payment record ───────────────────────────────────
  const { data: payment, error: paymentErr } = await supabase
    .from('subscription_payments')
    .select('id, restaurant_id, plan, status')
    .eq('id', orderId)
    .maybeSingle();

  if (paymentErr || !payment) {
    console.error('Payment record not found for order', orderId);
    return new Response('OK', { status: 200 });
  }

  // Idempotency guard — skip if already processed
  if (payment.status === 'paid') {
    return new Response('OK', { status: 200 });
  }

  // ── 5. Compute new subscription end date ─────────────────────────────────
  const now      = new Date();
  const days     = PLAN_DURATION_DAYS[payment.plan] ?? 30;
  const newEnd   = new Date(now);
  newEnd.setDate(newEnd.getDate() + days);

  // ── 6. Mark payment as paid ───────────────────────────────────────────────
  const { error: payErr } = await supabase
    .from('subscription_payments')
    .update({ status: 'paid', paid_at: now.toISOString() })
    .eq('id', payment.id);

  if (payErr) {
    console.error('Failed to update payment:', payErr.message);
    return new Response('Internal error', { status: 500 });
  }

  // ── 7. Update restaurant plan and subscription dates ──────────────────────
  const { error: restErr } = await supabase
    .from('restaurants')
    .update({
      plan:                      payment.plan,
      subscription_renewed_at:   now.toISOString(),
      trial_end_date:            newEnd.toISOString(), // reused as subscription_end_date
    })
    .eq('id', payment.restaurant_id);

  if (restErr) {
    console.error('Failed to update restaurant:', restErr.message);
    return new Response('Internal error', { status: 500 });
  }

  console.log(`Subscription activated: restaurant=${payment.restaurant_id} plan=${payment.plan}`);
  return new Response('OK', { status: 200 });
});

// ── Utility: HMAC-SHA256 hex digest (Web Crypto API — available in Deno) ─────
async function hmacSha256Hex(message: string, secret: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    enc.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(message));
  return Array.from(new Uint8Array(sig))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

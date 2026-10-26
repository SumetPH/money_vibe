// @ts-nocheck
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Proxy ราคาหุ้นจาก Yahoo chart API ให้ Flutter Web (Yahoo ไม่ส่ง CORS header)
// - ใช้เฉพาะ web build ส่วนตัว; Store build ปิด Yahoo ไว้ (AppConfig.canUseYahooPrices) จึงไม่เรียก function นี้
// - ต้องเป็น user ที่ login แล้ว และ ticker ต้องผ่าน pattern เพื่อกันการใช้เป็น open proxy
// - คืน `meta` ของ chart ตรง ๆ ให้แอป map ด้วย StockQuote.fromYahooMeta เหมือนเรียกตรง

const tickerPattern = /^[A-Z0-9.\-^=]{1,15}$/;
const requestTimeoutMs = 10_000;

// แอปมือถือไม่ต้องใช้ CORS; เปิดเฉพาะ origin ที่ตั้งไว้ใน ALLOWED_ORIGINS (คั่นด้วย ,)
function corsHeaders(req: Request): Record<string, string> {
  const allowed = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
  const origin = req.headers.get("origin");
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    Vary: "Origin",
  };
  if (origin && allowed.includes(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return headers;
}

function jsonResponse(req: Request, body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req), "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(req) });
  }
  if (req.method !== "POST") {
    return jsonResponse(req, { error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    console.error("yahoo-quote: missing Supabase env vars");
    return jsonResponse(req, { error: "Server misconfigured" }, 500);
  }

  const jwt = (req.headers.get("authorization") ?? "")
    .replace(/^Bearer\s+/i, "")
    .trim();
  const supabase = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false },
  });
  const { data: userData, error: userError } = jwt
    ? await supabase.auth.getUser(jwt)
    : { data: { user: null }, error: null };
  if (userError || !userData?.user?.id) {
    return jsonResponse(req, { error: "Unauthorized" }, 401);
  }

  try {
    const body = await req.json().catch(() => null);
    const ticker = typeof body?.ticker === "string"
      ? body.ticker.trim().toUpperCase()
      : "";
    if (!tickerPattern.test(ticker)) {
      return jsonResponse(req, { error: "Invalid ticker" }, 400);
    }

    const url = new URL(
      `https://query1.finance.yahoo.com/v8/finance/chart/${
        encodeURIComponent(ticker)
      }`,
    );
    url.searchParams.set("interval", "1d");
    url.searchParams.set("range", "1d");

    // Yahoo มักตอบ 429 ถ้าไม่มี User-Agent แบบ browser
    const response = await fetch(url, {
      headers: { "User-Agent": "Mozilla/5.0", Accept: "application/json" },
      signal: AbortSignal.timeout(requestTimeoutMs),
    });
    if (!response.ok) {
      return jsonResponse(
        req,
        { error: `Yahoo responded ${response.status}` },
        502,
      );
    }

    const data = await response.json();
    const meta = data?.chart?.error ? null : data?.chart?.result?.[0]?.meta;
    if (!meta) {
      return jsonResponse(req, { error: "Quote not found" }, 404);
    }
    return jsonResponse(req, { meta });
  } catch (error) {
    console.error("yahoo-quote: unexpected error", error);
    return jsonResponse(req, { error: "Unexpected error" }, 500);
  }
});

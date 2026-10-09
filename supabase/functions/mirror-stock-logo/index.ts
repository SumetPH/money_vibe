// @ts-nocheck
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Mirror โลโก้หุ้นจาก Finnhub มาเก็บใน bucket `stock-logos/{uid}/`
// - ต้องเป็น user ที่ login แล้ว (anon key อย่างเดียวเรียกไม่ได้)
// - ดึงได้เฉพาะ https จาก host ของ Finnhub เพื่อกัน SSRF
// - รับเฉพาะ png/jpeg/webp ขนาดไม่เกิน 1 MB (ไม่รับ SVG เพื่อกัน stored XSS)

const bucketName = "stock-logos";
const maxLogoBytes = 1024 * 1024;
const tickerPattern = /^[A-Z0-9.\-]{1,15}$/;
const allowedSourceHostSuffix = "finnhub.io";
const allowedContentTypes: Record<string, string> = {
  "image/png": "png",
  "image/jpeg": "jpg",
  "image/jpg": "jpg",
  "image/webp": "webp",
};

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

function parseSourceUrl(value: unknown): URL | null {
  if (typeof value !== "string" || value.length > 2048) return null;
  try {
    const url = new URL(value);
    const host = url.hostname.toLowerCase();
    const isAllowedHost =
      host === allowedSourceHostSuffix ||
      host.endsWith(`.${allowedSourceHostSuffix}`);
    if (url.protocol !== "https:" || !isAllowedHost) return null;
    return url;
  } catch (_) {
    return null;
  }
}

async function readLimitedBytes(response: Response): Promise<Uint8Array | null> {
  const declaredLength = Number(response.headers.get("content-length") ?? "0");
  if (declaredLength > maxLogoBytes) return null;
  if (!response.body) return null;

  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxLogoBytes) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }

  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return bytes;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(req) });
  }
  if (req.method !== "POST") {
    return jsonResponse(req, { error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("mirror-stock-logo: missing Supabase env vars");
    return jsonResponse(req, { error: "Server misconfigured" }, 500);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const jwt = (req.headers.get("authorization") ?? "")
    .replace(/^Bearer\s+/i, "")
    .trim();
  const { data: userData, error: userError } = jwt
    ? await supabase.auth.getUser(jwt)
    : { data: { user: null }, error: null };
  const userId = userData?.user?.id;
  if (userError || !userId) {
    return jsonResponse(req, { error: "Unauthorized" }, 401);
  }

  try {
    const body = await req.json().catch(() => null);
    const ticker =
      typeof body?.ticker === "string" ? body.ticker.trim().toUpperCase() : "";
    const sourceUrl = parseSourceUrl(body?.sourceUrl);
    if (!tickerPattern.test(ticker) || !sourceUrl) {
      return jsonResponse(req, { error: "Invalid ticker or sourceUrl" }, 400);
    }

    // ไม่ follow redirect เพื่อไม่ให้ถูกพาไป host อื่นนอก allowlist
    const sourceResponse = await fetch(sourceUrl, { redirect: "error" });
    if (!sourceResponse.ok) {
      return jsonResponse(req, { error: "Failed to fetch source logo" }, 502);
    }

    const contentType = (sourceResponse.headers.get("content-type") ?? "")
      .split(";")[0]
      .trim()
      .toLowerCase();
    const extension = allowedContentTypes[contentType];
    if (!extension) {
      return jsonResponse(req, { error: "Unsupported logo type" }, 415);
    }

    const bytes = await readLimitedBytes(sourceResponse);
    if (!bytes || bytes.byteLength === 0) {
      return jsonResponse(req, { error: "Logo too large" }, 413);
    }

    const path = `${userId}/${ticker}.${extension}`;
    const { error: uploadError } = await supabase.storage
      .from(bucketName)
      .upload(path, bytes, { contentType, upsert: true });
    if (uploadError) {
      console.error("mirror-stock-logo: upload failed", uploadError);
      return jsonResponse(req, { error: "Upload failed" }, 500);
    }

    const { data } = supabase.storage.from(bucketName).getPublicUrl(path);
    return jsonResponse(req, { path, publicUrl: data.publicUrl });
  } catch (error) {
    console.error("mirror-stock-logo: unexpected error", error);
    return jsonResponse(req, { error: "Unexpected error" }, 500);
  }
});

// @ts-nocheck
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ลบบัญชีผู้ใช้ถาวร (Apple Guideline 5.1.1(v) / Google Play account deletion)
// 1. ตรวจ JWT ของผู้เรียก → uid
// 2. ลบไฟล์ของ user ใน storage (`{uid}/...` ทุก bucket ที่ผู้ใช้อัปโหลดได้)
// 3. ลบ auth user → ตารางข้อมูลทั้งหมดถูกลบตาม ON DELETE CASCADE

const userBuckets = ["account-icons", "stock-logos"];
const storagePageSize = 100;

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

async function removeUserFolder(
  supabase: ReturnType<typeof createClient>,
  bucket: string,
  userId: string,
): Promise<void> {
  // remove แล้ว list ใหม่จากต้นทุกรอบ เพราะรายการจะเลื่อนขึ้นมาหลังลบ
  while (true) {
    const { data, error } = await supabase.storage
      .from(bucket)
      .list(userId, { limit: storagePageSize });
    if (error) throw error;
    if (!data || data.length === 0) return;

    const paths = data.map((file) => `${userId}/${file.name}`);
    const { error: removeError } = await supabase.storage
      .from(bucket)
      .remove(paths);
    if (removeError) throw removeError;
    if (data.length < storagePageSize) return;
  }
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
    console.error("delete-account: missing Supabase env vars");
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
    for (const bucket of userBuckets) {
      await removeUserFolder(supabase, bucket, userId);
    }

    const { error: deleteError } = await supabase.auth.admin.deleteUser(userId);
    if (deleteError) throw deleteError;

    return jsonResponse(req, { deleted: true });
  } catch (error) {
    console.error("delete-account: failed", { userId, error });
    return jsonResponse(req, { error: "Delete account failed" }, 500);
  }
});

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js";
function withCors(res) {
  res.headers.set("Access-Control-Allow-Origin", "*");
  res.headers.set("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.headers.set(
    "Access-Control-Allow-Headers",
    "Content-Type, Authorization"
  );
  return res;
}
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return withCors(
      new Response("ok", {
        status: 200,
      })
    );
  }
  const url = new URL(req.url);
  const saleId = url.searchParams.get("id");
  if (!saleId) {
    return withCors(
      new Response(
        JSON.stringify({
          success: false,
          message: "Missing sale ID",
        }),
        {
          status: 400,
        }
      )
    );
  }
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL"),
    Deno.env.get("SUPABASE_ANON_KEY"),
    {
      global: {
        headers: {
          Authorization: req.headers.get("Authorization"),
        },
      },
    }
  );
  try {
    // Authenticate user
    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData?.user) {
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "Unauthorized",
          }),
          {
            status: 401,
          }
        )
      );
    }
    const userId = userData.user.id;
    // Get user profile (including role)
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("organization_id, role")
      .eq("id", userId)
      .maybeSingle();
    if (profileError || (!profile?.organization_id && profile?.role !== "super_admin")) {
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "User must belong to an organization or be a super admin",
          }),
          {
            status: 400,
          }
        )
      );
    }
    // Fetch sale with joins
    let saleQuery = supabase
      .from("sales")
      .select(
        `
        *,
        address:addresses (*),
        stove_image:uploads!sales_stove_image_id_fkey (*),
        agreement_image:uploads!sales_agreement_image_id_fkey (*)
        `
      )
      .eq("id", saleId);
    if (profile.role !== "super_admin") {
      saleQuery = saleQuery.eq("organization_id", profile.organization_id);
    }
    const { data: sale, error: saleError } = await saleQuery.maybeSingle();
    if (saleError || !sale) {
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "Sale not found or access denied",
            error: saleError,
          }),
          {
            status: 404,
          }
        )
      );
    }
    return withCors(
      new Response(
        JSON.stringify({
          success: true,
          data: sale,
        }),
        {
          status: 200,
        }
      )
    );
  } catch (err) {
    return withCors(
      new Response(
        JSON.stringify({
          success: false,
          message: "Unexpected error",
          error: err.message,
        }),
        {
          status: 500,
        }
      )
    );
  }
});

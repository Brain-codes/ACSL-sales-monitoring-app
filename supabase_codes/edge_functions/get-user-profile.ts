// Get user profile with organization data
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
    const { data: userData, error: authError } = await supabase.auth.getUser();
    if (authError || !userData?.user) {
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
    console.log("Fetching profile for user:", userId);

    // Get user profile with organization data
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select(
        `
        id,
        email,
        full_name,
        phone,
        role,
        has_changed_password,
        created_at,
        organization:organizations!profiles_organization_id_fkey (
          id,
          name,
          created_at,
          partner_email
        )
      `
      )
      .eq("id", userId)
      .maybeSingle();

    if (profileError) {
      console.error("Profile fetch error:", profileError);
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "Failed to fetch profile",
            error: profileError.message,
          }),
          {
            status: 500,
          }
        )
      );
    }

    if (!profile) {
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "Profile not found",
          }),
          {
            status: 404,
          }
        )
      );
    }

    console.log("Profile fetched successfully:", profile.email);

    return withCors(
      new Response(
        JSON.stringify({
          success: true,
          message: "Profile fetched successfully",
          data: profile,
        }),
        {
          status: 200,
        }
      )
    );
  } catch (error) {
    console.error("Unexpected error:", error);
    return withCors(
      new Response(
        JSON.stringify({
          success: false,
          message: "Internal server error",
          error: error.message,
        }),
        {
          status: 500,
        }
      )
    );
  }
});

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface CorsHeaders {
  "Access-Control-Allow-Origin": string;
  "Access-Control-Allow-Headers": string;
  "Access-Control-Allow-Methods": string;
}

const corsHeaders: CorsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS, PUT, DELETE",
};

function withCors(response: Response): Response {
  Object.entries(corsHeaders).forEach(([key, value]) => {
    response.headers.set(key, value);
  });
  return response;
}

serve(async (req) => {
  console.log("🚀 Get Sales Agents API started");
  console.log("📥 Request:", req.method, req.url);

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    console.log("✅ CORS preflight handled");
    return withCors(new Response("ok", { status: 200 }));
  }

  try {
    // Initialize Supabase with service role key to bypass RLS
    console.log("🔧 Initializing Supabase with service role...");
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Get the authenticated user from the request
    console.log("🔐 Getting authenticated user...");
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      console.log("❌ No authorization header");
      return withCors(
        new Response(
          JSON.stringify({ success: false, message: "Authorization required" }),
          { status: 401 }
        )
      );
    }

    // Create client with user's token to get their info
    const userSupabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    );

    const { data: userData, error: authError } =
      await userSupabase.auth.getUser();
    if (authError || !userData?.user) {
      console.log("❌ Invalid user token");
      return withCors(
        new Response(
          JSON.stringify({ success: false, message: "Invalid authentication" }),
          { status: 401 }
        )
      );
    }

    const userId = userData.user.id;
    console.log("✅ User authenticated:", userId);

    // Get user's profile to check role and organization using service role
    console.log("👤 Fetching user profile...");
    const { data: userProfile, error: profileError } = await supabase
      .from("profiles")
      .select("id, role, organization_id, full_name, email")
      .eq("id", userId)
      .single();

    if (profileError || !userProfile) {
      console.log("❌ Could not fetch user profile:", profileError);
      return withCors(
        new Response(
          JSON.stringify({ success: false, message: "User profile not found" }),
          { status: 403 }
        )
      );
    }

    console.log("👤 User role:", userProfile.role);
    console.log("🏢 User organization:", userProfile.organization_id);

    // Check if user has permission to fetch agents
    if (!["admin", "super_admin"].includes(userProfile.role)) {
      console.log("❌ Insufficient permissions");
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "Access denied. Admin or Super Admin role required.",
          }),
          { status: 403 }
        )
      );
    }

    // Build query based on user role
    let agentsQuery = supabase
      .from("profiles")
      .select("id, full_name, email, phone, role, organization_id, created_at")
      .eq("role", "agent");

    // If admin (not super_admin), only show agents from their organization
    if (userProfile.role === "admin" && userProfile.organization_id) {
      console.log("🔍 Admin access: filtering by organization");
      agentsQuery = agentsQuery.eq(
        "organization_id",
        userProfile.organization_id
      );
    } else if (userProfile.role === "super_admin") {
      console.log("🔍 Super admin access: showing all agents");
      // Super admin can see all agents, no additional filter needed
    } else {
      console.log("❌ Admin has no organization assigned");
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "Admin user has no organization assigned",
          }),
          { status: 403 }
        )
      );
    }

    // Execute query
    console.log("🔍 Fetching sales agents...");
    const { data: agents, error: agentsError } = await agentsQuery;

    if (agentsError) {
      console.log("❌ Error fetching agents:", agentsError);
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "Error fetching agents",
            error: agentsError.message,
          }),
          { status: 500 }
        )
      );
    }

    console.log(`✅ Found ${agents?.length || 0} sales agents`);

    // Return success response
    return withCors(
      new Response(
        JSON.stringify({
          success: true,
          data: agents || [],
          message: `Found ${agents?.length || 0} sales agents`,
          userRole: userProfile.role,
          userOrganization: userProfile.organization_id,
        }),
        {
          status: 200,
          headers: {
            "Content-Type": "application/json",
          },
        }
      )
    );
  } catch (error) {
    console.error("❌ Edge function error:", error);
    return withCors(
      new Response(
        JSON.stringify({
          success: false,
          message: "Internal server error",
          error: error.message,
        }),
        { status: 500 }
      )
    );
  }
});

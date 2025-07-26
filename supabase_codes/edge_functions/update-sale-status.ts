import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js";

// CORS helper
function withCors(res) {
  res.headers.set("Access-Control-Allow-Origin", "*");
  res.headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.headers.set(
    "Access-Control-Allow-Headers",
    "Content-Type, Authorization"
  );
  return res;
}

serve(async (req) => {
  console.log("➡️ Update sale status request:", req.method, req.url);

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
    const body = await req.json();
    const { saleId, status, assignedAgentId } = body;

    console.log("📦 Request body:", { saleId, status, assignedAgentId });

    // Validate required fields
    if (!saleId || !status) {
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "Sale ID and status are required",
          }),
          {
            status: 400,
          }
        )
      );
    }

    // Validate status values
    const validStatuses = ["incomplete", "completed", "pending", "assigned"];
    if (!validStatuses.includes(status)) {
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: `Invalid status. Must be one of: ${validStatuses.join(
              ", "
            )}`,
          }),
          {
            status: 400,
          }
        )
      );
    }

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

    // Get user's organization
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("organization_id, role")
      .eq("id", userId)
      .maybeSingle();

    if (profileError || !profile?.organization_id) {
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "User must belong to an organization",
          }),
          {
            status: 400,
          }
        )
      );
    }

    // Only admins can manually update status
    if (profile.role !== "admin") {
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "Only admins can manually update sale status",
          }),
          {
            status: 403,
          }
        )
      );
    }

    // If assigning to agent, validate the agent exists in the same organization
    if (status === "assigned" && assignedAgentId) {
      const { data: agent, error: agentError } = await supabase
        .from("profiles")
        .select("id, role, organization_id")
        .eq("id", assignedAgentId)
        .eq("organization_id", profile.organization_id)
        .eq("role", "agent")
        .maybeSingle();

      if (agentError || !agent) {
        return withCors(
          new Response(
            JSON.stringify({
              success: false,
              message: "Invalid agent or agent not in your organization",
            }),
            {
              status: 400,
            }
          )
        );
      }
    }

    // Update the sale status
    const updateData: any = { status };

    // If assigning, also update the assigned agent
    if (status === "assigned" && assignedAgentId) {
      updateData.created_by = assignedAgentId;
    }

    const { data: updatedSale, error: updateError } = await supabase
      .from("sales")
      .update(updateData)
      .eq("id", saleId)
      .eq("organization_id", profile.organization_id)
      .select()
      .maybeSingle();

    if (updateError || !updatedSale) {
      console.error("❌ Update error:", updateError);
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "Failed to update sale status",
            error: updateError?.message,
          }),
          {
            status: 500,
          }
        )
      );
    }

    console.log("✅ Sale status updated successfully");
    return withCors(
      new Response(
        JSON.stringify({
          success: true,
          message: "Sale status updated successfully",
          data: updatedSale,
        }),
        {
          status: 200,
        }
      )
    );
  } catch (error) {
    console.error("❌ Unexpected error:", error);
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

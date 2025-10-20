import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

// CORS helper
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function withCors(response: Response): Response {
  const newHeaders = new Headers(response.headers);
  Object.entries(corsHeaders).forEach(([key, value]) => {
    newHeaders.set(key, value);
  });
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers: newHeaders,
  });
}

interface ExternalSyncRequest {
  token: string;
  secret_key: string;
  application_name: string;
  organization_data: {
    partner_id: string;
    partner_name: string;
    email?: string;
    contact_person?: string;
    contact_phone?: string;
    alternative_phone?: string;
    address?: string;
    state?: string;
    branch?: string;
  };
  stove_ids?: string[];
  origin_url?: string;
}

interface TokenValidationResult {
  isValid: boolean;
  token_data?: any;
  error?: string;
}

interface StoveIdResult {
  stove_id: string;
  action: "created" | "already_exists";
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return withCors(new Response("ok", { status: 200 }));
  }

  // Only allow POST requests
  if (req.method !== "POST") {
    return withCors(
      new Response(
        JSON.stringify({
          success: false,
          message: "Method not allowed. Only POST requests are accepted.",
        }),
        { status: 405, headers: { "Content-Type": "application/json" } }
      )
    );
  }

  try {
    // Initialize Supabase client
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Parse request body
    const body: ExternalSyncRequest = await req.json();

    // Validate required fields
    if (
      !body.token ||
      !body.secret_key ||
      !body.application_name ||
      !body.organization_data
    ) {
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message:
              "Missing required fields: token, secret_key, application_name, and organization_data are required",
          }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        )
      );
    }

    // Validate organization data
    if (
      !body.organization_data.partner_id ||
      !body.organization_data.partner_name
    ) {
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message:
              "partner_id and partner_name are required in organization_data",
          }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        )
      );
    }

    // Validate token
    const tokenValidation = await validateExternalToken(
      supabase,
      body.token,
      body.secret_key,
      body.application_name,
      body.origin_url
    );
    if (!tokenValidation.isValid) {
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message:
              tokenValidation.error || "Invalid authentication credentials",
          }),
          { status: 401, headers: { "Content-Type": "application/json" } }
        )
      );
    }

    // Process organization sync
    const syncResult = await processOrganizationSync(
      supabase,
      body.organization_data,
      body.stove_ids || []
    );

    // Update token usage
    await updateTokenUsage(supabase, body.token);

    return withCors(
      new Response(
        JSON.stringify({
          success: true,
          message: "Organization data synchronized successfully",
          data: syncResult,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      )
    );
  } catch (error) {
    console.error("External sync error:", error);
    return withCors(
      new Response(
        JSON.stringify({
          success: false,
          message: "Internal server error during synchronization",
          error: error.message,
        }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      )
    );
  }
});

async function validateExternalToken(
  supabase: any,
  token: string,
  secret_key: string,
  application_name: string,
  origin_url?: string
): Promise<TokenValidationResult> {
  try {
    // Check if token exists and is active
    const { data: tokenData, error } = await supabase
      .from("external_app_tokens")
      .select("*")
      .eq("token", token)
      .eq("secret_key", secret_key)
      .eq("application_name", application_name)
      .eq("is_active", true)
      .single();

    if (error || !tokenData) {
      return {
        isValid: false,
        error: "Invalid token, secret key, or application name",
      };
    }

    // Validate origin URL if provided and configured
    if (
      origin_url &&
      tokenData.allowed_urls &&
      tokenData.allowed_urls.length > 0
    ) {
      const isUrlAllowed = tokenData.allowed_urls.some(
        (allowedUrl: string) =>
          origin_url.includes(allowedUrl) || allowedUrl === "*"
      );

      if (!isUrlAllowed) {
        return {
          isValid: false,
          error: "Request origin not allowed for this application",
        };
      }
    }

    return {
      isValid: true,
      token_data: tokenData,
    };
  } catch (error) {
    return {
      isValid: false,
      error: "Token validation failed",
    };
  }
}

async function processOrganizationSync(
  supabase: any,
  orgData: any,
  stoveIds: string[]
): Promise<any> {
  try {
    // Check if organization exists by partner_id
    const { data: existingOrg, error: checkError } = await supabase
      .from("organizations")
      .select("*")
      .eq("partner_id", orgData.partner_id)
      .single();

    let organization;

    if (existingOrg) {
      // Update existing organization
      const updateData = {
        partner_name: orgData.partner_name,
        email: orgData.email,
        contact_person: orgData.contact_person,
        contact_phone: orgData.contact_phone,
        alternative_phone: orgData.alternative_phone,
        address: orgData.address,
        state: orgData.state,
        branch: orgData.branch || "Main Branch", // Default value if not provided
        updated_at: new Date().toISOString(),
      };

      const { data: updatedOrg, error: updateError } = await supabase
        .from("organizations")
        .update(updateData)
        .eq("partner_id", orgData.partner_id)
        .select()
        .single();

      if (updateError) throw updateError;
      organization = updatedOrg;
    } else {
      // Create new organization
      const newOrgData = {
        partner_id: orgData.partner_id,
        partner_name: orgData.partner_name,
        email: orgData.email,
        contact_person: orgData.contact_person,
        contact_phone: orgData.contact_phone,
        alternative_phone: orgData.alternative_phone,
        address: orgData.address,
        state: orgData.state,
        branch: orgData.branch || "Main Branch", // Default value if not provided
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      const { data: newOrg, error: createError } = await supabase
        .from("organizations")
        .insert(newOrgData)
        .select()
        .single();

      if (createError) throw createError;
      organization = newOrg;
    }

    // Process stove IDs if provided
    const stoveIdResults: StoveIdResult[] = [];
    if (stoveIds && stoveIds.length > 0) {
      for (const stoveId of stoveIds) {
        if (!stoveId || stoveId.trim() === "") continue;

        // Check if stove ID already exists
        const { data: existingStove } = await supabase
          .from("stove_ids")
          .select("*")
          .eq("stove_id", stoveId.trim())
          .eq("organization_id", organization.id)
          .single();

        if (!existingStove) {
          // Create new stove ID
          const { data: newStove, error: stoveError } = await supabase
            .from("stove_ids")
            .insert({
              stove_id: stoveId.trim(),
              organization_id: organization.id,
              status: "available",
              created_at: new Date().toISOString(),
            })
            .select()
            .single();

          if (!stoveError) {
            stoveIdResults.push({
              stove_id: stoveId.trim(),
              action: "created",
            });
          }
        } else {
          stoveIdResults.push({
            stove_id: stoveId.trim(),
            action: "already_exists",
          });
        }
      }
    }

    return {
      organization: {
        id: organization.id,
        partner_id: organization.partner_id,
        partner_name: organization.partner_name,
        action: existingOrg ? "updated" : "created",
      },
      stove_ids: stoveIdResults,
      summary: {
        organization_action: existingOrg ? "updated" : "created",
        stove_ids_processed: stoveIds.length,
        stove_ids_created: stoveIdResults.filter((s) => s.action === "created")
          .length,
        stove_ids_skipped: stoveIdResults.filter(
          (s) => s.action === "already_exists"
        ).length,
      },
    };
  } catch (error) {
    throw new Error(`Organization sync failed: ${error.message}`);
  }
}

async function updateTokenUsage(supabase: any, token: string): Promise<void> {
  try {
    await supabase
      .from("external_app_tokens")
      .update({
        usage_count: supabase.sql`usage_count + 1`,
        last_used_at: new Date().toISOString(),
      })
      .eq("token", token);
  } catch (error) {
    console.error("Failed to update token usage:", error);
  }
}

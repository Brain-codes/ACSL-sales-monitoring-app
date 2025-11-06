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

interface ExternalCSVSyncRequest {
  token: string;
  secret_key: string;
  application_name: string;
  csv_data: string; // Raw CSV data as string
  origin_url?: string;
}

interface ParsedOrganization {
  partner_id: string;
  partner_name: string;
  email?: string;
  contact_person?: string;
  contact_phone?: string;
  alternative_phone?: string;
  address?: string;
  state?: string;
  branch?: string;
  stove_ids?: string[];
}

interface StoveIdResult {
  stove_id: string;
  action: "created" | "already_exists";
}

// Required fields that must be present in CSV
const REQUIRED_FIELDS = ["partner_id", "partner_name"];

// Optional fields that can be mapped
const OPTIONAL_FIELDS = [
  "email",
  "contact_person",
  "contact_phone",
  "alternative_phone",
  "address",
  "state",
  "branch",
  "stove_ids",
];

// Common field name variations for mapping
const FIELD_MAPPINGS: Record<string, string[]> = {
  partner_id: [
    "partner_id",
    "partnerid",
    "partner_code",
    "partner-id",
    "id",
    "code",
  ],
  partner_name: [
    "partner_name",
    "partnername",
    "partner-name",
    "name",
    "organization_name",
    "org_name",
  ],
  email: ["email", "email_address", "partner_email", "contact_email"],
  contact_person: [
    "contact_person",
    "contactperson",
    "contact-person",
    "contact_name",
    "representative",
  ],
  contact_phone: [
    "contact_phone",
    "contactphone",
    "contact-phone",
    "phone",
    "primary_phone",
  ],
  alternative_phone: [
    "alternative_phone",
    "alternativephone",
    "alternative-phone",
    "alt_phone",
    "secondary_phone",
  ],
  address: ["address", "full_address", "location", "street_address"],
  state: ["state", "region", "province"],
  branch: ["branch", "branch_name", "office", "location_name"],
  stove_ids: [
    "stove_ids",
    "stoveids",
    "stove-ids",
    "stove_id_list",
    "serial_numbers",
  ],
};

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
    const body: ExternalCSVSyncRequest = await req.json();

    // Validate required fields
    if (
      !body.token ||
      !body.secret_key ||
      !body.application_name ||
      !body.csv_data
    ) {
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message:
              "Missing required fields: token, secret_key, application_name, and csv_data are required",
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

    // Parse CSV data
    const parseResult = parseFlexibleCSV(body.csv_data);
    if (!parseResult.success) {
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: parseResult.error,
          }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        )
      );
    }

    // Process each organization
    const results = [];
    for (const orgData of parseResult.organizations) {
      try {
        const syncResult = await processOrganizationSync(
          supabase,
          orgData,
          orgData.stove_ids || []
        );
        results.push({
          partner_id: orgData.partner_id,
          status: "success",
          result: syncResult,
        });
      } catch (error) {
        results.push({
          partner_id: orgData.partner_id,
          status: "error",
          error: error.message,
        });
      }
    }

    // Update token usage
    await updateTokenUsage(supabase, body.token);

    const successCount = results.filter((r) => r.status === "success").length;
    const errorCount = results.filter((r) => r.status === "error").length;

    return withCors(
      new Response(
        JSON.stringify({
          success: true,
          message: `CSV synchronization completed. ${successCount} successful, ${errorCount} failed.`,
          summary: {
            total_processed: results.length,
            successful: successCount,
            failed: errorCount,
            field_mappings_used: parseResult.mappings_used,
          },
          results: results,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      )
    );
  } catch (error) {
    console.error("External CSV sync error:", error);
    return withCors(
      new Response(
        JSON.stringify({
          success: false,
          message: "Internal server error during CSV synchronization",
          error: error.message,
        }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      )
    );
  }
});

function parseFlexibleCSV(csvData: string): {
  success: boolean;
  organizations?: ParsedOrganization[];
  error?: string;
  mappings_used?: Record<string, string>;
} {
  try {
    const lines = csvData.trim().split("\n");
    if (lines.length < 2) {
      return {
        success: false,
        error: "CSV must contain at least a header row and one data row",
      };
    }

    // Parse header
    const headers = lines[0]
      .split(",")
      .map((h) => h.trim().toLowerCase().replace(/"/g, ""));

    // Find field mappings
    const mappingsUsed: Record<string, string> = {};
    const fieldMap: Record<string, number> = {};

    // Map headers to our expected fields
    for (const [expectedField, variations] of Object.entries(FIELD_MAPPINGS)) {
      for (let i = 0; i < headers.length; i++) {
        const header = headers[i];
        if (variations.includes(header)) {
          fieldMap[expectedField] = i;
          mappingsUsed[expectedField] = header;
          break;
        }
      }
    }

    // Check if required fields are present
    for (const requiredField of REQUIRED_FIELDS) {
      if (!(requiredField in fieldMap)) {
        return {
          success: false,
          error: `Required field '${requiredField}' not found. Expected one of: ${FIELD_MAPPINGS[
            requiredField
          ].join(", ")}`,
        };
      }
    }

    // Parse data rows
    const organizations: ParsedOrganization[] = [];
    for (let i = 1; i < lines.length; i++) {
      const values = lines[i].split(",").map((v) => v.trim().replace(/"/g, ""));

      if (values.length === 0 || values.every((v) => !v)) continue; // Skip empty rows

      const org: ParsedOrganization = {
        partner_id: "",
        partner_name: "",
      };

      // Extract required fields
      org.partner_id = values[fieldMap.partner_id] || "";
      org.partner_name = values[fieldMap.partner_name] || "";

      if (!org.partner_id || !org.partner_name) {
        continue; // Skip rows with missing required data
      }

      // Extract optional fields
      for (const optionalField of OPTIONAL_FIELDS) {
        if (optionalField in fieldMap && values[fieldMap[optionalField]]) {
          const value = values[fieldMap[optionalField]];

          if (optionalField === "stove_ids") {
            // Handle stove IDs - could be comma-separated or semicolon-separated
            org.stove_ids = value
              .split(/[;|]/)
              .map((id) => id.trim())
              .filter((id) => id);
          } else {
            (org as any)[optionalField] = value;
          }
        }
      }

      organizations.push(org);
    }

    if (organizations.length === 0) {
      return {
        success: false,
        error: "No valid organization data found in CSV",
      };
    }

    return {
      success: true,
      organizations,
      mappings_used: mappingsUsed,
    };
  } catch (error) {
    return {
      success: false,
      error: `CSV parsing failed: ${error.message}`,
    };
  }
}

async function validateExternalToken(
  supabase: any,
  token: string,
  secret_key: string,
  application_name: string,
  origin_url?: string
): Promise<{ isValid: boolean; token_data?: any; error?: string }> {
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
  orgData: ParsedOrganization,
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
        branch: orgData.branch,
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
        branch: orgData.branch,
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
    // First get current usage count
    const { data: currentToken } = await supabase
      .from("external_app_tokens")
      .select("usage_count")
      .eq("token", token)
      .single();

    if (currentToken) {
      // Update with incremented count
      await supabase
        .from("external_app_tokens")
        .update({
          usage_count: (currentToken.usage_count || 0) + 1,
          last_used_at: new Date().toISOString(),
        })
        .eq("token", token);
    }
  } catch (error) {
    console.error("Failed to update token usage:", error);
  }
}

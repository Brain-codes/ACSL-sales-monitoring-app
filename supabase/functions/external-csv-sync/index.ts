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

interface UserCreationResult {
  userId: string;
  email: string;
  password: string;
  isDummyEmail: boolean;
}

/**
 * Validate email format
 * Returns true if email is valid, false otherwise
 */
function isValidEmail(email: string | undefined | null): boolean {
  console.log("🔍 ========== EMAIL VALIDATION ==========");
  console.log("Input email:", email);
  console.log("Input type:", typeof email);
  console.log("Input value (JSON):", JSON.stringify(email));
  
  if (!email || typeof email !== 'string') {
    console.log("❌ Validation failed: Email is null, undefined, or not a string");
    console.log("======================================\n");
    return false;
  }
  
  const trimmed = email.trim().toLowerCase();
  console.log("Trimmed & lowercase:", trimmed);
  
  // Check for common invalid values
  const invalidValues = ['', 'n/a', 'na', 'null', 'undefined', 'none', '-', 'nil', 'n.a', 'n/a'];
  if (invalidValues.includes(trimmed)) {
    console.log(`❌ Validation failed: Email matches invalid value (${trimmed})`);
    console.log("======================================\n");
    return false;
  }
  
  // Check for valid email format using regex
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  const isValid = emailRegex.test(trimmed);
  
  if (isValid) {
    console.log("✅ Validation passed: Email is valid");
  } else {
    console.log("❌ Validation failed: Email format is invalid (regex test failed)");
  }
  console.log("======================================\n");
  
  return isValid;
}

// Generate a secure random password
function generatePassword(length: number = 16): string {
  const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*';
  const array = new Uint8Array(length);
  crypto.getRandomValues(array);
  return Array.from(array, (byte) => charset[byte % charset.length]).join('');
}

// Generate dummy email from partner name
function generateDummyEmail(partnerName: string, partnerId: string): string {
  // Sanitize partner name: lowercase, remove special chars, replace spaces with underscore
  const sanitized = partnerName
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, '')
    .replace(/\s+/g, '_')
    .substring(0, 50); // Limit length
  
  return `${sanitized}_${partnerId}@atmosfair.site`;
}

// Create user in auth.users and profiles table
async function createUserForOrganization(
  supabase: any,
  email: string,
  password: string,
  partnerName: string,
  organizationId: string
): Promise<UserCreationResult> {
  try {
    // First, check if user already exists in auth.users by email
    const { data: existingAuthUsers, error: listError } = await supabase.auth.admin.listUsers();
    
    let authUserId: string | null = null;
    
    if (existingAuthUsers?.users) {
      const existingUser = existingAuthUsers.users.find((u: any) => u.email === email);
      if (existingUser) {
        console.log(`⚠️ Auth user already exists with this email (ID: ${existingUser.id}), using existing user`);
        authUserId = existingUser.id;
      }
    }
    
    // Create auth user only if it doesn't exist
    let authUser: any;
    if (!authUserId) {
      const { data: newAuthUser, error: authError } = await supabase.auth.admin.createUser({
        email: email,
        password: password,
        email_confirm: true, // Auto-confirm email
        user_metadata: {
          full_name: partnerName,
          organization_id: organizationId,
        }
      });

      if (authError) throw new Error(`Auth user creation failed: ${authError.message}`);
      if (!newAuthUser.user) throw new Error('User creation returned no user data');
      
      authUser = newAuthUser;
      authUserId = newAuthUser.user.id;
      console.log(`✅ New auth user created with ID: ${authUserId}`);
    } else {
      // Use existing auth user
      authUser = { user: existingAuthUsers.users.find((u: any) => u.id === authUserId) };
    }

    // Check if profile already exists for this user ID
    const { data: existingProfile, error: profileCheckError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', authUserId)
      .maybeSingle();

    if (existingProfile) {
      console.log(`ℹ️ Profile already exists for user ID: ${authUserId}, skipping profile creation`);
      return {
        userId: authUserId,
        email: email,
        password: password,
      };
    }

    // Create profile entry only if it doesn't exist
    console.log(`📝 Creating profile for user ID: ${authUserId}`);
    const { error: profileError } = await supabase
      .from('profiles')
      .insert({
        id: authUserId,
        full_name: partnerName,
        email: email,
        role: 'admin', // Default role for organization admin
        organization_id: organizationId,
        created_at: new Date().toISOString(),
      });

    if (profileError) {
      console.error(`❌ Profile creation error:`, profileError);
      // Only try to clean up if we just created this auth user
      if (!existingAuthUsers?.users?.find((u: any) => u.id === authUserId)) {
        console.log(`🧹 Attempting to clean up auth user: ${authUserId}`);
        await supabase.auth.admin.deleteUser(authUserId);
      }
      throw new Error(`Profile creation failed: ${profileError.message}`);
    }

    console.log(`✅ Profile created successfully for user: ${authUserId}`);

    const isDummyEmail = email.endsWith('@atmosfair.site');

    return {
      userId: authUserId!,
      email: email,
      password: password,
      isDummyEmail: isDummyEmail,
    };
  } catch (error) {
    throw new Error(`User creation failed: ${error.message}`);
  }
}

// Save credentials to credentials table
async function saveCredentials(
  supabase: any,
  partnerId: string,
  partnerName: string,
  email: string,
  password: string,
  organizationId: string,
  userId: string,
  isDummyEmail: boolean
): Promise<void> {
  try {
    const { error } = await supabase
      .from('credentials')
      .insert({
        partner_id: partnerId,
        partner_name: partnerName,
        email: email,
        password: password, // Stored in plaintext for partner reference
        organization_id: organizationId,
        user_id: userId,
        is_dummy_email: isDummyEmail,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });

    if (error) throw new Error(`Failed to save credentials: ${error.message}`);
  } catch (error) {
    throw new Error(`Credentials save failed: ${error.message}`);
  }
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
    console.log("📄 ========== CSV DATA RECEIVED ==========");
    console.log("Raw CSV Data:", body.csv_data);
    console.log("=========================================");
    
    const parseResult = parseFlexibleCSV(body.csv_data);
    if (!parseResult.success) {
      console.error("❌ CSV parsing failed:", parseResult.error);
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

    console.log("✅ CSV parsed successfully");
    console.log(`📊 Total organizations parsed: ${parseResult.organizations?.length || 0}`);
    console.log("📋 Field mappings used:", JSON.stringify(parseResult.mappings_used, null, 2));

    // Process each organization
    const results = [];
    for (const orgData of parseResult.organizations) {
      console.log("\n🔄 ========== PROCESSING ORGANIZATION ==========");
      console.log("Partner ID:", orgData.partner_id);
      console.log("Partner Name:", orgData.partner_name);
      console.log("Email (raw):", orgData.email);
      console.log("Email type:", typeof orgData.email);
      console.log("Email value (JSON):", JSON.stringify(orgData.email));
      console.log("Full org data:", JSON.stringify(orgData, null, 2));
      console.log("==============================================\n");
      
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
        console.error(`❌ Failed to process organization ${orgData.partner_id}:`, error.message);
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
    let userCreated = false;
    let userCredentials: UserCreationResult | null = null;

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
        branch: orgData.branch || 'Main Branch',
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
        branch: orgData.branch || 'Main Branch',
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

      // NEW: Create user for new organization
      console.log(`🆕 New organization created, checking if user needs to be created...`);
      
      // First, check if a user already exists for this organization
      const { data: existingProfile, error: profileCheckError } = await supabase
        .from("profiles")
        .select("*")
        .eq("organization_id", organization.id)
        .maybeSingle();

      if (existingProfile) {
        console.log(`ℹ️ User already exists for organization (email: ${existingProfile.email}), skipping user creation`);
      } else {
        console.log(`👤 No existing user found, creating admin user...`);
        
        // Determine email to use - VALIDATE FIRST, then fallback to dummy
        let userEmail: string;
        let isDummyEmail = false;
        
        console.log("📧 ========== EMAIL DETERMINATION ==========");
        console.log("Provided email:", orgData.email);
        console.log("===========================================\n");
        
        if (isValidEmail(orgData.email)) {
          // Use provided email only if it's valid
          userEmail = orgData.email!.trim();
          isDummyEmail = false;
          console.log(`✅ Using provided email: ${userEmail}`);
        } else {
          // Generate dummy email if no valid email provided
          userEmail = generateDummyEmail(orgData.partner_name, orgData.partner_id);
          isDummyEmail = true;
          if (orgData.email) {
            console.log(`⚠️ Invalid email provided (${orgData.email}), generated dummy email: ${userEmail}`);
          } else {
            console.log(`📧 No email provided, generated dummy email: ${userEmail}`);
          }
        }

        // Generate password
        const password = generatePassword();
        console.log("🔑 Password generated (length):", password.length);

        try {
          console.log(`🚀 Attempting to create user with email: ${userEmail}`);
          
          // Create user in auth and profiles
          userCredentials = await createUserForOrganization(
            supabase,
            userEmail,
            password,
            orgData.partner_name,
            organization.id
          );

          // Save credentials to credentials table (always save for reference)
          await saveCredentials(
            supabase,
            orgData.partner_id,
            orgData.partner_name,
            userEmail,
            password,
            organization.id,
            userCredentials.userId,
            isDummyEmail
          );

          userCreated = true;
          console.log(`✅ Admin user created successfully for organization: ${organization.id}`);
        } catch (userError) {
          console.error(`❌ ========== USER CREATION FAILED ==========`);
          console.error(`Organization: ${orgData.partner_name}`);
          console.error(`Error message: ${userError.message}`);
          console.error(`Full error:`, userError);
          console.error(`============================================\n`);
          // Don't fail the entire sync if user creation fails
          // Organization is still created, just log the error
        }
      }
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
      user: userCreated ? {
        created: true,
        email: userCredentials?.email,
        password: userCredentials?.password,
        is_dummy_email: userCredentials?.isDummyEmail,
      } : {
        created: false,
        reason: existingOrg ? "Organization already exists" : "User creation failed",
      },
      stove_ids: stoveIdResults,
      summary: {
        organization_action: existingOrg ? "updated" : "created",
        user_created: userCreated,
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

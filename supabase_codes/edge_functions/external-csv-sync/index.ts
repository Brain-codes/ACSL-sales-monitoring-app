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
  username?: string;
  password: string;
  isDummyEmail: boolean; // Keep for backward compatibility
  isInternalEmail: boolean; // New field for username-based users
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

  if (!email || typeof email !== "string") {
    console.log(
      "❌ Validation failed: Email is null, undefined, or not a string"
    );
    console.log("======================================\n");
    return false;
  }

  const trimmed = email.trim().toLowerCase();
  console.log("Trimmed & lowercase:", trimmed);

  // Check for common invalid values
  const invalidValues = [
    "",
    "n/a",
    "na",
    "null",
    "undefined",
    "none",
    "-",
    "nil",
    "n.a",
    "n/a",
  ];
  if (invalidValues.includes(trimmed)) {
    console.log(
      `❌ Validation failed: Email matches invalid value (${trimmed})`
    );
    console.log("======================================\n");
    return false;
  }

  // Check for valid email format using regex
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  const isValid = emailRegex.test(trimmed);

  if (isValid) {
    console.log("✅ Validation passed: Email is valid");
  } else {
    console.log(
      "❌ Validation failed: Email format is invalid (regex test failed)"
    );
  }
  console.log("======================================\n");

  return isValid;
}

/**
 * Generate username from partner name and ID
 * Format: partnerId_FirstWord (e.g., "B8A107_nabda" or "598581_lapo")
 * - Uses partner_id as base for uniqueness
 * - Adds first significant word from partner name for readability
 * - Short and simple (max ~15 characters)
 */
function generateUsername(partnerName: string, partnerId: string): string {
  // Clean and get first meaningful word from partner name
  const words = partnerName
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, "") // Remove special characters
    .trim()
    .split(/\s+/) // Split into words
    .filter(word => word.length > 2); // Filter out short words like "of", "to", etc.
  
  // Get first significant word (max 8 chars)
  let namePrefix = words[0] || "user";
  if (namePrefix.length > 8) {
    namePrefix = namePrefix.substring(0, 8);
  }

  // Clean partner_id: remove special chars, keep alphanumeric
  const cleanId = partnerId.replace(/[^a-z0-9]/gi, "").toLowerCase();

  // Format: partnerId_name (e.g., "b8a107_nabda" or "598581_lapo")
  return `${cleanId}_${namePrefix}`;
}

/**
 * Normalize branch value - convert NA/N/A variations to 'Main Branch'
 */
function normalizeBranch(branch: string | undefined): string {
  if (!branch) return "Main Branch";
  
  const trimmed = branch.trim();
  const normalized = trimmed.toUpperCase();
  
  // Check for NA variations
  if (normalized === "NA" || normalized === "N/A" || normalized === "N.A." || normalized === "NOT AVAILABLE") {
    return "Main Branch";
  }
  
  return trimmed; // Return original case if not NA
}

/**
 * Generate internal email from username
 * Format: username@internal.acsl.local (never exposed to users)
 */
function generateInternalEmail(username: string): string {
  return `${username}@internal.acsl.local`;
}

// Generate a secure random password
function generatePassword(length: number = 16): string {
  const charset =
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*";
  const array = new Uint8Array(length);
  crypto.getRandomValues(array);
  return Array.from(array, (byte) => charset[byte % charset.length]).join("");
}

// Create user in auth.users and profiles table
async function createUserForOrganization(
  supabase: any,
  email: string,
  username: string | undefined,
  password: string,
  partnerName: string,
  organizationId: string,
  isInternalEmail: boolean
): Promise<UserCreationResult> {
  try {
    console.log(`\n🔵 ========== CREATE USER FUNCTION CALLED ==========`);
    console.log(`   Email: ${email}`);
    console.log(`   Username: ${username}`);
    console.log(`   Partner Name: ${partnerName}`);
    console.log(`   Organization ID: ${organizationId}`);
    console.log(`   Is Internal Email: ${isInternalEmail}`);
    console.log(`=====================================================\n`);

    // First, check if user already exists in auth.users by email
    const { data: existingAuthUsers, error: listError } =
      await supabase.auth.admin.listUsers();

    let authUserId: string | null = null;

    if (existingAuthUsers?.users) {
      const existingUser = existingAuthUsers.users.find(
        (u: any) => u.email === email
      );
      if (existingUser) {
        console.log(
          `⚠️ Auth user already exists with this email (ID: ${existingUser.id}), using existing user`
        );
        authUserId = existingUser.id;
      }
    }

    // Create auth user only if it doesn't exist
    let authUser: any;
    if (!authUserId) {
      const { data: newAuthUser, error: authError } =
        await supabase.auth.admin.createUser({
          email: email,
          password: password,
          email_confirm: true, // Auto-confirm email
          user_metadata: {
            full_name: partnerName,
            organization_id: organizationId,
            username: username,
          },
        });

      if (authError)
        throw new Error(`Auth user creation failed: ${authError.message}`);
      if (!newAuthUser.user)
        throw new Error("User creation returned no user data");

      authUser = newAuthUser;
      authUserId = newAuthUser.user.id;
      console.log(`✅ New auth user created with ID: ${authUserId}`);
    } else {
      // Use existing auth user
      authUser = {
        user: existingAuthUsers.users.find((u: any) => u.id === authUserId),
      };
    }

    // Check if profile already exists for this user ID
    console.log(`\n🔍 Checking if profile exists for user ID: ${authUserId}...`);
    const { data: existingProfile, error: profileCheckError } = await supabase
      .from("profiles")
      .select("*")
      .eq("id", authUserId)
      .maybeSingle();

    console.log(`📊 Profile check result:`);
    console.log(`   Profile exists: ${!!existingProfile}`);
    console.log(`   Profile check error: ${profileCheckError ? JSON.stringify(profileCheckError) : 'none'}`);
    if (existingProfile) {
      console.log(`   Existing profile data:`, JSON.stringify(existingProfile, null, 2));
    }

    if (existingProfile) {
      console.log(
        `\n⚠️ Profile already exists for user ID: ${authUserId}, attempting to update...`
      );
      console.log(`📋 Current Values in Database:`);
      console.log(`   username: ${existingProfile.username || 'NULL'}`);
      console.log(`   role: ${existingProfile.role || 'NULL'}`);
      console.log(`   email: ${existingProfile.email || 'NULL'}`);
      console.log(`   full_name: ${existingProfile.full_name || 'NULL'}`);
      console.log(`\n📝 New Values to Set:`);
      console.log(`   username: ${username}`);
      console.log(`   role: admin`);
      
      console.log(`\n🚀 Executing UPDATE query...`);
      // ✅ FIX: Update existing profile to ensure username and role are set
      const { data: updatedProfile, error: updateError } = await supabase
        .from("profiles")
        .update({
          username: username, // Ensure username is set
          role: "admin", // Ensure role is set to admin
          // updated_at removed - column doesn't exist in profiles table
        })
        .eq("id", authUserId)
        .select(); // ✅ Return updated data to verify

      console.log(`\n📊 UPDATE Result:`);
      if (updateError) {
        console.error(`❌ UPDATE FAILED!`);
        console.error(`   Error message: ${updateError.message}`);
        console.error(`   Error code: ${updateError.code}`);
        console.error(`   Error hint: ${updateError.hint}`);
        console.error(`   Full error details:`, JSON.stringify(updateError, null, 2));
      } else {
        console.log(`✅ UPDATE SUCCESSFUL!`);
        console.log(`   Rows affected: ${updatedProfile?.length || 0}`);
        if (updatedProfile && updatedProfile.length > 0) {
          console.log(`   Updated profile:`, JSON.stringify(updatedProfile[0], null, 2));
          console.log(`\n✅ VERIFICATION:`);
          console.log(`   username is now: ${updatedProfile[0].username || 'STILL NULL!'}`);
          console.log(`   role is now: ${updatedProfile[0].role || 'STILL NULL!'}`);
        } else {
          console.log(`   ⚠️ No data returned from update!`);
        }
      }

      return {
        userId: authUserId!,
        email: email,
        username: username,
        password: password,
        isDummyEmail: email.endsWith("@atmosfair.site"),
        isInternalEmail: isInternalEmail,
      };
    }

    // Create profile entry only if it doesn't exist
    console.log(`📝 Creating profile for user ID: ${authUserId}`);
    const { error: profileError } = await supabase.from("profiles").insert({
      id: authUserId,
      full_name: partnerName,
      email: email,
      username: username,
      role: "admin", // Default role for organization admin
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

    const isDummyEmail = email.endsWith("@atmosfair.site");

    return {
      userId: authUserId!,
      email: email,
      username: username,
      password: password,
      isDummyEmail: isDummyEmail,
      isInternalEmail: isInternalEmail,
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
  username: string | undefined,
  password: string,
  organizationId: string,
  userId: string,
  isDummyEmail: boolean,
  isInternalEmail: boolean
): Promise<void> {
  try {
    const { error } = await supabase.from("credentials").insert({
      partner_id: partnerId,
      partner_name: partnerName,
      email: email,
      username: username,
      password: password, // Stored in plaintext for partner reference
      organization_id: organizationId,
      user_id: userId,
      profile_id: userId, // ✅ FIX: Link credential to profile (requires migration to be run first)
      role: "admin", // ✅ Always set role to admin for synced organizations
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
    "stove ids", // ✅ FIX: Support "Stove IDs" with space
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
    // Initialize Supabase client with auth options to bypass RLS
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
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
    console.log(
      `📊 Total organizations parsed: ${parseResult.organizations?.length || 0}`
    );
    console.log(
      "📋 Field mappings used:",
      JSON.stringify(parseResult.mappings_used, null, 2)
    );

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
        console.error(
          `❌ Failed to process organization ${orgData.partner_id}:`,
          error.message
        );
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
        branch: normalizeBranch(orgData.branch), // ✅ FIX: Normalize NA variations to 'Main Branch'
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
        branch: normalizeBranch(orgData.branch), // ✅ FIX: Normalize NA variations to 'Main Branch'
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
      console.log(
        `🆕 New organization created, checking if user needs to be created...`
      );

      // First, check if a user already exists for this organization
      const { data: existingProfile, error: profileCheckError } = await supabase
        .from("profiles")
        .select("*")
        .eq("organization_id", organization.id)
        .maybeSingle();

      if (existingProfile) {
        console.log(
          `ℹ️ User already exists for organization (email: ${existingProfile.email}), skipping user creation`
        );
      } else {
        console.log(`👤 No existing user found, creating admin user...`);

        // Determine authentication method - email OR username
        let userEmail: string;
        let username: string | undefined;
        let isInternalEmail = false;
        let isDummyEmail = false; // Keep for backward compatibility

        console.log("📧 ========== AUTHENTICATION DETERMINATION ==========");
        console.log("Provided email:", orgData.email);
        console.log("===================================================\n");

        if (isValidEmail(orgData.email)) {
          // Use provided email for authentication (traditional email-based users)
          userEmail = orgData.email!.trim();
          username = undefined;
          isInternalEmail = false;
          isDummyEmail = false; // Real email provided
          console.log(`✅ Using provided email: ${userEmail}`);
        } else {
          // Generate username for authentication (new username-based users)
          username = generateUsername(orgData.partner_name, orgData.partner_id);
          userEmail = generateInternalEmail(username);
          isInternalEmail = true;
          isDummyEmail = true; // ✅ FIX: Generated internal email IS a dummy email

          if (orgData.email) {
            console.log(
              `⚠️ Invalid email provided (${orgData.email}), generated username: ${username}`
            );
          } else {
            console.log(`� No email provided, generated username: ${username}`);
          }
          console.log(
            `📧 Internal email created: ${userEmail} (not exposed to user)`
          );
        }

        // Generate password
        const password = generatePassword();
        console.log("🔑 Password generated (length):", password.length);

        try {
          console.log(`🚀 Attempting to create user...`);
          console.log(`   Username: ${username || "N/A (email-based)"}`);
          console.log(`   Email: ${userEmail.substring(0, 10)}...`);

          // Create user in auth and profiles
          userCredentials = await createUserForOrganization(
            supabase,
            userEmail,
            username,
            password,
            orgData.partner_name,
            organization.id,
            isInternalEmail
          );

          // Save credentials to credentials table (always save for reference)
          await saveCredentials(
            supabase,
            orgData.partner_id,
            orgData.partner_name,
            userEmail,
            username,
            password,
            organization.id,
            userCredentials.userId,
            isDummyEmail,
            isInternalEmail
          );

          userCreated = true;
          console.log(
            `✅ Admin user created successfully for organization: ${organization.id}`
          );
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
    // console.log(`📦 ========== PROCESSING STOVE IDs ==========`);
    // console.log(`Total stove IDs to process: ${stoveIds?.length || 0}`);
    // console.log(`Stove IDs array:`, stoveIds);
    // console.log(`Organization ID: ${organization.id}`);
    // console.log(`===========================================\n`);

    if (stoveIds && stoveIds.length > 0) {
      for (const stoveId of stoveIds) {
        if (!stoveId || stoveId.trim() === "") {
          // console.log(`⚠️ Skipping empty stove ID`);
          continue;
        }

        // console.log(`🔍 Processing stove ID: ${stoveId.trim()}`);

        // Check if stove ID already exists
        const { data: existingStove, error: checkError } = await supabase
          .from("stove_ids")
          .select("*")
          .eq("stove_id", stoveId.trim())
          .eq("organization_id", organization.id)
          .single();

        if (checkError && checkError.code !== "PGRST116") {
          // PGRST116 = no rows found, which is expected for new stove IDs
          // console.error(`❌ Error checking stove ID:`, checkError);
        }

        if (!existingStove) {
          // console.log(`➕ Creating new stove ID: ${stoveId.trim()}`);

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

          if (stoveError) {
            console.error(
              `❌ Failed to create stove ID ${stoveId.trim()}:`,
              stoveError
            );
            // console.error(
            //   `   Error details:`,
            //   JSON.stringify(stoveError, null, 2)
            // );
          } else {
            // console.log(`✅ Stove ID created successfully: ${stoveId.trim()}`);
            stoveIdResults.push({
              stove_id: stoveId.trim(),
              action: "created",
            });
          }
        } else {
          // console.log(`ℹ️ Stove ID already exists: ${stoveId.trim()}`);
          stoveIdResults.push({
            stove_id: stoveId.trim(),
            action: "already_exists",
          });
        }
      }
    } else {
      // console.log(`⚠️ No stove IDs provided or empty array`);
    }

    console.log(`\n📊 STOVE ID SUMMARY: Total processed: ${stoveIdResults.length}, Created: ${stoveIdResults.filter((s) => s.action === "created").length}, Already existed: ${stoveIdResults.filter((s) => s.action === "already_exists").length}`);

    // console.log(`\n📊 ========== STOVE ID PROCESSING SUMMARY ==========`);
    // console.log(`Total processed: ${stoveIdResults.length}`);
    // console.log(
    //   `Created: ${stoveIdResults.filter((s) => s.action === "created").length}`
    // );
    // console.log(
    //   `Already exists: ${
    //     stoveIdResults.filter((s) => s.action === "already_exists").length
    //   }`
    // );
    // console.log(`====================================================\n`);

    return {
      organization: {
        id: organization.id,
        partner_id: organization.partner_id,
        partner_name: organization.partner_name,
        action: existingOrg ? "updated" : "created",
      },
      user: userCreated
        ? {
            created: true,
            username: userCredentials?.username,
            email: userCredentials?.isInternalEmail
              ? undefined
              : userCredentials?.email,
            password: userCredentials?.password,
            is_internal_email: userCredentials?.isInternalEmail,
            login_identifier:
              userCredentials?.username || userCredentials?.email,
          }
        : {
            created: false,
            reason: existingOrg
              ? "Organization already exists"
              : "User creation failed",
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

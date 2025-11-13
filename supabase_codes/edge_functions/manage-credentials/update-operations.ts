// Update operations for credentials management
import {
  SupabaseClient,
  createClient,
} from "https://esm.sh/@supabase/supabase-js@2.39.3";

export interface UpdatePasswordRequest {
  partner_id: string;
  new_password: string;
  super_admin_password: string;
  super_admin_email: string;
}

/**
 * Update password for an organization (Super Admin only with password verification)
 * Updates both credentials table and auth.users
 */
export async function updateOrganizationPassword(
  supabase: SupabaseClient,
  request: UpdatePasswordRequest
): Promise<{ success: boolean; message?: string; error?: string }> {
  try {
    const {
      partner_id,
      new_password,
      super_admin_password,
      super_admin_email,
    } = request;

    // Step 1: Verify Super Admin's password
    console.log("🔐 Verifying Super Admin password...");

    // Create a separate client for password verification
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const verifyClient = createClient(supabaseUrl, supabaseAnonKey);

    const { data: authData, error: authError } =
      await verifyClient.auth.signInWithPassword({
        email: super_admin_email,
        password: super_admin_password,
      });

    if (authError || !authData.user) {
      console.error("❌ Super Admin password verification failed");
      return {
        success: false,
        error: "Invalid Super Admin password. Authorization denied.",
      };
    }

    console.log("✅ Super Admin password verified");

    // Step 2: Get credential record by partner_id
    console.log(`📋 Fetching credential for partner: ${partner_id}`);
    const { data: credential, error: credError } = await supabase
      .from("credentials")
      .select("*")
      .eq("partner_id", partner_id)
      .single();

    if (credError || !credential) {
      console.error("❌ Credential not found");
      return { success: false, error: "Credential not found for this partner" };
    }

    console.log(`✅ Credential found for user: ${credential.email}`);

    // Step 3: Update password in auth.users using service role
    console.log("🔑 Updating password in auth.users...");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { error: updateAuthError } =
      await adminClient.auth.admin.updateUserById(credential.user_id, {
        password: new_password,
      });

    if (updateAuthError) {
      console.error("❌ Failed to update auth password:", updateAuthError);
      return {
        success: false,
        error: `Failed to update authentication password: ${updateAuthError.message}`,
      };
    }

    console.log("✅ Auth password updated successfully");

    // Step 4: Update password in credentials table
    console.log("💾 Updating password in credentials table...");
    const { error: updateCredError } = await supabase
      .from("credentials")
      .update({
        password: new_password,
        updated_at: new Date().toISOString(),
      })
      .eq("partner_id", partner_id);

    if (updateCredError) {
      console.error("❌ Failed to update credential:", updateCredError);
      return {
        success: false,
        error: `Failed to update credential record: ${updateCredError.message}`,
      };
    }

    console.log("✅ Credential updated successfully");

    return {
      success: true,
      message: `Password successfully updated for organization: ${credential.partner_name}`,
    };
  } catch (error) {
    console.error("❌ Unexpected error updating password:", error);
    return { success: false, error: "Failed to update password" };
  }
}

/**
 * Generate a secure random password
 */
export function generateSecurePassword(length: number = 16): string {
  const charset =
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*";
  const array = new Uint8Array(length);
  crypto.getRandomValues(array);
  return Array.from(array, (byte) => charset[byte % charset.length]).join("");
}

/**
 * Reset password for an organization (Auto-generates password OR use custom)
 * Super Admin only - requires password verification
 */
export async function resetOrganizationPassword(
  supabase: SupabaseClient,
  partnerId: string,
  superAdminEmail: string,
  superAdminPassword: string,
  customPassword?: string // Optional: If provided, use this instead of auto-generating
): Promise<{
  success: boolean;
  message?: string;
  newPassword?: string;
  error?: string;
}> {
  try {
    console.log("🔄 Starting password reset process...");
    console.log(`📋 Partner ID: ${partnerId}`);
    console.log(`👤 Super Admin: ${superAdminEmail}`);
    console.log(
      `🔑 Password mode: ${customPassword ? "Custom" : "Auto-generated"}`
    );

    // Step 1: Verify Super Admin's password
    console.log("🔐 Verifying Super Admin password...");

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const verifyClient = createClient(supabaseUrl, supabaseAnonKey);

    const { data: authData, error: authError } =
      await verifyClient.auth.signInWithPassword({
        email: superAdminEmail,
        password: superAdminPassword,
      });

    if (authError || !authData.user) {
      console.error("❌ Super Admin password verification failed");
      return {
        success: false,
        error: "Invalid Super Admin password",
      };
    }

    console.log("✅ Super Admin password verified");

    // Step 2: Get credential record by partner_id
    console.log(`📋 Fetching credential for partner: ${partnerId}`);
    const { data: credential, error: credError } = await supabase
      .from("credentials")
      .select("*")
      .eq("partner_id", partnerId)
      .single();

    if (credError || !credential) {
      console.error("❌ Credential not found");
      return {
        success: false,
        error: `Partner not found with ID: ${partnerId}`,
      };
    }

    console.log(`✅ Credential found for user: ${credential.email}`);

    // Step 3: Use custom password OR auto-generate new secure password
    let newPassword: string;
    if (customPassword && customPassword.trim().length > 0) {
      newPassword = customPassword.trim();
      console.log("🔑 Using custom password provided by Super Admin");
      
      // Validate custom password strength (minimum 8 characters)
      if (newPassword.length < 8) {
        return {
          success: false,
          error: "Custom password must be at least 8 characters long",
        };
      }
    } else {
      newPassword = generateSecurePassword(16);
      console.log("🔑 Auto-generated new secure password (length: 16)");
    }

    // Step 4: Update password in auth.users using service role
    console.log("🔑 Updating password in auth.users...");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { error: updateAuthError } =
      await adminClient.auth.admin.updateUserById(credential.user_id, {
        password: newPassword,
      });

    if (updateAuthError) {
      console.error("❌ Failed to update auth password:", updateAuthError);
      return {
        success: false,
        error: `Failed to update authentication password: ${updateAuthError.message}`,
      };
    }

    console.log("✅ Auth password updated successfully");

    // Step 5: Update password in credentials table
    console.log("💾 Updating password in credentials table...");
    const { error: updateCredError } = await supabase
      .from("credentials")
      .update({
        password: newPassword,
        updated_at: new Date().toISOString(),
      })
      .eq("partner_id", partnerId);

    if (updateCredError) {
      console.error("❌ Failed to update credential:", updateCredError);
      return {
        success: false,
        error: `Failed to update credential record: ${updateCredError.message}`,
      };
    }

    console.log("✅ Credential updated successfully");
    console.log("🎉 Password reset completed!");

    return {
      success: true,
      message: `Password reset successfully for partner: ${partnerId}`,
      newPassword: newPassword,
    };
  } catch (error) {
    console.error("❌ Unexpected error resetting password:", error);
    return { success: false, error: "Failed to reset password" };
  }
}

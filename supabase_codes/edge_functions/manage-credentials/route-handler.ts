// Route handler for manage-credentials edge function
import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { withCors } from "./cors.ts";
import {
  getAllCredentials,
  getCredentialByPartnerId,
  getCredentialByOrganizationId,
} from "./read-operations.ts";
import {
  updateOrganizationPassword,
  resetOrganizationPassword,
  generateSecurePassword,
} from "./update-operations.ts";

export async function handleRequest(
  req: Request,
  supabase: SupabaseClient,
  authenticatedUser?: { id: string; email: string; role: string }
): Promise<Response> {
  const url = new URL(req.url);
  const method = req.method;

  console.log("📍 Route Handler - Processing request");
  console.log("🔗 Full URL:", url.href);
  console.log("🌐 Method:", method);
  console.log("📂 Pathname:", url.pathname);
  console.log("🔍 Query params:", url.searchParams.toString());

  try {
    // GET /manage-credentials - Get all credentials
    if (method === "GET" && url.pathname.endsWith("/manage-credentials")) {
      console.log("📋 Route matched: GET all credentials");
      console.log("🔄 Fetching all credentials from database...");

      const result = await getAllCredentials(supabase);

      if (!result.success) {
        console.error("❌ Failed to get credentials:", result.error);
        return withCors(
          new Response(
            JSON.stringify({ success: false, error: result.error }),
            { status: 400, headers: { "Content-Type": "application/json" } }
          )
        );
      }

      console.log("✅ Successfully retrieved credentials");
      console.log("📊 Count:", result.count);

      return withCors(
        new Response(
          JSON.stringify({
            success: true,
            data: result.data,
            count: result.count,
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        )
      );
    }

    // GET /manage-credentials?partner_id=XXX - Get credential by partner ID
    if (method === "GET" && url.searchParams.has("partner_id")) {
      const partnerId = url.searchParams.get("partner_id")!;
      const result = await getCredentialByPartnerId(supabase, partnerId);

      if (!result.success) {
        return withCors(
          new Response(
            JSON.stringify({ success: false, error: result.error }),
            { status: 404, headers: { "Content-Type": "application/json" } }
          )
        );
      }

      return withCors(
        new Response(JSON.stringify({ success: true, data: result.data }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      );
    }

    // GET /manage-credentials?organization_id=XXX - Get credential by organization ID
    if (method === "GET" && url.searchParams.has("organization_id")) {
      const orgId = url.searchParams.get("organization_id")!;
      const result = await getCredentialByOrganizationId(supabase, orgId);

      if (!result.success) {
        return withCors(
          new Response(
            JSON.stringify({ success: false, error: result.error }),
            { status: 404, headers: { "Content-Type": "application/json" } }
          )
        );
      }

      return withCors(
        new Response(JSON.stringify({ success: true, data: result.data }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      );
    }

    // PUT /manage-credentials/update-password - Reset organization password (Auto-generate OR Custom)
    if (method === "PUT" && url.pathname.includes("/update-password")) {
      console.log("🔐 Route matched: PUT /update-password (Reset Password)");
      const body = await req.json();

      console.log("📋 Request body:", JSON.stringify(body, null, 2));

      // Validate required fields
      if (!body.partner_id || !body.super_admin_password) {
        console.error("❌ Missing required fields");
        return withCors(
          new Response(
            JSON.stringify({
              success: false,
              error:
                "Missing required fields: partner_id, super_admin_password",
            }),
            { status: 400, headers: { "Content-Type": "application/json" } }
          )
        );
      }

      // Use authenticated user's email
      const superAdminEmail = authenticatedUser?.email;
      if (!superAdminEmail) {
        console.error("❌ Authenticated user email not found");
        return withCors(
          new Response(
            JSON.stringify({
              success: false,
              error: "Super Admin email not found in session",
            }),
            { status: 400, headers: { "Content-Type": "application/json" } }
          )
        );
      }

      // Check if custom password is provided, otherwise auto-generate
      const customPassword = body.new_password?.trim();
      const passwordMode = customPassword ? "custom" : "auto-generated";

      console.log(
        `🔄 Resetting password for partner: ${body.partner_id} by ${superAdminEmail}`
      );
      console.log(`🔑 Password mode: ${passwordMode}`);

      const result = await resetOrganizationPassword(
        supabase,
        body.partner_id,
        superAdminEmail,
        body.super_admin_password,
        customPassword // Pass custom password if provided, undefined otherwise
      );

      if (!result.success) {
        console.error("❌ Password reset failed:", result.error);
        return withCors(
          new Response(
            JSON.stringify({ success: false, error: result.error }),
            { status: 400, headers: { "Content-Type": "application/json" } }
          )
        );
      }

      console.log("✅ Password reset successful!");
      console.log(`🔑 Password ${passwordMode}: ${result.newPassword}`);

      return withCors(
        new Response(
          JSON.stringify({
            success: true,
            message: result.message,
            newPassword: result.newPassword,
            passwordMode: passwordMode,
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        )
      );
    }

    // PUT /manage-credentials/update-password-custom - Update with custom password (legacy)
    if (
      method === "PUT" &&
      url.pathname.includes("/update-password-custom")
    ) {
      const body = await req.json();

      // Validate required fields
      if (
        !body.partner_id ||
        !body.new_password ||
        !body.super_admin_password ||
        !body.super_admin_email
      ) {
        return withCors(
          new Response(
            JSON.stringify({
              success: false,
              error:
                "Missing required fields: partner_id, new_password, super_admin_password, super_admin_email",
            }),
            { status: 400, headers: { "Content-Type": "application/json" } }
          )
        );
      }

      const result = await updateOrganizationPassword(supabase, body);

      if (!result.success) {
        return withCors(
          new Response(
            JSON.stringify({ success: false, error: result.error }),
            { status: 400, headers: { "Content-Type": "application/json" } }
          )
        );
      }

      return withCors(
        new Response(
          JSON.stringify({
            success: true,
            message: result.message,
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        )
      );
    }

    // POST /manage-credentials/generate-password - Generate a secure password (helper)
    if (method === "POST" && url.pathname.includes("/generate-password")) {
      const body = await req.json();
      const length = body.length || 16;
      const password = generateSecurePassword(length);

      return withCors(
        new Response(
          JSON.stringify({
            success: true,
            password: password,
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        )
      );
    }

    // Route not found
    return withCors(
      new Response(
        JSON.stringify({
          success: false,
          error: "Route not found",
          available_routes: [
            "GET /manage-credentials - Get all credentials",
            "GET /manage-credentials?partner_id=XXX - Get credential by partner ID",
            "GET /manage-credentials?organization_id=XXX - Get credential by organization ID",
            "PUT /manage-credentials/update-password - Update organization password",
            "POST /manage-credentials/generate-password - Generate secure password",
          ],
        }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      )
    );
  } catch (error) {
    console.error("Request handling error:", error);
    return withCors(
      new Response(
        JSON.stringify({
          success: false,
          error: "Internal server error",
        }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      )
    );
  }
}

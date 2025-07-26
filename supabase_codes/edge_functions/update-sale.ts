import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js";
// Utility
function withCors(res) {
  res.headers.set("Access-Control-Allow-Origin", "*");
  res.headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.headers.set(
    "Access-Control-Allow-Headers",
    "Content-Type, Authorization"
  );
  return res;
}
function log(...args) {
  console.log("🧠", ...args);
}
serve(async (req) => {
  const url = new URL(req.url);
  const saleId = url.searchParams.get("id");
  log("➡️ Update sale triggered. Sale ID:", saleId);
  if (req.method === "OPTIONS")
    return withCors(
      new Response("ok", {
        status: 200,
      })
    );
  if (!saleId)
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
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL"),
    Deno.env.get("SUPABASE_ANON_KEY"),
    {
      global: {
        headers: {
          Authorization: req.headers.get("Authorization") ?? "",
        },
      },
    }
  );
  try {
    const body = await req.json();
    log("📦 Incoming update payload:", body);
    // Auth
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
    log("🔐 Authenticated user:", userId);

    // Get user profile for organization context
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("organization_id")
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

    const updatedFields = {};
    // 🔁 Map camelCase to snake_case
    const map = (src, key, dbKey) => {
      if (src[key] !== undefined) updatedFields[dbKey ?? key] = src[key];
    };
    map(body, "transactionId", "transaction_id");
    map(body, "stoveSerialNo", "stove_serial_no");
    map(body, "salesDate", "sales_date");
    map(body, "contactPerson", "contact_person");
    map(body, "contactPhone", "contact_phone");
    map(body, "endUserName", "end_user_name");
    map(body, "aka");
    map(body, "stateBackup", "state_backup");
    map(body, "lgaBackup", "lga_backup");
    map(body, "phone");
    map(body, "otherPhone", "other_phone");
    map(body, "partnerName", "partner_name");
    map(body, "amount");
    map(body, "signature");
    map(body, "stoveImageId", "stove_image_id");
    map(body, "agreementImageId", "agreement_image_id");
    // 🏡 Address handling
    if (body.address) {
      const addr = body.address;
      log("📍 Processing address:", addr);
      if (addr.id) {
        const { error: addressUpdateError } = await supabase
          .from("addresses")
          .update({
            full_address: addr.full_address,
            street: addr.street,
            city: addr.city,
            state: addr.state,
            country: addr.country,
            latitude: addr.latitude,
            longitude: addr.longitude,
          })
          .eq("id", addr.id);
        if (addressUpdateError) {
          log("❌ Address update failed:", addressUpdateError);
          return withCors(
            new Response(
              JSON.stringify({
                success: false,
                message: "Address update failed",
                error: addressUpdateError,
              }),
              {
                status: 500,
              }
            )
          );
        }
        log("✅ Address updated. Address ID:", addr.id);
        updatedFields.address_id = addr.id;
      }
    }
    log("📝 Final update fields:", updatedFields);

    // Recalculate status if any relevant fields were updated
    const statusRelevantFields = [
      "transaction_id",
      "stove_serial_no",
      "sales_date",
      "contact_person",
      "contact_phone",
      "end_user_name",
      "phone",
      "partner_name",
      "amount",
      "signature",
      "stove_image_id",
      "agreement_image_id",
    ];
    const hasStatusRelevantUpdates = statusRelevantFields.some((field) =>
      Object.keys(updatedFields).includes(field)
    );

    if (hasStatusRelevantUpdates) {
      // Get current sale data to recalculate status
      const { data: currentSale, error: fetchError } = await supabase
        .from("sales")
        .select("*")
        .eq("id", saleId)
        .eq("organization_id", profile.organization_id)
        .maybeSingle();

      if (!fetchError && currentSale) {
        // Merge current data with updates for status calculation
        const mergedData = { ...currentSale, ...updatedFields };

        // Calculate new status
        const requiredFields = [
          mergedData.transaction_id,
          mergedData.stove_serial_no,
          mergedData.sales_date,
          mergedData.contact_person,
          mergedData.contact_phone,
          mergedData.end_user_name,
          mergedData.phone,
          mergedData.partner_name,
          mergedData.amount,
        ];
        const hasAllRequiredFields = requiredFields.every(
          (field) =>
            field !== null && field !== undefined && String(field).trim() !== ""
        );
        const hasSignature =
          mergedData.signature && String(mergedData.signature).trim() !== "";
        const hasStoveImage =
          mergedData.stove_image_id !== null &&
          mergedData.stove_image_id !== undefined;
        const hasAgreementImage =
          mergedData.agreement_image_id !== null &&
          mergedData.agreement_image_id !== undefined;

        let newStatus = "incomplete"; // Default status
        if (
          hasAllRequiredFields &&
          hasSignature &&
          hasStoveImage &&
          hasAgreementImage
        ) {
          newStatus = "completed";
        } else if (
          hasAllRequiredFields &&
          (hasSignature || hasStoveImage || hasAgreementImage)
        ) {
          newStatus = "pending";
        }

        // Add calculated status to updates
        updatedFields.status = newStatus;
        log("📊 Recalculated status:", newStatus);
      }
    }

    if (Object.keys(updatedFields).length === 0) {
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "No fields provided for update",
          }),
          {
            status: 400,
          }
        )
      );
    }
    const { error: updateError } = await supabase
      .from("sales")
      .update(updatedFields)
      .eq("id", saleId);
    if (updateError) {
      log("❌ Sale update failed:", updateError);
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "Failed to update sale",
            error: updateError,
          }),
          {
            status: 500,
          }
        )
      );
    }
    log("✅ Sale updated successfully");
    return withCors(
      new Response(
        JSON.stringify({
          success: true,
          message: "Sale updated successfully",
        }),
        {
          status: 200,
        }
      )
    );
  } catch (err) {
    log("🔥 Unexpected error:", err);
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

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js";
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
  console.log("➡️ Incoming request:", req.method, req.url);
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
    console.log("📦 Request body received:", body);
    const {
      transactionId,
      stoveSerialNo,
      salesDate,
      contactPerson,
      contactPhone,
      endUserName,
      aka,
      stateBackup,
      lgaBackup,
      phone,
      otherPhone,
      partnerName,
      amount,
      signature,
      addressData,
      stoveImageId,
      agreementImageId,
    } = body;
    // Authenticate user
    console.log("🔐 Authenticating user...");
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
    console.log("✅ Authenticated user:", userId);
    // Get organization
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
    console.log("🏢 User organization ID:", profile.organization_id);
    // Insert address
    console.log("📍 Inserting address:", addressData);
    const { data: address, error: addressError } = await supabase
      .from("addresses")
      .insert([
        {
          full_address: addressData.fullAddress,
          street: addressData.street,
          city: addressData.city,
          state: addressData.state,
          country: addressData.country,
          latitude: addressData.latitude,
          longitude: addressData.longitude,
        },
      ])
      .select()
      .maybeSingle();
    if (addressError || !address) {
      console.error("❌ Address save failed:", addressError);
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "Address save failed",
            addressError,
          }),
          {
            status: 500,
          }
        )
      );
    }
    console.log("🏡 Address inserted:", address);
    // Determine sale status based on data completeness
    const requiredFields = [
      transactionId,
      stoveSerialNo,
      salesDate,
      contactPerson,
      contactPhone,
      endUserName,
      phone,
      partnerName,
      amount,
    ];
    const hasAllRequiredFields = requiredFields.every(
      (field) =>
        field !== null && field !== undefined && String(field).trim() !== ""
    );
    const hasSignature = signature && String(signature).trim() !== "";
    const hasStoveImage = stoveImageId !== null && stoveImageId !== undefined;
    const hasAgreementImage =
      agreementImageId !== null && agreementImageId !== undefined;

    let saleStatus = "incomplete"; // Default status
    if (
      hasAllRequiredFields &&
      hasSignature &&
      hasStoveImage &&
      hasAgreementImage
    ) {
      saleStatus = "completed";
    } else if (
      hasAllRequiredFields &&
      (hasSignature || hasStoveImage || hasAgreementImage)
    ) {
      saleStatus = "pending";
    }

    // Insert sale
    console.log("📝 Inserting main sale with status:", saleStatus);
    const { data: saleInsertData, error: saleError } = await supabase
      .from("sales")
      .insert([
        {
          transaction_id: transactionId,
          stove_serial_no: stoveSerialNo,
          sales_date: salesDate,
          contact_person: contactPerson,
          contact_phone: contactPhone,
          end_user_name: endUserName,
          aka,
          state_backup: stateBackup,
          lga_backup: lgaBackup,
          phone,
          other_phone: otherPhone,
          partner_name: partnerName,
          amount,
          signature,
          status: saleStatus,
          created_by: userId,
          organization_id: profile.organization_id,
          address_id: address.id,
          stove_image_id: stoveImageId,
          agreement_image_id: agreementImageId,
        },
      ])
      .select("id")
      .maybeSingle();
    if (saleError || !saleInsertData?.id) {
      console.error("❌ Sales insert failed:", saleError);
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "Sales save failed",
            error: saleError,
          }),
          {
            status: 500,
          }
        )
      );
    }
    const saleId = saleInsertData.id;
    // Log query params
    console.log("🔎 Attempting to update stove_ids:", {
      stove_id: stoveSerialNo,
      stove_id_type: typeof stoveSerialNo,
      stove_id_length: stoveSerialNo?.length,
      organization_id: profile.organization_id,
      organization_id_type: typeof profile.organization_id,
      organization_id_length: profile.organization_id?.length,
      sale_id: saleId,
    });
    // Log all stove_ids for this organization
    const { data: allStoves, error: allStovesError } = await supabase
      .from("stove_ids")
      .select("id, stove_id, organization_id, status, sale_id")
      .eq("organization_id", profile.organization_id);
    if (allStovesError) {
      console.error("❌ Error fetching all stove_ids for org:", allStovesError);
    } else {
      console.log("📋 All stove_ids for org:", allStoves);
    }
    // Log current state before update
    const { data: stoveBefore, error: stoveBeforeError } = await supabase
      .from("stove_ids")
      .select("id, stove_id, status, sale_id, organization_id")
      .eq("stove_id", stoveSerialNo)
      .eq("organization_id", profile.organization_id)
      .maybeSingle();
    if (stoveBeforeError) {
      console.error(
        "❌ Error fetching stove_ids before update:",
        stoveBeforeError
      );
    } else {
      console.log("🟡 stove_ids row before update:", stoveBefore);
    }
    // Perform update
    const {
      data: stoveUpdateData,
      error: stoveUpdateError,
      count: stoveUpdateCount,
    } = await supabase
      .from("stove_ids")
      .update({ status: "sold", sale_id: saleId })
      .eq("stove_id", stoveSerialNo)
      .eq("organization_id", profile.organization_id)
      .select("id, stove_id, status, sale_id, organization_id");
    if (stoveUpdateError) {
      console.error("❌ Failed to update stove_ids:", stoveUpdateError);
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "Failed to update stove_ids",
            error: stoveUpdateError,
          }),
          { status: 500 }
        )
      );
    }
    console.log("🟢 stove_ids update result:", stoveUpdateData);
    // Log state after update
    const { data: stoveAfter, error: stoveAfterError } = await supabase
      .from("stove_ids")
      .select("id, stove_id, status, sale_id, organization_id")
      .eq("stove_id", stoveSerialNo)
      .eq("organization_id", profile.organization_id)
      .maybeSingle();
    if (stoveAfterError) {
      console.error(
        "❌ Error fetching stove_ids after update:",
        stoveAfterError
      );
    } else {
      console.log("🟢 stove_ids row after update:", stoveAfter);
    }
    console.log("✅ Sales saved and stove_ids updated with sale_id:", saleId);
    return withCors(
      new Response(
        JSON.stringify({
          success: true,
          message: "Sales saved successfully",
          status: saleStatus,
          sale_id: saleId,
        }),
        {
          status: 200,
        }
      )
    );
  } catch (err) {
    console.error("🔥 Unexpected Error:", err);
    return withCors(
      new Response(
        JSON.stringify({
          success: false,
          message: "Unexpected error",
          err,
        }),
        {
          status: 500,
        }
      )
    );
  }
});

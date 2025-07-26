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
    const { error: saleError } = await supabase.from("sales").insert([
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
    ]);
    if (saleError) {
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
    console.log("✅ Sales saved successfully with status:", saleStatus);
    return withCors(
      new Response(
        JSON.stringify({
          success: true,
          message: "Sales saved successfully",
          status: saleStatus,
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

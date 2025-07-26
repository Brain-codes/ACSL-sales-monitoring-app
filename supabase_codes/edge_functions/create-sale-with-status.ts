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

// Function to determine sale status based on data completeness
function determineSaleStatus(
  saleData,
  hasStoveImage = false,
  hasAgreementImage = false
) {
  const requiredFields = [
    "transaction_id",
    "stove_serial_no",
    "sales_date",
    "contact_person",
    "contact_phone",
    "end_user_name",
    "phone",
    "partner_name",
    "amount",
  ];

  // Check if all required fields are present and not empty
  const hasAllRequiredFields = requiredFields.every((field) => {
    const value = saleData[field];
    return value !== null && value !== undefined && String(value).trim() !== "";
  });

  // Check if signature is present
  const hasSignature =
    saleData.signature && String(saleData.signature).trim() !== "";

  // Determine status based on completeness
  if (
    hasAllRequiredFields &&
    hasSignature &&
    hasStoveImage &&
    hasAgreementImage
  ) {
    return "completed";
  } else if (
    hasAllRequiredFields &&
    (hasSignature || hasStoveImage || hasAgreementImage)
  ) {
    return "pending";
  } else {
    return "incomplete";
  }
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
    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData?.user) {
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
    console.log("🔐 Authenticated user:", userId);

    // Get user profile for organization_id
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

    // Save address first
    console.log("🏡 Saving address...");
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

    // Prepare sale data
    const saleData = {
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
      created_by: userId,
      organization_id: profile.organization_id,
      address_id: address.id,
      stove_image_id: stoveImageId,
      agreement_image_id: agreementImageId,
    };

    // Determine status based on data completeness
    const hasStoveImage = stoveImageId !== null && stoveImageId !== undefined;
    const hasAgreementImage =
      agreementImageId !== null && agreementImageId !== undefined;
    const calculatedStatus = determineSaleStatus(
      saleData,
      hasStoveImage,
      hasAgreementImage
    );

    // Add status to sale data
    saleData.status = calculatedStatus;

    console.log("📝 Inserting sale with status:", calculatedStatus);

    // Insert sale
    const { error: saleError } = await supabase
      .from("sales")
      .insert([saleData]);

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

    console.log("✅ Sales saved successfully with status:", calculatedStatus);
    return withCors(
      new Response(
        JSON.stringify({
          success: true,
          message: "Sales saved successfully",
          status: calculatedStatus,
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

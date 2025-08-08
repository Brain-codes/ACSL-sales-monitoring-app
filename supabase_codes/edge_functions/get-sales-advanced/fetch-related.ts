// Related data fetcher module
import { Filters } from "./parse-filters.ts";

export async function fetchRelatedData(
  supabase: any,
  sales: any[],
  filters: Filters
) {
  console.log("🔗 Fetching related data...");

  if (!sales || sales.length === 0) {
    console.log("🔗 No sales data to process");
    return sales;
  }

  console.log(`🔗 Processing ${sales.length} sales records for related data`);

  // Fetch organizations separately if requested
  if (filters.includeOrganization) {
    await fetchOrganizations(supabase, sales);
  }

  // Fetch addresses separately if requested
  if (filters.includeAddress) {
    await fetchAddresses(supabase, sales);
  }

  // Fetch creators separately if requested
  if (filters.includeCreator) {
    await fetchCreators(supabase, sales);
  }

  // Fetch images separately if requested
  if (
    filters.includeImages ||
    filters.includeStoveImage ||
    filters.includeAgreementImage
  ) {
    await fetchImages(supabase, sales);
  }

  // Log results
  logRelatedDataResults(sales);

  return sales;
}

async function fetchOrganizations(supabase: any, sales: any[]) {
  console.log("🏢 Fetching organizations separately...");

  const orgIds = [
    ...new Set(
      sales
        .map((sale) => sale.organization_id)
        .filter((id) => id !== null && id !== undefined)
    ),
  ];

  console.log(`🏢 Found ${orgIds.length} unique organization IDs:`, orgIds);

  if (orgIds.length > 0) {
    const { data: organizations, error: orgsError } = await supabase
      .from("organizations")
      .select("id, name, created_at, partner_email")
      .in("id", orgIds);

    if (orgsError) {
      console.log("❌ Error fetching organizations:", orgsError);
    } else {
      console.log(
        `🏢 Successfully fetched ${organizations?.length || 0} organizations`
      );

      // Attach organizations to sales records
      sales.forEach((sale) => {
        if (sale.organization_id) {
          const foundOrg = organizations?.find(
            (org) => org.id === sale.organization_id
          );
          sale.organization = foundOrg || null;
          console.log(
            `🔍 Organization ${sale.organization_id}: ${
              foundOrg ? "FOUND" : "NOT FOUND"
            }`
          );
        }
      });
    }
  }
}

async function fetchAddresses(supabase: any, sales: any[]) {
  console.log("📍 Fetching addresses separately...");

  const addressIds = [
    ...new Set(
      sales
        .map((sale) => sale.address_id)
        .filter((id) => id !== null && id !== undefined)
    ),
  ];

  console.log(`📍 Found ${addressIds.length} unique address IDs:`, addressIds);

  console.log(
    `📍 CHECKING ${
      addressIds.length > 0
    } Attempting to fetch addresses with service role...`
  );
  if (addressIds.length > 0) {
    console.log("📍 Attempting to fetch addresses with service role...");
    const { data: addresses, error: addressError } = await supabase
      .from("addresses")
      .select(
        "id, city, state, street, country, latitude, longitude, full_address, created_at"
      )
      .in("id", addressIds);

    if (addressError) {
      console.log("❌ Error fetching addresses:", addressError);
      console.log(
        "❌ Full address error:",
        JSON.stringify(addressError, null, 2)
      );
    } else {
      console.log(
        `📍 Successfully fetched ${addresses?.length || 0} addresses`
      );
      console.log("📍 Address data:", addresses);

      // Attach addresses to sales records
      sales.forEach((sale) => {
        if (sale.address_id) {
          const foundAddr = addresses?.find(
            (addr) => addr.id === sale.address_id
          );
          sale.address = foundAddr || null;
          console.log(
            `🔍 Address ${sale.address_id}: ${
              foundAddr ? "FOUND" : "NOT FOUND"
            }`
          );
        }
      });
    }
  } else {
    console.log(
      `📍AFTER CHECKING ${addressIds.length > 0} IT LOOKS LIKE IT IS EMPTY`
    );
  }
}

async function fetchCreators(supabase: any, sales: any[]) {
  console.log("👤 Fetching creators separately...");

  const creatorIds = [
    ...new Set(
      sales
        .map((sale) => sale.created_by)
        .filter((id) => id !== null && id !== undefined)
    ),
  ];

  console.log(`👤 Found ${creatorIds.length} unique creator IDs:`, creatorIds);

  if (creatorIds.length > 0) {
    console.log("👤 Attempting to fetch creators with service role...");
    console.log("👤 Debug: Creator IDs to fetch:", JSON.stringify(creatorIds));

    // Test if we can access profiles table at all
    console.log("👤 Testing profiles table access...");
    const { data: testProfiles, error: testError } = await supabase
      .from("profiles")
      .select("id")
      .limit(1);

    if (testError) {
      console.log("❌ Cannot access profiles table:", testError);
    } else {
      console.log(
        `👤 Profiles table accessible, found ${
          testProfiles?.length || 0
        } test records`
      );
    }

    const { data: creators, error: creatorsError } = await supabase
      .from("profiles")
      .select("id, full_name, email, phone, role")
      .in("id", creatorIds);

    if (creatorsError) {
      console.log("❌ Error fetching creators:", creatorsError);
      console.log(
        "❌ Full creators error:",
        JSON.stringify(creatorsError, null, 2)
      );
    } else {
      console.log(`👤 Successfully fetched ${creators?.length || 0} creators`);
      console.log("👤 Creator data:", creators);

      // Check if the specific IDs exist in the table
      if (creators && creators.length === 0) {
        console.log("ℹ️ No creators found for the requested IDs - users may no longer exist");
        console.log("🔍 This is normal - sales may reference users who have been deleted");
        console.log("✅ Continuing with null creator values in response");
      } else if (creators && creators.length < creatorIds.length) {
        console.log(`ℹ️ Found ${creators.length} out of ${creatorIds.length} creators - some users may no longer exist`);
        const foundIds = creators.map(c => c.id);
        const missingIds = creatorIds.filter(id => !foundIds.includes(id));
        console.log("🔍 Missing creator IDs:", missingIds);
        console.log("✅ Continuing with partial creator data");
      }
      console.log("👤 Creator data:", creators);

      // Attach creators to sales records
      sales.forEach((sale) => {
        if (sale.created_by) {
          const foundCreator = creators?.find(
            (creator) => creator.id === sale.created_by
          );
          sale.creator = foundCreator || null;
          console.log(
            `🔍 Creator ${sale.created_by}: ${
              foundCreator ? "FOUND" : "NOT FOUND"
            }`
          );
        }
      });
    }
  }
}

async function fetchImages(supabase: any, sales: any[]) {
  console.log("🖼️ Fetching images separately...");

  // Collect all unique image IDs
  const stoveImageIds = sales
    .map((sale) => sale.stove_image_id)
    .filter((id) => id !== null && id !== undefined);
  const agreementImageIds = sales
    .map((sale) => sale.agreement_image_id)
    .filter((id) => id !== null && id !== undefined);
  const allImageIds = [...new Set([...stoveImageIds, ...agreementImageIds])];

  console.log(
    `🖼️ Found ${allImageIds.length} unique image IDs to fetch:`,
    allImageIds
  );

  if (allImageIds.length > 0) {
    const { data: images, error: imagesError } = await supabase
      .from("uploads")
      .select("id, public_id, url, type, created_by, created_at")
      .in("id", allImageIds);

    if (imagesError) {
      console.log("❌ Error fetching images:", imagesError);
    } else {
      console.log(`🖼️ Successfully fetched ${images?.length || 0} images`);

      // Attach images to sales records
      sales.forEach((sale) => {
        if (sale.stove_image_id) {
          const foundImage = images?.find(
            (img) => img.id === sale.stove_image_id
          );
          sale.stove_image = foundImage || null;
          console.log(
            `🔍 Stove image ${sale.stove_image_id}: ${
              foundImage ? "FOUND" : "NOT FOUND"
            }`
          );
        }
        if (sale.agreement_image_id) {
          const foundImage = images?.find(
            (img) => img.id === sale.agreement_image_id
          );
          sale.agreement_image = foundImage || null;
          console.log(
            `🔍 Agreement image ${sale.agreement_image_id}: ${
              foundImage ? "FOUND" : "NOT FOUND"
            }`
          );
        }
      });

      console.log("🖼️ Images attached to sales records");
    }
  } else {
    console.log("🖼️ No image IDs found in sales records");
  }
}

function logRelatedDataResults(sales: any[]) {
  if (sales.length === 0) return;

  const sampleSale = sales[0];
  console.log("🔗 Sample sale with related data:");
  console.log(
    `   - Has address: ${!!sampleSale.address} (ID: ${sampleSale.address_id})`
  );
  console.log(
    `   - Has creator: ${!!sampleSale.creator} (ID: ${sampleSale.created_by})`
  );
  console.log(
    `   - Has organization: ${!!sampleSale.organization} (ID: ${
      sampleSale.organization_id
    })`
  );
  console.log(
    `   - Has stove_image: ${!!sampleSale.stove_image} (ID: ${
      sampleSale.stove_image_id
    })`
  );
  console.log(
    `   - Has agreement_image: ${!!sampleSale.agreement_image} (ID: ${
      sampleSale.agreement_image_id
    })`
  );

  // Debug any remaining null relationships
  if (!sampleSale.address && sampleSale.address_id) {
    console.log(
      "❌ Address is null but address_id exists - check addresses table RLS policies"
    );
  }
  if (!sampleSale.creator && sampleSale.created_by) {
    console.log(
      "ℹ️ Creator is null but created_by exists - user may no longer exist in system"
    );
  }
  if (!sampleSale.organization && sampleSale.organization_id) {
    console.log(
      "❌ Organization is null but organization_id exists - check organizations table RLS policies"
    );
  }
}

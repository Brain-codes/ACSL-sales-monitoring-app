import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS, PUT, DELETE",
};
function withCors(response) {
  const headers = new Headers(response.headers);
  Object.entries(corsHeaders).forEach(([key, value]) => {
    headers.set(key, value);
  });
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}
serve(async (req) => {
  console.log("🚀 Edge function started");
  console.log("📥 Request method:", req.method);
  console.log("📥 Request URL:", req.url);
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    console.log("✅ CORS preflight request handled");
    return withCors(
      new Response("ok", {
        status: 200,
      })
    );
  }
  try {
    console.log("🔧 Initializing Supabase client...");
    // Initialize Supabase client
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: {
            Authorization: req.headers.get("Authorization") ?? "",
          },
        },
      }
    );
    console.log("✅ Supabase client initialized");
    console.log("🔐 Checking authentication...");
    // Authentication check
    const { data: userData, error: authError } = await supabase.auth.getUser();
    if (authError || !userData?.user) {
      console.log("❌ Authentication failed:", authError?.message);
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
    console.log("✅ User authenticated:", userData.user.email);
    console.log("👤 Fetching user profile...");
    // Check if user is super admin
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("role, organization_id")
      .eq("id", userData.user.id)
      .single();

    // Fallback: If profile fetch fails, check if user email is super admin
    let userRole: string | null = null;
    let userOrgId: string | null = null;

    if (profileError || !profile) {
      console.log("❌ Profile fetch failed:", profileError?.message);
      console.log("🔄 Trying email-based super admin check...");

      // Check if user email is the super admin email
      if (userData.user.email === "superadmin@mail.com") {
        console.log("✅ Super admin identified by email");
        userRole = "super_admin";
        userOrgId = null;
      } else {
        console.log("❌ Not super admin email, access denied");
        return withCors(
          new Response(
            JSON.stringify({
              success: false,
              message: "Profile not found and not super admin email",
            }),
            {
              status: 404,
            }
          )
        );
      }
    } else {
      console.log("✅ Profile fetched successfully");
      userRole = profile.role;
      userOrgId = profile.organization_id;
    }

    console.log(
      "✅ User role determined - Role:",
      userRole,
      "Org ID:",
      userOrgId
    );

    if (userRole !== "super_admin") {
      console.log("❌ Access denied - Role:", userRole);
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "Access denied. Super admin role required.",
          }),
          {
            status: 403,
          }
        )
      );
    }
    console.log("✅ Super admin access confirmed");
    console.log("📋 Parsing request filters...");
    // Parse request body for filters
    const filters =
      req.method === "POST"
        ? await req.json()
        : Object.fromEntries(new URL(req.url).searchParams.entries());
    console.log("✅ Filters parsed:", JSON.stringify(filters, null, 2));
    console.log("🧪 Running test query to check table access...");
    // Debug: Test simple query first with full access
    const { data: testData, error: testError } = await supabase
      .from("sales")
      .select("id, created_at, organization_id")
      .limit(5);
    console.log("🧪 Test query result:", testData);
    console.log("🧪 Test query error:", testError);
    if (testError) {
      console.log("❌ Test query failed - possible table access issue");
      console.log("❌ Test error details:", JSON.stringify(testError, null, 2));
    } else {
      console.log("✅ Test query successful - table accessible");
      console.log(
        `🧪 Sample data preview: ${testData?.length || 0} records found`
      );
      if (testData && testData.length > 0) {
        console.log(
          "🧪 First record sample:",
          JSON.stringify(testData[0], null, 2)
        );
      }
    }
    console.log("🔍 Building query with select fields...");
    // Build base query - construct select fields properly
    let selectFields = [
      "id",
      "transaction_id",
      "stove_serial_no",
      "sales_date",
      "contact_person",
      "contact_phone",
      "end_user_name",
      "aka",
      "state_backup",
      "lga_backup",
      "phone",
      "other_phone",
      "partner_name",
      "amount",
      "signature",
      "created_by",
      "organization_id",
      "address_id",
      "stove_image_id",
      "agreement_image_id",
      "created_at",
      "status",
    ];

    // For now, don't include related data in the main query to avoid RLS issues
    // We'll fetch related data separately after getting the sales records
    console.log(
      "📋 Using basic fields only, will fetch related data separately"
    );
    console.log("📋 Final select fields:", selectFields.join(", "));
    // Start with a fresh query using RLS bypass for super_admin
    console.log(
      "🔓 Creating query with super_admin privileges (bypassing RLS if needed)..."
    );
    let query = supabase.from("sales").select(selectFields.join(", "));
    // Super admin should see ALL sales regardless of organization
    console.log(
      "👑 Super admin detected - enabling access to all organizations"
    );
    console.log("📊 No organization filter will be applied for super_admin");
    console.log("🔧 Applying filters to query...");
    console.log("📊 Filters to apply:", JSON.stringify(filters, null, 2));
    // Apply date filters
    console.log("📅 Checking date filters...");
    if (filters.dateFrom || filters.dateTo) {
      console.log("📅 Applying sales date filters:", {
        dateFrom: filters.dateFrom,
        dateTo: filters.dateTo,
      });
      if (filters.dateFrom) {
        query = query.gte("sales_date", filters.dateFrom);
      }
      if (filters.dateTo) {
        query = query.lte("sales_date", filters.dateTo);
      }
    } else {
      console.log("📅 No sales date filters applied");
    }
    if (filters.createdFrom || filters.createdTo) {
      console.log("📅 Applying created_at filters:", {
        createdFrom: filters.createdFrom,
        createdTo: filters.createdTo,
      });
      if (filters.createdFrom) {
        query = query.gte("created_at", filters.createdFrom);
      }
      if (filters.createdTo) {
        query = query.lte("created_at", filters.createdTo);
      }
    } else {
      console.log("📅 No created_at filters applied");
    }
    // Apply quick date filters
    console.log("⚡ Checking quick date filters...");
    const now = new Date();
    if (filters.lastNDays) {
      console.log(`⚡ Applying lastNDays filter: ${filters.lastNDays} days`);
      const pastDate = new Date(
        now.getTime() - filters.lastNDays * 24 * 60 * 60 * 1000
      );
      query = query.gte("created_at", pastDate.toISOString());
    }
    if (filters.thisWeek) {
      console.log("⚡ Applying thisWeek filter");
      const startOfWeek = new Date(now.setDate(now.getDate() - now.getDay()));
      query = query.gte("created_at", startOfWeek.toISOString());
    }
    if (filters.thisMonth) {
      console.log("⚡ Applying thisMonth filter");
      const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
      query = query.gte("created_at", startOfMonth.toISOString());
    }
    if (filters.thisYear) {
      console.log("⚡ Applying thisYear filter");
      const startOfYear = new Date(now.getFullYear(), 0, 1);
      query = query.gte("created_at", startOfYear.toISOString());
    }
    if (
      !filters.lastNDays &&
      !filters.thisWeek &&
      !filters.thisMonth &&
      !filters.thisYear
    ) {
      console.log("⚡ No quick date filters applied");
    }
    // Apply location filters
    if (filters.state) {
      query = query.eq("state_backup", filters.state);
    }
    if (filters.states && filters.states.length > 0) {
      query = query.in("state_backup", filters.states);
    }
    if (filters.lga) {
      query = query.eq("lga_backup", filters.lga);
    }
    if (filters.lgas && filters.lgas.length > 0) {
      query = query.in("lga_backup", filters.lgas);
    }
    // Apply stove filters
    if (filters.stoveSerialNo) {
      query = query.eq("stove_serial_no", filters.stoveSerialNo);
    }
    if (filters.stoveSerialNos && filters.stoveSerialNos.length > 0) {
      query = query.in("stove_serial_no", filters.stoveSerialNos);
    }
    if (filters.stoveSerialNoPattern) {
      query = query.like(
        "stove_serial_no",
        `%${filters.stoveSerialNoPattern}%`
      );
    }
    // Apply people filters
    if (filters.contactPerson) {
      query = query.ilike("contact_person", `%${filters.contactPerson}%`);
    }
    if (filters.contactPhone) {
      query = query.eq("contact_phone", filters.contactPhone);
    }
    if (filters.endUserName) {
      query = query.ilike("end_user_name", `%${filters.endUserName}%`);
    }
    if (filters.aka) {
      query = query.ilike("aka", `%${filters.aka}%`);
    }
    if (filters.partnerName) {
      query = query.ilike("partner_name", `%${filters.partnerName}%`);
    }
    if (filters.createdBy) {
      query = query.eq("created_by", filters.createdBy);
    }
    if (filters.createdByIds && filters.createdByIds.length > 0) {
      query = query.in("created_by", filters.createdByIds);
    }
    // Apply amount filters
    if (filters.amountMin !== undefined) {
      query = query.gte("amount", filters.amountMin);
    }
    if (filters.amountMax !== undefined) {
      query = query.lte("amount", filters.amountMax);
    }
    if (filters.amountExact !== undefined) {
      query = query.eq("amount", filters.amountExact);
    }
    // Apply status filters
    if (filters.status) {
      query = query.eq("status", filters.status);
    }
    if (filters.statuses && filters.statuses.length > 0) {
      query = query.in("status", filters.statuses);
    }
    // Apply organization filters (except for super_admin who sees all)
    console.log("🏢 Checking organization filters...");
    if (userRole !== "super_admin") {
      console.log("👤 Non-super-admin user - applying organization filter");
      if (filters.organizationId) {
        console.log(
          `🏢 Filtering by specific organization: ${filters.organizationId}`
        );
        query = query.eq("organization_id", filters.organizationId);
      } else if (
        filters.organizationIds &&
        filters.organizationIds.length > 0
      ) {
        console.log(
          `🏢 Filtering by multiple organizations: ${filters.organizationIds.join(
            ", "
          )}`
        );
        query = query.in("organization_id", filters.organizationIds);
      } else if (userOrgId) {
        console.log(`🏢 Auto-filtering by user's organization: ${userOrgId}`);
        query = query.eq("organization_id", userOrgId);
      }
    } else {
      console.log(
        "👑 Super admin - no organization filter applied (sees all organizations)"
      );
      // Super admin can optionally filter by organization if specified
      if (filters.organizationId) {
        console.log(
          `🏢 Super admin choosing to filter by organization: ${filters.organizationId}`
        );
        query = query.eq("organization_id", filters.organizationId);
      } else if (
        filters.organizationIds &&
        filters.organizationIds.length > 0
      ) {
        console.log(
          `🏢 Super admin choosing to filter by organizations: ${filters.organizationIds.join(
            ", "
          )}`
        );
        query = query.in("organization_id", filters.organizationIds);
      }
    }
    // Apply phone filters
    if (filters.phone) {
      query = query.eq("phone", filters.phone);
    }
    if (filters.otherPhone) {
      query = query.eq("other_phone", filters.otherPhone);
    }
    // Apply boolean filters
    if (filters.hasStoveImage !== undefined) {
      if (filters.hasStoveImage) {
        query = query.not("stove_image_id", "is", null);
      } else {
        query = query.is("stove_image_id", null);
      }
    }
    if (filters.hasAgreementImage !== undefined) {
      if (filters.hasAgreementImage) {
        query = query.not("agreement_image_id", "is", null);
      } else {
        query = query.is("agreement_image_id", null);
      }
    }
    if (filters.hasSignature !== undefined) {
      if (filters.hasSignature) {
        query = query.not("signature", "is", null);
      } else {
        query = query.is("signature", null);
      }
    }
    // Apply general search
    if (filters.search) {
      const searchTerm = `%${filters.search}%`;
      query = query.or(
        `contact_person.ilike.${searchTerm},end_user_name.ilike.${searchTerm},aka.ilike.${searchTerm},phone.ilike.${searchTerm},other_phone.ilike.${searchTerm},stove_serial_no.ilike.${searchTerm},partner_name.ilike.${searchTerm},contact_phone.ilike.${searchTerm}`
      );
    }
    // Apply sorting
    console.log("🔄 Applying sorting...");
    const sortBy = filters.sortBy || "created_at";
    const sortOrder = filters.sortOrder || "desc";
    console.log(`🔄 Sort by: ${sortBy}, Order: ${sortOrder}`);
    if (filters.multiSort && filters.multiSort.length > 0) {
      console.log("🔄 Applying multi-sort:", filters.multiSort);
      filters.multiSort.forEach((sort) => {
        query = query.order(sort.field, {
          ascending: sort.order === "asc",
        });
      });
    } else {
      console.log(`🔄 Applying single sort: ${sortBy} ${sortOrder}`);
      query = query.order(sortBy, {
        ascending: sortOrder === "asc",
      });
    }
    // Apply pagination
    console.log("📄 Applying pagination...");
    const limit = Math.min(filters.limit || 100, 1000); // Max 1000 records
    const offset = filters.offset || ((filters.page || 1) - 1) * limit;
    console.log(
      `📄 Limit: ${limit}, Offset: ${offset}, Page: ${filters.page || 1}`
    );
    query = query.range(offset, offset + limit - 1);
    console.log("🚀 Executing main query...");
    // Execute query
    const { data: sales, error, count } = await query;
    console.log("📊 Main query completed!");
    console.log("📊 Sales data length:", sales?.length || 0);
    console.log("📊 Query error:", error);
    // Debug: Check if sales table has any data at all (bypass RLS for super admin)
    console.log("🔍 Checking total records in sales table (unfiltered)...");
    const { count: totalRecords } = await supabase.from("sales").select("*", {
      count: "exact",
      head: true,
    });
    console.log("📊 Total records in sales table:", totalRecords);
    console.log("📊 Query result count:", sales?.length || 0);
    // Additional debug: Check with service role to bypass RLS completely
    console.log("🔍 Performing admin-level count check...");
    try {
      const { data: adminCheck, error: adminError } = await supabase.rpc(
        "get_table_count",
        {
          table_name: "sales",
        }
      );
      if (adminCheck !== null && !adminError) {
        console.log("🔍 Admin count check result:", adminCheck);
      } else {
        console.log("🔍 Admin count check failed:", adminError?.message);
        // Fallback: Try manual count with different approach
        const { data: manualCount } = await supabase
          .from("sales")
          .select("id", {
            count: "exact",
            head: true,
          });
        console.log("🔍 Manual count fallback:", manualCount);
      }
    } catch (e) {
      console.log("🔍 Could not perform admin count check:", e);
    }
    if (error) {
      console.error("❌ Main query failed:", error);
      console.error("❌ Error details:", JSON.stringify(error, null, 2));
      return withCors(
        new Response(
          JSON.stringify({
            success: false,
            message: "Database query failed",
            error: error.message,
            errorDetails: error,
          }),
          {
            status: 500,
          }
        )
      );
    }
    console.log("✅ Main query successful!");
    // Debug: Let's check what RLS policies are affecting this
    console.log("🔒 Checking RLS impact...");
    if (sales?.length === 0 && totalRecords > 0) {
      console.log(
        "⚠️  POSSIBLE RLS ISSUE: Table has data but query returns 0 results"
      );
      console.log(
        "🔒 This suggests Row Level Security policies are blocking access"
      );
      console.log("💡 Check sales table RLS policies for super_admin role");
      // Try a query with specific organization filter to test RLS
      console.log("🧪 Testing RLS with organization filter...");
      if (userOrgId) {
        const { data: orgTest } = await supabase
          .from("sales")
          .select("id")
          .eq("organization_id", userOrgId)
          .limit(1);
        console.log(
          `🧪 Org-filtered test result: ${orgTest?.length || 0} records`
        );
      }
    }
    // Check if we should create sample data
    if (totalRecords === 0) {
      console.log("⚠️  No data found in sales table!");
      console.log("💡 Consider adding sample data for testing");
      // Let's also check what tables exist
      console.log("🔍 Checking available tables...");
      try {
        const { data: tables, error: tablesError } = await supabase
          .from("information_schema.tables")
          .select("table_name")
          .eq("table_schema", "public")
          .eq("table_type", "BASE TABLE");
        if (tables) {
          console.log(
            "📋 Available tables:",
            tables.map((t) => t.table_name)
          );
        } else {
          console.log("❌ Could not fetch table list:", tablesError);
        }
      } catch (e) {
        console.log("❌ Error checking tables:", e);
      }
    }
    // Fetch related data separately if requested
    console.log("🔗 Checking for related data to fetch...");
    if (sales && sales.length > 0) {
      console.log(
        `🔗 Processing ${sales.length} sales records for related data`
      );

      // Fetch organizations separately if requested
      if (filters.includeOrganization) {
        console.log("🏢 Fetching organizations separately...");
        const orgIds = [
          ...new Set(
            sales
              .map((sale) => sale.organization_id)
              .filter((id) => id !== null && id !== undefined)
          ),
        ];

        console.log(
          `🏢 Found ${orgIds.length} unique organization IDs:`,
          orgIds
        );

        if (orgIds.length > 0) {
          const { data: organizations, error: orgsError } = await supabase
            .from("organizations")
            .select("id, name, created_at, partner_email")
            .in("id", orgIds);

          if (orgsError) {
            console.log("❌ Error fetching organizations:", orgsError);
          } else {
            console.log(
              `🏢 Successfully fetched ${
                organizations?.length || 0
              } organizations`
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

      // Fetch addresses separately if requested
      if (filters.includeAddress) {
        console.log("📍 Fetching addresses separately...");
        const addressIds = [
          ...new Set(
            sales
              .map((sale) => sale.address_id)
              .filter((id) => id !== null && id !== undefined)
          ),
        ];

        console.log(
          `📍 Found ${addressIds.length} unique address IDs:`,
          addressIds
        );

        if (addressIds.length > 0) {
          const { data: addresses, error: addressError } = await supabase
            .from("addresses")
            .select(
              "id, city, state, street, country, latitude, longitude, full_address, created_at"
            )
            .in("id", addressIds);

          if (addressError) {
            console.log("❌ Error fetching addresses:", addressError);
          } else {
            console.log(
              `📍 Successfully fetched ${addresses?.length || 0} addresses`
            );

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
        }
      }

      // Fetch creators separately if requested
      if (filters.includeCreator) {
        console.log("👤 Fetching creators separately...");
        const creatorIds = [
          ...new Set(
            sales
              .map((sale) => sale.created_by)
              .filter((id) => id !== null && id !== undefined)
          ),
        ];

        console.log(
          `👤 Found ${creatorIds.length} unique creator IDs:`,
          creatorIds
        );

        if (creatorIds.length > 0) {
          const { data: creators, error: creatorsError } = await supabase
            .from("profiles")
            .select("id, full_name, email, phone, role")
            .in("id", creatorIds);

          if (creatorsError) {
            console.log("❌ Error fetching creators:", creatorsError);
          } else {
            console.log(
              `👤 Successfully fetched ${creators?.length || 0} creators`
            );

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

      // Fetch images separately if requested
      if (filters.includeImages) {
        console.log("🖼️ Fetching images separately...");

        // Collect all unique image IDs
        const stoveImageIds = sales
          .map((sale) => sale.stove_image_id)
          .filter((id) => id !== null && id !== undefined);
        const agreementImageIds = sales
          .map((sale) => sale.agreement_image_id)
          .filter((id) => id !== null && id !== undefined);
        const allImageIds = [
          ...new Set([...stoveImageIds, ...agreementImageIds]),
        ];

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
            console.log(
              `🖼️ Successfully fetched ${images?.length || 0} images:`,
              images
            );

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

      // Fetch sales history if requested (this needs separate query)
      if (filters.includeSalesHistory) {
        console.log("� Fetching sales history...");
        const salesIds = sales.map((sale) => sale.id);
        const { data: salesHistory } = await supabase
          .from("sales_history")
          .select("*")
          .in("sale_id", salesIds);
        console.log(`� Fetched ${salesHistory?.length || 0} history records`);
        if (salesHistory) {
          sales.forEach((sale) => {
            sale.sales_history = salesHistory.filter(
              (history) => history.sale_id === sale.id
            );
          });
          console.log("� Sales history attached to records");
        }
      }
      // Log what related data was included
      const sampleSale = sales[0];
      console.log("🔗 Sample sale with related data:");
      console.log(
        `   - Has address: ${!!sampleSale.address} (ID: ${
          sampleSale.address_id
        })`
      );
      console.log(
        `   - Has creator: ${!!sampleSale.creator} (ID: ${
          sampleSale.created_by
        })`
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
          "❌ Creator is null but created_by exists - check profiles table RLS policies"
        );
      }
      if (!sampleSale.organization && sampleSale.organization_id) {
        console.log(
          "❌ Organization is null but organization_id exists - check organizations table RLS policies"
        );
      }
    } else {
      console.log("🔗 No sales data to process for related data");
    }
    // Handle export formats
    console.log("📤 Checking export format...");
    if (filters.export && sales) {
      console.log(`📤 Export requested: ${filters.export}`);
      console.log(
        `📤 Export fields requested: ${
          filters.exportFields ? filters.exportFields.join(", ") : "all fields"
        }`
      );
      const exportData = filters.exportFields
        ? sales.map((sale) => {
            const filtered = {};
            filters.exportFields.forEach((field) => {
              if (sale[field] !== undefined) {
                filtered[field] = sale[field];
              }
            });
            return filtered;
          })
        : sales;
      console.log(`📤 Prepared ${exportData.length} records for export`);
      if (filters.export === "csv") {
        console.log("📤 Converting to CSV...");
        const csv = convertToCSV(exportData);
        console.log(
          `📤 CSV generated with ${csv.split("\n").length - 1} data rows`
        );
        return withCors(
          new Response(csv, {
            status: 200,
            headers: {
              "Content-Type": "text/csv",
              "Content-Disposition": "attachment; filename=sales-export.csv",
            },
          })
        );
      }
    } else if (filters.export) {
      console.log("📤 Export requested but no sales data available");
    }
    // Get total count for pagination info
    console.log("📊 Getting total count for pagination...");
    const { count: totalCount } = await supabase.from("sales").select("*", {
      count: "exact",
      head: true,
    });
    // Prepare response
    console.log("📋 Preparing final response...");
    const response = {
      success: true,
      data: sales,
      pagination: {
        page: filters.page || 1,
        limit,
        offset,
        total: totalCount || 0,
        totalPages: Math.ceil((totalCount || 0) / limit),
      },
      filters: filters,
      timestamp: new Date().toISOString(),
      debug: {
        totalRecordsInTable: totalRecords,
        queryResultCount: sales?.length || 0,
        selectFields: selectFields.join(", "),
        userRole: userRole,
        userId: userData.user.id,
      },
    };
    console.log("📋 Final response summary:");
    console.log(`   - Success: ${response.success}`);
    console.log(`   - Records returned: ${response.debug.queryResultCount}`);
    console.log(
      `   - Total records in table: ${response.debug.totalRecordsInTable}`
    );
    console.log(`   - User role: ${response.debug.userRole}`);
    console.log(`   - Current page: ${response.pagination.page}`);
    console.log(`   - Total pages: ${response.pagination.totalPages}`);
    console.log(`   - Filters object keys: ${Object.keys(filters).join(", ")}`);
    // Add helpful suggestion if table is empty
    if (totalRecords === 0) {
      console.log("💡 SUGGESTION: Sales table is empty. Consider:");
      console.log("   1. Adding sample data through the Flutter app");
      console.log("   2. Importing existing sales data");
      console.log("   3. Creating test sales records");
      console.log(
        "   4. Checking if sales are being saved to a different table"
      );
    }
    return withCors(
      new Response(JSON.stringify(response), {
        status: 200,
        headers: {
          "Content-Type": "application/json",
        },
      })
    );
  } catch (error) {
    console.error("Edge function error:", error);
    return withCors(
      new Response(
        JSON.stringify({
          success: false,
          message: "Internal server error",
          error: error.message,
        }),
        {
          status: 500,
        }
      )
    );
  }
});
// Helper function to convert data to CSV
function convertToCSV(data) {
  if (!data || data.length === 0) return "";
  const headers = Object.keys(data[0]);
  const csvContent = [
    headers.join(","),
    ...data.map((row) =>
      headers
        .map((header) => {
          const value = row[header];
          if (value === null || value === undefined) return "";
          if (typeof value === "string" && value.includes(",")) {
            return `"${value.replace(/"/g, '""')}"`;
          }
          return String(value);
        })
        .join(",")
    ),
  ].join("\n");
  return csvContent;
}

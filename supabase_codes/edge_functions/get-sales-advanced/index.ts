import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { withCors } from "./cors.ts";
import { authenticateUser } from "./authenticate.ts";
import { parseFilters } from "./parse-filters.ts";
import { buildQuery } from "./build-query.ts";
import { fetchRelatedData } from "./fetch-related.ts";
import { convertToCSV, prepareExportData } from "./export.ts";

serve(async (req) => {
  console.log("🚀 Sales API started");
  console.log("📥 Request:", req.method, req.url);

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    console.log("✅ CORS preflight handled");
    return withCors(new Response("ok", { status: 200 }));
  }

  try {
    // Initialize Supabase client
    console.log("🔧 Initializing Supabase...");
    const authHeader = req.headers.get("Authorization");
    console.log("🔑 Auth header present:", !!authHeader);
    console.log(
      "🔑 Auth header preview:",
      authHeader ? authHeader.substring(0, 20) + "..." : "None"
    );

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      {
        global: {
          headers: {
            Authorization: authHeader ?? "",
          },
        },
      }
    );

    // Authenticate user
    console.log("🔐 Authenticating user...");
    const { userRole, userId, userOrgId } = await authenticateUser(supabase);
    console.log(`✅ Authenticated as: ${userRole}`);

    // Parse request filters
    console.log("📋 Parsing filters...");
    const filters = await parseFilters(req);
    console.log(`✅ Parsed ${Object.keys(filters).length} filters`);

    // Build and execute main query
    console.log("🔍 Building query...");
    const { sales, totalRecords } = await buildQuery(
      supabase,
      filters,
      userRole,
      userOrgId
    );
    console.log(`✅ Found ${sales?.length || 0} sales records`);

    // Fetch related data if requested
    if (sales && sales.length > 0) {
      console.log("🔗 Fetching related data...");
      await fetchRelatedData(supabase, sales, filters);
      console.log("✅ Related data attached");
    }

    // Handle export if requested
    if (filters.export && sales) {
      console.log("📤 Handling export...");
      const exportData = prepareExportData(sales, filters);

      if (filters.export === "csv") {
        console.log("📤 Converting to CSV...");
        const csv = convertToCSV(exportData);
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
    }

    // Prepare response
    const limit = Math.min(filters.limit || 100, 1000);
    const response = {
      success: true,
      data: sales,
      pagination: {
        page: filters.page || 1,
        limit,
        offset: filters.offset || ((filters.page || 1) - 1) * limit,
        total: totalRecords || 0,
        totalPages: Math.ceil((totalRecords || 0) / limit),
      },
      filters: filters,
      timestamp: new Date().toISOString(),
      debug: {
        totalRecordsInTable: totalRecords,
        queryResultCount: sales?.length || 0,
        userRole,
        userId,
      },
    };

    console.log("📋 Response ready:", {
      success: response.success,
      records: response.debug.queryResultCount,
      total: response.debug.totalRecordsInTable,
      role: response.debug.userRole,
    });

    return withCors(
      new Response(JSON.stringify(response), {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "Cache-Control": "no-cache, no-store, must-revalidate",
          Pragma: "no-cache",
          Expires: "0",
        },
      })
    );
  } catch (error) {
    console.error("❌ Edge function error:", error);
    return withCors(
      new Response(
        JSON.stringify({
          success: false,
          message: "Internal server error",
          error: error.message,
        }),
        { status: 500 }
      )
    );
  }
});

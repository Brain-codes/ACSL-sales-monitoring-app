// Read operations for agents

export async function getAgents(
  supabase: any,
  searchParams: URLSearchParams,
  userRole: string,
  organizationId: string | null
) {
  console.log("📋 Fetching agents list...");

  try {
    // Parse pagination parameters
    const page = parseInt(searchParams.get("page") || "1");
    const limit = Math.min(parseInt(searchParams.get("limit") || "10"), 100);
    const offset = (page - 1) * limit;

    // Parse search parameters
    const search = searchParams.get("search") || "";
    const sortBy = searchParams.get("sortBy") || "created_at";
    const sortOrder = searchParams.get("sortOrder") || "desc";

    console.log("📊 Query parameters:", {
      page,
      limit,
      search,
      sortBy,
      sortOrder,
    });

    // Build base query
    let query = supabase
      .from("profiles")
      .select(
        "id, full_name, email, phone, role, organization_id, created_at",
        { count: "exact" }
      )
      .eq("role", "agent");

    // Apply organization filter based on user role
    if (userRole === "admin" && organizationId) {
      // Admin can only see agents from their organization
      query = query.eq("organization_id", organizationId);
      console.log("🔍 Admin access: filtering by organization", organizationId);
    } else if (userRole === "super_admin") {
      // Super admin can see all agents
      console.log("🔍 Super admin access: showing all agents");
    } else if (userRole === "admin" && !organizationId) {
      // Admin has no organization assigned
      console.log("❌ Admin has no organization assigned");
      throw new Error("Admin user has no organization assigned");
    } else {
      throw new Error("Insufficient permissions to view agents");
    }

    // Apply search filter
    if (search.trim()) {
      query = query.or(`full_name.ilike.%${search}%,email.ilike.%${search}%`);
      console.log("🔍 Search filter applied:", search);
    }

    // Apply sorting
    const ascending = sortOrder.toLowerCase() === "asc";
    query = query.order(sortBy, { ascending });

    // Apply pagination
    query = query.range(offset, offset + limit - 1);

    // Execute query
    const { data: agents, error: agentsError, count } = await query;

    if (agentsError) {
      console.error("❌ Error fetching agents:", agentsError);
      throw new Error(`Database error: ${agentsError.message}`);
    }

    // Calculate pagination metadata
    const totalPages = Math.ceil((count || 0) / limit);
    const hasNextPage = page < totalPages;
    const hasPrevPage = page > 1;

    console.log(`✅ Found ${agents?.length || 0} agents (${count} total)`);

    return {
      message: `Found ${count || 0} agents`,
      data: agents || [],
      pagination: {
        currentPage: page,
        totalPages,
        totalItems: count || 0,
        itemsPerPage: limit,
        hasNextPage,
        hasPrevPage,
      },
      filters: {
        search,
        sortBy,
        sortOrder,
      },
    };
  } catch (error) {
    console.error("❌ Error in getAgents:", error);
    throw error;
  }
}

export async function getAgent(
  supabase: any,
  agentId: string,
  userRole: string,
  organizationId: string | null
) {
  console.log("🔍 Fetching single agent:", agentId);

  try {
    // Build query for single agent
    let query = supabase
      .from("profiles")
      .select("id, full_name, email, phone, role, organization_id, created_at")
      .eq("id", agentId)
      .eq("role", "agent");

    // Apply organization filter based on user role
    if (userRole === "admin" && organizationId) {
      // Admin can only see agents from their organization
      query = query.eq("organization_id", organizationId);
      console.log("🔍 Admin access: filtering by organization", organizationId);
    } else if (userRole === "super_admin") {
      // Super admin can see any agent
      console.log("🔍 Super admin access: no organization filter");
    } else if (userRole === "admin" && !organizationId) {
      // Admin has no organization assigned
      console.log("❌ Admin has no organization assigned");
      throw new Error("Admin user has no organization assigned");
    } else {
      throw new Error("Insufficient permissions to view agent");
    }

    const { data: agent, error: agentError } = await query.single();

    if (agentError) {
      if (agentError.code === "PGRST116") {
        throw new Error("Agent not found or access denied");
      }
      console.error("❌ Error fetching agent:", agentError);
      throw new Error(`Database error: ${agentError.message}`);
    }

    console.log("✅ Agent found:", agent.id);

    return {
      message: "Agent retrieved successfully",
      data: agent,
    };
  } catch (error) {
    console.error("❌ Error in getAgent:", error);
    throw error;
  }
}

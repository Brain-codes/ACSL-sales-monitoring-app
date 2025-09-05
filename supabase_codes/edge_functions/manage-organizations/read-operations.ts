// CRUD operations for organizations

// Read operations for organizations with admin user information

export async function getOrganization(supabase: any, organizationId: string) {
  console.log(`🔍 Getting organization with admin user: ${organizationId}`);

  // First get the organization
  const { data: organization, error } = await supabase
    .from("organizations")
    .select(
      `
      id,
      name,
      partner_email,
      contact_phone,
      address,
      city,
      state,
      country,
      description,
      status,
      created_at,
      updated_at,
      created_by
    `
    )
    .eq("id", organizationId)
    .single();

  if (error) {
    if (error.code === "PGRST116") {
      throw new Error(`Organization with ID ${organizationId} not found`);
    }
    throw new Error(`Failed to fetch organization: ${error.message}`);
  }

  // Get the admin user for this organization
  let adminUser = null;
  try {
    const { data: admin, error: adminError } = await supabase
      .from("profiles")
      .select(
        `
        id,
        email,
        full_name,
        phone,
        role,
        has_changed_password,
        created_at
      `
      )
      .eq("organization_id", organizationId)
      .eq("role", "admin")
      .limit(1)
      .single();

    if (!adminError && admin) {
      adminUser = admin;
    }
  } catch (adminError) {
    console.warn("Could not fetch admin user:", adminError);
  }

  return {
    data: {
      organization,
      admin_user: adminUser,
    },
    message: "Organization retrieved successfully",
  };
}

export async function getOrganizations(
  supabase: any,
  searchParams: URLSearchParams
) {
  console.log("🔍 Getting all organizations with admin users...");

  const limit = Math.min(parseInt(searchParams.get("limit") || "50"), 100);
  const offset = parseInt(searchParams.get("offset") || "0");
  const search = searchParams.get("search");
  const status = searchParams.get("status");
  const sortBy = searchParams.get("sortBy") || "created_at";
  const sortOrder = searchParams.get("sortOrder") || "desc";
  const includeAdminUsers = searchParams.get("include_admin_users") !== "false"; // Default to true

  let query = supabase.from("organizations").select(
    `
      id,
      name,
      partner_email,
      contact_phone,
      address,
      city,
      state,
      country,
      description,
      status,
      created_at,
      updated_at,
      created_by
    `,
    { count: "exact" }
  );

  // Apply filters
  if (search) {
    query = query.or(
      `name.ilike.%${search}%,partner_email.ilike.%${search}%,city.ilike.%${search}%`
    );
  }

  if (status) {
    query = query.eq("status", status);
  }

  // Apply sorting and pagination
  query = query
    .order(sortBy, { ascending: sortOrder === "asc" })
    .range(offset, offset + limit - 1);

  const { data: organizations, error, count } = await query;

  if (error) {
    throw new Error(`Failed to fetch organizations: ${error.message}`);
  }

  // If requested, fetch admin users for each organization
  let organizationsWithAdmins = organizations;

  if (includeAdminUsers && organizations && organizations.length > 0) {
    console.log("📋 Fetching admin users for organizations...");

    try {
      // Get all admin users for these organizations in one query
      const orgIds = organizations.map((org: any) => org.id);

      const { data: adminUsers, error: adminError } = await supabase
        .from("profiles")
        .select(
          `
          id,
          email,
          full_name,
          phone,
          role,
          has_changed_password,
          created_at,
          organization_id
        `
        )
        .in("organization_id", orgIds)
        .eq("role", "admin");

      if (!adminError && adminUsers) {
        // Create a map of organization_id -> admin_user
        const adminMap = new Map();
        adminUsers.forEach((admin: any) => {
          adminMap.set(admin.organization_id, admin);
        });

        // Add admin user data to each organization
        organizationsWithAdmins = organizations.map((org: any) => ({
          ...org,
          admin_user: adminMap.get(org.id) || null,
        }));
      } else {
        console.warn("Could not fetch admin users:", adminError);
        // Still return organizations without admin data if admin fetch fails
        organizationsWithAdmins = organizations.map((org: any) => ({
          ...org,
          admin_user: null,
        }));
      }
    } catch (adminFetchError) {
      console.error("Error fetching admin users:", adminFetchError);
      // Return organizations without admin data if there's an error
      organizationsWithAdmins = organizations.map((org: any) => ({
        ...org,
        admin_user: null,
      }));
    }
  }

  return {
    data: organizationsWithAdmins,
    pagination: {
      limit,
      offset,
      total: count || 0,
      totalPages: Math.ceil((count || 0) / limit),
    },
    message: `Retrieved ${organizationsWithAdmins?.length || 0} organizations${
      includeAdminUsers ? " with admin user data" : ""
    }`,
  };
}

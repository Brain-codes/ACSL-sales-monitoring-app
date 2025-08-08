// Query building module
import { Filters } from "./parse-filters.ts";

export interface QueryResult {
  sales: any[] | null;
  totalRecords: number | null;
}

export async function buildQuery(
  supabase: any,
  filters: Filters,
  userRole: string,
  userOrgId: string | null
): Promise<QueryResult> {
  console.log("🔍 Building sales query...");

  // Test basic table access first
  console.log("🧪 Testing table access...");
  const { data: testData, error: testError } = await supabase
    .from("sales")
    .select("id, created_at, organization_id")
    .limit(3);

  if (testError) {
    console.log("❌ Table access test failed:", testError.message);
    console.log("❌ Full error details:", JSON.stringify(testError, null, 2));
    throw new Error(`Table access failed: ${testError.message}`);
  }

  console.log(
    `✅ Table accessible, found ${testData?.length || 0} test records`
  );

  // Build select fields - basic fields only, related data fetched separately
  const selectFields = [
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

  console.log("📋 Using basic fields only, related data fetched separately");

  // Start building query
  let query = supabase.from("sales").select(selectFields.join(", "));

  // Apply filters
  query = applyDateFilters(query, filters);
  query = applyLocationFilters(query, filters);
  query = applyStoveFilters(query, filters);
  query = applyPeopleFilters(query, filters);
  query = applyAmountFilters(query, filters);
  query = applyStatusFilters(query, filters);
  query = applyOrganizationFilters(query, filters, userRole, userOrgId);
  query = applyBooleanFilters(query, filters);
  query = applySearchFilter(query, filters);
  query = applySorting(query, filters);
  query = applyPagination(query, filters);

  console.log("🚀 Executing main query...");

  // Execute query
  const { data: sales, error } = await query;

  if (error) {
    console.error("❌ Main query failed:", error.message);
    throw new Error(`Database query failed: ${error.message}`);
  }

  console.log(`✅ Query successful: ${sales?.length || 0} records`);

  // Get total count
  console.log("📊 Getting total count...");
  const { count: totalRecords } = await supabase
    .from("sales")
    .select("*", { count: "exact", head: true });

  console.log(`📊 Total records in table: ${totalRecords}`);

  return { sales, totalRecords };
}

function applyDateFilters(query: any, filters: Filters) {
  console.log("📅 Applying date filters...");

  // Sales date filters
  if (filters.dateFrom) query = query.gte("sales_date", filters.dateFrom);
  if (filters.dateTo) query = query.lte("sales_date", filters.dateTo);

  // Created date filters
  if (filters.createdFrom) query = query.gte("created_at", filters.createdFrom);
  if (filters.createdTo) query = query.lte("created_at", filters.createdTo);

  // Quick date filters
  const now = new Date();
  if (filters.lastNDays) {
    const pastDate = new Date(
      now.getTime() - filters.lastNDays * 24 * 60 * 60 * 1000
    );
    query = query.gte("created_at", pastDate.toISOString());
  }
  if (filters.thisWeek) {
    const startOfWeek = new Date(now.setDate(now.getDate() - now.getDay()));
    query = query.gte("created_at", startOfWeek.toISOString());
  }
  if (filters.thisMonth) {
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    query = query.gte("created_at", startOfMonth.toISOString());
  }
  if (filters.thisYear) {
    const startOfYear = new Date(now.getFullYear(), 0, 1);
    query = query.gte("created_at", startOfYear.toISOString());
  }

  return query;
}

function applyLocationFilters(query: any, filters: Filters) {
  if (filters.state) query = query.eq("state_backup", filters.state);
  if (filters.states?.length) query = query.in("state_backup", filters.states);
  if (filters.lga) query = query.eq("lga_backup", filters.lga);
  if (filters.lgas?.length) query = query.in("lga_backup", filters.lgas);
  return query;
}

function applyStoveFilters(query: any, filters: Filters) {
  if (filters.stoveSerialNo)
    query = query.eq("stove_serial_no", filters.stoveSerialNo);
  if (filters.stoveSerialNos?.length)
    query = query.in("stove_serial_no", filters.stoveSerialNos);
  if (filters.stoveSerialNoPattern) {
    query = query.like("stove_serial_no", `%${filters.stoveSerialNoPattern}%`);
  }
  return query;
}

function applyPeopleFilters(query: any, filters: Filters) {
  if (filters.contactPerson)
    query = query.ilike("contact_person", `%${filters.contactPerson}%`);
  if (filters.contactPhone)
    query = query.eq("contact_phone", filters.contactPhone);
  if (filters.endUserName)
    query = query.ilike("end_user_name", `%${filters.endUserName}%`);
  if (filters.aka) query = query.ilike("aka", `%${filters.aka}%`);
  if (filters.partnerName)
    query = query.ilike("partner_name", `%${filters.partnerName}%`);
  if (filters.createdBy) query = query.eq("created_by", filters.createdBy);
  if (filters.createdByIds?.length)
    query = query.in("created_by", filters.createdByIds);
  if (filters.phone) query = query.eq("phone", filters.phone);
  if (filters.otherPhone) query = query.eq("other_phone", filters.otherPhone);
  return query;
}

function applyAmountFilters(query: any, filters: Filters) {
  if (filters.amountMin !== undefined)
    query = query.gte("amount", filters.amountMin);
  if (filters.amountMax !== undefined)
    query = query.lte("amount", filters.amountMax);
  if (filters.amountExact !== undefined)
    query = query.eq("amount", filters.amountExact);
  return query;
}

function applyStatusFilters(query: any, filters: Filters) {
  if (filters.status) query = query.eq("status", filters.status);
  if (filters.statuses?.length) query = query.in("status", filters.statuses);
  return query;
}

function applyOrganizationFilters(
  query: any,
  filters: Filters,
  userRole: string,
  userOrgId: string | null
) {
  console.log("🏢 Applying organization filters...");

  if (userRole !== "super_admin") {
    console.log("👤 Non-super-admin: applying org restrictions");
    if (filters.organizationId) {
      query = query.eq("organization_id", filters.organizationId);
    } else if (filters.organizationIds?.length) {
      query = query.in("organization_id", filters.organizationIds);
    } else if (userOrgId) {
      query = query.eq("organization_id", userOrgId);
    }
  } else {
    console.log("👑 Super admin: optional org filtering");
    if (filters.organizationId) {
      query = query.eq("organization_id", filters.organizationId);
    } else if (filters.organizationIds?.length) {
      query = query.in("organization_id", filters.organizationIds);
    }
  }

  return query;
}

function applyBooleanFilters(query: any, filters: Filters) {
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
  return query;
}

function applySearchFilter(query: any, filters: Filters) {
  if (filters.search) {
    const searchTerm = `%${filters.search}%`;
    query = query.or(
      `contact_person.ilike.${searchTerm},end_user_name.ilike.${searchTerm},aka.ilike.${searchTerm},phone.ilike.${searchTerm},other_phone.ilike.${searchTerm},stove_serial_no.ilike.${searchTerm},partner_name.ilike.${searchTerm},contact_phone.ilike.${searchTerm}`
    );
  }
  return query;
}

function applySorting(query: any, filters: Filters) {
  console.log("🔄 Applying sorting...");

  const sortBy = filters.sortBy || "created_at";
  const sortOrder = filters.sortOrder || "desc";

  if (filters.multiSort?.length) {
    filters.multiSort.forEach((sort) => {
      query = query.order(sort.field, { ascending: sort.order === "asc" });
    });
  } else {
    query = query.order(sortBy, { ascending: sortOrder === "asc" });
  }

  return query;
}

function applyPagination(query: any, filters: Filters) {
  console.log("📄 Applying pagination...");

  const limit = Math.min(filters.limit || 100, 1000);
  const offset = filters.offset || ((filters.page || 1) - 1) * limit;

  console.log(`📄 Limit: ${limit}, Offset: ${offset}`);

  return query.range(offset, offset + limit - 1);
}

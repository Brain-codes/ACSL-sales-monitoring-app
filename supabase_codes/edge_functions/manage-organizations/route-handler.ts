// Route handler for organization operations

import { getOrganization, getOrganizations } from "./read-operations.ts";
import { createOrganization, updateOrganization } from "./write-operations.ts";
import {
  deleteOrganization,
  hardDeleteOrganization,
} from "./delete-operations.ts";

export async function handleOrganizationRoute(
  req: Request,
  supabase: any,
  userId: string,
  userRole: string
) {
  // Parse URL to get organization ID if present
  const url = new URL(req.url);
  const pathParts = url.pathname.split("/").filter(Boolean);
  const organizationId = pathParts[pathParts.length - 1];

  // Check for hard delete query parameter
  const isHardDelete = url.searchParams.get("hard_delete") === "true";

  // Route to appropriate CRUD operation
  const method = req.method.toUpperCase();

  switch (method) {
    case "GET":
      if (organizationId && organizationId !== "manage-organizations") {
        // Get single organization
        return await getOrganization(supabase, organizationId);
      } else {
        // Get all organizations with pagination
        return await getOrganizations(supabase, url.searchParams);
      }

    case "POST":
      // Create new organization with admin user
      const createData = await req.json();
      return await createOrganization(supabase, createData, userId);

    case "PUT":
    case "PATCH":
      // Update organization and/or admin user
      if (!organizationId || organizationId === "manage-organizations") {
        throw new Error("Organization ID is required for update operations");
      }
      const updateData = await req.json();
      return await updateOrganization(
        supabase,
        organizationId,
        updateData,
        userId
      );

    case "DELETE":
      // Delete organization (soft delete by default, hard delete with query param)
      if (!organizationId || organizationId === "manage-organizations") {
        throw new Error("Organization ID is required for delete operation");
      }

      if (isHardDelete) {
        console.warn("⚠️ Hard delete requested - this is irreversible!");
        return await hardDeleteOrganization(supabase, organizationId);
      } else {
        return await deleteOrganization(supabase, organizationId);
      }

    default:
      throw new Error(`Method ${method} not allowed`);
  }
}

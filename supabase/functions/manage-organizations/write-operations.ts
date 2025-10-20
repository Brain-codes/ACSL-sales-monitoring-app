// Create and update operations for organizations with integrated user management
import { validateOrganizationData } from "./validate.ts";
import {
  createUserInAuth,
  generateSecurePassword,
  sendWelcomeEmail,
  updateUserInAuth,
  findOrganizationAdmin,
} from "./user-utils.ts";

export async function createOrganization(
  supabase: any,
  data: any,
  userId: string
) {
  console.log("➕ Creating new organization with admin user...");

  // Auto-generate admin user details from partner data
  data.admin_email =
    data.email ||
    `${data.partner_name.toLowerCase().replace(/\s+/g, "")}@admin.com`; // Use provided email or generate from partner name
  data.admin_full_name = `${data.partner_name} Admin`; // Use partner name + "Admin"

  console.log(`👤 Generated admin email: ${data.admin_email}`);
  console.log(`👤 Generated admin name: ${data.admin_full_name}`);

  // Validate required fields
  const validation = validateOrganizationData(data, "create");
  if (!validation.isValid) {
    throw new Error(`Validation failed: ${validation.errors.join(", ")}`);
  }

  // Check if admin email already exists in auth
  const { data: existingUser, error: userCheckError } =
    await supabase.auth.admin.listUsers();

  if (userCheckError) {
    console.warn("Could not check existing users:", userCheckError.message);
  } else {
    const emailExists = existingUser.users.some(
      (user: any) => user.email === data.admin_email
    );
    if (emailExists) {
      throw new Error(`User with email "${data.admin_email}" already exists`);
    }
  }

  // Start the creation process
  let organizationId: string;
  let adminUser: any;
  let generatedPassword: string;
  let newOrganization: any;

  try {
    // Step 1: Generate organization ID and create organization FIRST
    organizationId = crypto.randomUUID();

    const organizationData = {
      id: organizationId,
      partner_name: data.partner_name, // Required - Partner name
      branch: data.branch, // Required - Branch
      state: data.state, // Required - State
      contact_person: data.contact_person || null, // Optional - Contact person
      contact_phone: data.contact_phone || null, // Optional - Contact phone
      alternative_phone: data.alternative_phone || null, // Optional - Alternative phone
      email: data.email || null, // Optional - Email
      address: data.address || null, // Optional - Address
      created_by: userId,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    const { data: orgResult, error: orgError } = await supabase
      .from("organizations")
      .insert([organizationData])
      .select()
      .single();

    if (orgError) {
      throw new Error(`Failed to create organization: ${orgError.message}`);
    }

    newOrganization = orgResult;
    console.log("✅ Organization created successfully");

    // Step 2: Generate secure password
    generatedPassword = generateSecurePassword();
    console.log("🔑 Generated secure password for admin user");

    // Step 3: Create admin user in Supabase Auth (organization now exists)
    adminUser = await createUserInAuth(
      supabase,
      {
        email: data.admin_email,
        fullName: data.admin_full_name,
        organizationId: organizationId,
        role: "admin",
      },
      generatedPassword
    );

    console.log(`✅ Admin user created: ${adminUser.userId}`);

    // Step 4: Send welcome email via external API
    const emailResult = await sendWelcomeEmail(
      data.partner_name,
      data.admin_email,
      generatedPassword,
      data.admin_full_name
    );

    if (!emailResult.status) {
      throw new Error(
        `Failed to send welcome email: ${
          emailResult.error || "Unknown email error"
        }`
      );
    }

    console.log("✅ Welcome email sent successfully");

    // Return comprehensive response
    return {
      data: {
        organization: newOrganization,
        admin_user: {
          id: adminUser.userId,
          email: adminUser.email,
          full_name: data.admin_full_name,
          role: "admin",
          password_sent: true,
        },
      },
      message: "Organization and admin user created successfully",
    };
  } catch (error: any) {
    console.error("❌ Error during organization creation:", error.message);

    // Cleanup: Delete created organization and user if something failed
    if (newOrganization?.id) {
      try {
        await supabase
          .from("organizations")
          .delete()
          .eq("id", newOrganization.id);
        console.log("🧹 Cleaned up created organization after failure");
      } catch (cleanupError: any) {
        console.error("Failed to cleanup organization:", cleanupError.message);
      }
    }

    if (adminUser?.userId) {
      try {
        await supabase.auth.admin.deleteUser(adminUser.userId);
        console.log("🧹 Cleaned up created user after failure");
      } catch (cleanupError: any) {
        console.error("Failed to cleanup user:", cleanupError.message);
      }
    }

    throw error;
  }
}

export async function updateOrganization(
  supabase: any,
  organizationId: string,
  data: any,
  userId: string
) {
  console.log(`📝 Updating organization ${organizationId}...`);

  // Validate the update data
  const validation = validateOrganizationData(data, "update");
  if (!validation.isValid) {
    throw new Error(`Validation failed: ${validation.errors.join(", ")}`);
  }

  // Check if organization exists
  const { data: existingOrg, error: fetchError } = await supabase
    .from("organizations")
    .select("*")
    .eq("id", organizationId)
    .single();

  if (fetchError || !existingOrg) {
    throw new Error("Organization not found");
  }

  // Prepare organization update data - only 8 allowed fields
  const organizationUpdateData = {
    ...(data.partner_name && { partner_name: data.partner_name }),
    ...(data.branch && { branch: data.branch }),
    ...(data.state && { state: data.state }),
    ...(data.contact_person !== undefined && {
      contact_person: data.contact_person,
    }),
    ...(data.contact_phone !== undefined && {
      contact_phone: data.contact_phone,
    }),
    ...(data.alternative_phone !== undefined && {
      alternative_phone: data.alternative_phone,
    }),
    ...(data.email !== undefined && { email: data.email }),
    ...(data.address !== undefined && { address: data.address }),
    updated_by: userId,
    updated_at: new Date().toISOString(),
  };

  // Handle admin user updates if provided
  let adminUser: any = null;
  if (data.admin_full_name || data.admin_email) {
    console.log("👤 Updating admin user details...");

    // Find the current admin user
    const currentAdmin = await findOrganizationAdmin(supabase, organizationId);
    if (!currentAdmin) {
      throw new Error("No admin user found for this organization");
    }

    // Update the admin user
    adminUser = await updateUserInAuth(
      supabase,
      currentAdmin.id,
      data.admin_email || currentAdmin.email, // Use new email or keep existing
      undefined, // Don't change password
      {
        ...(data.admin_full_name && { fullName: data.admin_full_name }),
        role: "admin",
        organizationId: organizationId,
      }
    );

    console.log("✅ Admin user updated successfully");
  }

  // Update the organization
  const { data: updatedOrganization, error: updateError } = await supabase
    .from("organizations")
    .update(organizationUpdateData)
    .eq("id", organizationId)
    .select()
    .single();

  if (updateError) {
    throw new Error(`Failed to update organization: ${updateError.message}`);
  }

  console.log("✅ Organization updated successfully");

  return {
    data: {
      organization: updatedOrganization,
      ...(adminUser && {
        admin_user: {
          id: adminUser.user.id,
          email: adminUser.user.email,
          full_name: adminUser.profile.full_name,
          role: "admin",
        },
      }),
    },
    message: "Organization updated successfully",
  };
}

// Create and update operations for organizations
import { validateOrganizationData } from "./validate.ts";

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

  // Validate required fields including admin user data
  const validationResult = validateOrganizationData(data, "create");
  if (!validationResult.isValid) {
    throw new Error(`Validation failed: ${validationResult.errors.join(", ")}`);
  }

  // Check if organization name already exists
  const { data: existingOrg, error: checkError } = await supabase
    .from("organizations")
    .select("id, name")
    .eq("name", data.name)
    .single();

  if (existingOrg) {
    throw new Error(`Organization with name "${data.name}" already exists`);
  }

  // Check if partner email already exists
  const { data: existingPartnerEmail, error: partnerCheckError } =
    await supabase
      .from("organizations")
      .select("id, partner_email")
      .eq("partner_email", data.partner_email)
      .single();

  if (existingPartnerEmail) {
    throw new Error(
      `Organization with partner email "${data.partner_email}" already exists`
    );
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

  try {
    // Step 1: Generate organization ID first (we'll need it for user creation)
    organizationId = crypto.randomUUID();

    // Step 2: Generate secure password
    generatedPassword = generateSecurePassword();
    console.log("🔑 Generated secure password for admin user");

    // Step 3: Create admin user in Supabase Auth
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
      data.name,
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

    // Step 5: Create organization record (only after email success)
    const organizationData = {
      id: organizationId, // Use the pre-generated ID
      name: data.name,
      partner_email: data.partner_email,
      contact_phone: data.contact_phone || null,
      address: data.address || null,
      city: data.city || null,
      state: data.state || null,
      country: data.country || "Nigeria",
      description: data.description || null,
      status: data.status || "active",
      created_by: userId,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    const { data: newOrganization, error: orgError } = await supabase
      .from("organizations")
      .insert([organizationData])
      .select()
      .single();

    if (orgError) {
      throw new Error(`Failed to create organization: ${orgError.message}`);
    }

    console.log("✅ Organization created successfully");

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
          has_changed_password: false,
        },
        email_sent: true,
      },
      message:
        "Organization and admin user created successfully. Welcome email sent.",
    };
  } catch (error) {
    console.error("❌ Error in organization creation process:", error);

    // Cleanup: If we got far enough to create a user but failed later, we should clean up
    if (adminUser?.userId) {
      try {
        console.log("🧹 Cleaning up created user due to failure...");
        await supabase.auth.admin.deleteUser(adminUser.userId);
        console.log("✅ User cleanup completed");
      } catch (cleanupError) {
        console.error("❌ Failed to cleanup user:", cleanupError);
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
  console.log(`✏️ Updating organization: ${organizationId}`);

  // Validate data
  const validationResult = validateOrganizationData(data, "update");
  if (!validationResult.isValid) {
    throw new Error(`Validation failed: ${validationResult.errors.join(", ")}`);
  }

  // Check if organization exists
  const { data: existingOrg, error: checkError } = await supabase
    .from("organizations")
    .select("id, name")
    .eq("id", organizationId)
    .single();

  if (checkError || !existingOrg) {
    throw new Error(`Organization with ID ${organizationId} not found`);
  }

  // Check if new name conflicts with existing organizations (if name is being updated)
  if (data.name && data.name !== existingOrg.name) {
    const { data: nameConflict, error: nameError } = await supabase
      .from("organizations")
      .select("id, name")
      .eq("name", data.name)
      .neq("id", organizationId)
      .single();

    if (nameConflict) {
      throw new Error(`Organization with name "${data.name}" already exists`);
    }
  }

  // Handle admin user updates if admin data is provided
  let adminUserUpdate: any = null;
  let passwordChanged = false;

  if (data.admin_email || data.admin_full_name) {
    console.log("🔄 Updating organization admin user...");

    // Find the current admin user for this organization
    const currentAdmin = await findOrganizationAdmin(supabase, organizationId);

    if (!currentAdmin) {
      throw new Error("No admin user found for this organization");
    }

    // Check if email is changing
    const emailChanging =
      data.admin_email && data.admin_email !== currentAdmin.email;

    if (emailChanging) {
      // Check if new email already exists
      const { data: existingUser, error: userCheckError } =
        await supabase.auth.admin.listUsers();

      if (!userCheckError) {
        const emailExists = existingUser.users.some(
          (user: any) =>
            user.email === data.admin_email && user.id !== currentAdmin.id
        );
        if (emailExists) {
          throw new Error(
            `User with email "${data.admin_email}" already exists`
          );
        }
      }

      // Generate new password if email is changing
      const newPassword = generateSecurePassword();
      passwordChanged = true;

      // Send email notification about the change
      try {
        const emailResult = await sendWelcomeEmail(
          data.name || existingOrg.name,
          data.admin_email,
          newPassword,
          data.admin_full_name || currentAdmin.full_name
        );

        if (!emailResult.status) {
          throw new Error(
            `Failed to send notification email: ${
              emailResult.error || "Unknown email error"
            }`
          );
        }

        console.log("✅ Admin user notification email sent");
      } catch (emailError) {
        throw new Error(
          `Failed to send admin user notification: ${emailError.message}`
        );
      }

      // Update user in auth
      adminUserUpdate = await updateUserInAuth(
        supabase,
        currentAdmin.id,
        data.admin_email,
        newPassword,
        {
          fullName: data.admin_full_name,
          organizationId: organizationId,
          role: "admin",
        }
      );
    } else if (
      data.admin_full_name &&
      data.admin_full_name !== currentAdmin.full_name
    ) {
      // Only name is changing, no password change needed
      adminUserUpdate = await updateUserInAuth(
        supabase,
        currentAdmin.id,
        currentAdmin.email,
        undefined, // No password change
        {
          fullName: data.admin_full_name,
          organizationId: organizationId,
          role: "admin",
        }
      );
    }
  }

  // Prepare organization update data
  const updateData: any = {
    updated_at: new Date().toISOString(),
  };

  // Only update provided fields
  if (data.name !== undefined) updateData.name = data.name;
  if (data.partner_email !== undefined)
    updateData.partner_email = data.partner_email;
  if (data.contact_phone !== undefined)
    updateData.contact_phone = data.contact_phone;
  if (data.address !== undefined) updateData.address = data.address;
  if (data.city !== undefined) updateData.city = data.city;
  if (data.state !== undefined) updateData.state = data.state;
  if (data.country !== undefined) updateData.country = data.country;
  if (data.description !== undefined) updateData.description = data.description;
  if (data.status !== undefined) updateData.status = data.status;

  const { data: updatedOrganization, error } = await supabase
    .from("organizations")
    .update(updateData)
    .eq("id", organizationId)
    .select()
    .single();

  if (error) {
    throw new Error(`Failed to update organization: ${error.message}`);
  }

  // Prepare response
  const response: any = {
    data: {
      organization: updatedOrganization,
    },
    message: "Organization updated successfully",
  };

  // Include admin user update info if applicable
  if (adminUserUpdate) {
    response.data.admin_user = {
      id: adminUserUpdate.user.id,
      email: adminUserUpdate.user.email,
      full_name: adminUserUpdate.profile.full_name,
      role: adminUserUpdate.profile.role,
      password_changed: passwordChanged,
      notification_sent: passwordChanged,
    };

    if (passwordChanged) {
      response.message +=
        " Admin user credentials updated and notification email sent.";
    } else {
      response.message += " Admin user information updated.";
    }
  }

  return response;
}

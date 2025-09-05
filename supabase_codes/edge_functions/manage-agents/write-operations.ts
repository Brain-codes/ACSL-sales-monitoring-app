// Write operations for agents (create and update)

import { validateAgentData, validateUpdateData } from "./validate.ts";

export async function createAgent(
  supabase: any,
  agentData: any,
  adminId: string,
  userRole: string,
  organizationId: string | null
) {
  console.log("➕ Creating new agent...");

  try {
    // Validate input data
    const validatedData = validateAgentData(agentData);
    console.log("✅ Agent data validated");

    // Determine organization for the new agent
    let targetOrganizationId = organizationId;

    if (userRole === "super_admin" && agentData.organization_id) {
      // Super admin can specify organization
      targetOrganizationId = agentData.organization_id;
      console.log(
        "🏢 Super admin specified organization:",
        targetOrganizationId
      );
    } else if (userRole === "admin") {
      // Admin creates agents in their own organization
      if (!organizationId) {
        throw new Error("Admin must have an organization to create agents");
      }
      targetOrganizationId = organizationId;
      console.log(
        "🏢 Admin creating agent in their organization:",
        targetOrganizationId
      );
    } else {
      throw new Error("Insufficient permissions to create agents");
    }

    // Check if email already exists
    const { data: existingUser, error: checkError } = await supabase
      .from("profiles")
      .select("id")
      .eq("email", validatedData.email)
      .maybeSingle();

    if (checkError) {
      console.error("❌ Error checking existing user:", checkError);
      throw new Error(`Database error: ${checkError.message}`);
    }

    if (existingUser) {
      throw new Error("User with this email already exists");
    }

    // Create user in Supabase Auth
    console.log("👤 Creating user in Supabase Auth...");
    const { data: createdUser, error: createError } =
      await supabase.auth.admin.createUser({
        email: validatedData.email,
        password: validatedData.password,
        email_confirm: true,
        user_metadata: {
          full_name: validatedData.full_name,
          role: "agent",
          organization_id: targetOrganizationId,
        },
      });

    if (createError) {
      console.error("❌ Failed to create user in Auth:", createError);
      throw new Error(`Failed to create user: ${createError.message}`);
    }

    console.log("✅ User created in Auth:", createdUser.user?.id);

    // The profile should be created automatically by the database trigger
    // Wait a moment and then fetch the profile to confirm
    await new Promise((resolve) => setTimeout(resolve, 1000));

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("id, full_name, email, role, organization_id")
      .eq("id", createdUser.user?.id)
      .single();

    if (profileError) {
      console.error("❌ Profile not created:", profileError);
      // Clean up the auth user if profile creation failed
      await supabase.auth.admin.deleteUser(createdUser.user?.id);
      throw new Error("Failed to create agent profile");
    }

    console.log("✅ Agent created successfully:", profile.id);

    return {
      message: "Agent created successfully",
      data: {
        id: profile.id,
        full_name: profile.full_name,
        email: profile.email,
        role: profile.role,
        organization_id: profile.organization_id,
      },
    };
  } catch (error) {
    console.error("❌ Error in createAgent:", error);
    throw error;
  }
}

export async function updateAgent(
  supabase: any,
  agentId: string,
  updateData: any,
  adminId: string,
  userRole: string,
  organizationId: string | null
) {
  console.log("✏️ Updating agent:", agentId);

  try {
    // Validate update data
    const validatedData = validateUpdateData(updateData);
    console.log("✅ Update data validated");

    // First, check if the agent exists and admin has permission to update
    let checkQuery = supabase
      .from("profiles")
      .select("id, organization_id, role")
      .eq("id", agentId)
      .eq("role", "agent");

    // Apply organization filter for admin users
    if (userRole === "admin" && organizationId) {
      checkQuery = checkQuery.eq("organization_id", organizationId);
    } else if (userRole !== "super_admin") {
      throw new Error("Insufficient permissions to update agents");
    }

    const { data: existingAgent, error: checkError } =
      await checkQuery.single();

    if (checkError) {
      if (checkError.code === "PGRST116") {
        throw new Error("Agent not found or access denied");
      }
      console.error("❌ Error checking agent:", checkError);
      throw new Error(`Database error: ${checkError.message}`);
    }

    console.log("🔍 Agent found, proceeding with update");

    // Check if email is being updated and if it conflicts
    if (validatedData.email) {
      const { data: emailConflict, error: emailError } = await supabase
        .from("profiles")
        .select("id")
        .eq("email", validatedData.email)
        .neq("id", agentId)
        .maybeSingle();

      if (emailError) {
        console.error("❌ Error checking email conflict:", emailError);
        throw new Error(`Database error: ${emailError.message}`);
      }

      if (emailConflict) {
        throw new Error("Email already exists for another user");
      }
    }

    // Update the profile
    const { data: updatedAgent, error: updateError } = await supabase
      .from("profiles")
      .update(validatedData)
      .eq("id", agentId)
      .select("id, full_name, email, phone, role, organization_id, created_at")
      .single();

    if (updateError) {
      console.error("❌ Error updating agent:", updateError);
      throw new Error(`Database error: ${updateError.message}`);
    }

    // If email was updated, update it in Auth as well
    if (validatedData.email) {
      const { error: authUpdateError } =
        await supabase.auth.admin.updateUserById(agentId, {
          email: validatedData.email,
        });

      if (authUpdateError) {
        console.warn(
          "⚠️ Failed to update email in Auth:",
          authUpdateError.message
        );
        // Don't fail the whole operation, just log the warning
      }
    }

    console.log("✅ Agent updated successfully:", updatedAgent.id);

    return {
      message: "Agent updated successfully",
      data: updatedAgent,
    };
  } catch (error) {
    console.error("❌ Error in updateAgent:", error);
    throw error;
  }
}

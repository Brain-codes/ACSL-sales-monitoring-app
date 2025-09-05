// Validation module for organization and user data

export interface ValidationResult {
  isValid: boolean;
  errors: string[];
}

export interface CreateOrganizationWithUserData {
  // Organization fields
  name: string;
  partner_email: string;
  contact_phone?: string;
  address?: string;
  city?: string;
  state?: string;
  country?: string;
  description?: string;
  status?: string;

  // Admin user fields
  admin_full_name: string;
  admin_email: string;
}

export function validateOrganizationData(
  data: any,
  operation: "create" | "update"
): ValidationResult {
  const errors: string[] = [];

  if (!data || typeof data !== "object") {
    return {
      isValid: false,
      errors: ["Invalid data format: Expected object"],
    };
  }

  // Required fields for creation
  if (operation === "create") {
    if (
      !data.name ||
      typeof data.name !== "string" ||
      data.name.trim().length === 0
    ) {
      errors.push("Organization name is required");
    }

    if (
      !data.partner_email ||
      typeof data.partner_email !== "string" ||
      data.partner_email.trim().length === 0
    ) {
      errors.push("Partner email is required");
    }

    // Validate admin user fields for creation
    if (
      !data.admin_full_name ||
      typeof data.admin_full_name !== "string" ||
      data.admin_full_name.trim().length === 0
    ) {
      errors.push("Admin user full name is required");
    }

    if (
      !data.admin_email ||
      typeof data.admin_email !== "string" ||
      data.admin_email.trim().length === 0
    ) {
      errors.push("Admin user email is required");
    }
  }

  // Validate admin user fields for creation
  if (operation === "create") {
    if (data.admin_full_name && typeof data.admin_full_name === "string") {
      if (data.admin_full_name.trim().length === 0) {
        errors.push("Admin user full name cannot be empty");
      } else if (data.admin_full_name.trim().length > 100) {
        errors.push("Admin user full name cannot exceed 100 characters");
      }
    }

    if (data.admin_email && typeof data.admin_email === "string") {
      if (data.admin_email.trim().length === 0) {
        errors.push("Admin user email cannot be empty");
      } else if (!isValidEmail(data.admin_email)) {
        errors.push("Admin user email must be a valid email address");
      }
    }
  }

  // Validate admin user fields for updates (if provided)
  if (operation === "update") {
    if (data.admin_full_name !== undefined) {
      if (typeof data.admin_full_name !== "string") {
        errors.push("Admin user full name must be a string");
      } else if (data.admin_full_name.trim().length === 0) {
        errors.push("Admin user full name cannot be empty");
      } else if (data.admin_full_name.trim().length > 100) {
        errors.push("Admin user full name cannot exceed 100 characters");
      }
    }

    if (data.admin_email !== undefined) {
      if (typeof data.admin_email !== "string") {
        errors.push("Admin user email must be a string");
      } else if (data.admin_email.trim().length === 0) {
        errors.push("Admin user email cannot be empty");
      } else if (!isValidEmail(data.admin_email)) {
        errors.push("Admin user email must be a valid email address");
      }
    }
  }
  if (data.name !== undefined) {
    if (typeof data.name !== "string") {
      errors.push("Organization name must be a string");
    } else if (data.name.trim().length === 0) {
      errors.push("Organization name cannot be empty");
    } else if (data.name.trim().length > 100) {
      errors.push("Organization name cannot exceed 100 characters");
    }
  }

  // Validate email if provided
  if (data.partner_email !== undefined) {
    if (typeof data.partner_email !== "string") {
      errors.push("Partner email must be a string");
    } else if (data.partner_email.trim().length === 0) {
      errors.push("Partner email cannot be empty");
    } else if (!isValidEmail(data.partner_email)) {
      errors.push("Partner email must be a valid email address");
    }
  }

  // Validate contact phone if provided
  if (data.contact_phone !== undefined && data.contact_phone !== null) {
    if (typeof data.contact_phone !== "string") {
      errors.push("Contact phone must be a string");
    } else if (data.contact_phone.length > 20) {
      errors.push("Contact phone cannot exceed 20 characters");
    }
  }

  // Validate address fields if provided
  if (data.address !== undefined && data.address !== null) {
    if (typeof data.address !== "string") {
      errors.push("Address must be a string");
    } else if (data.address.length > 255) {
      errors.push("Address cannot exceed 255 characters");
    }
  }

  if (data.city !== undefined && data.city !== null) {
    if (typeof data.city !== "string") {
      errors.push("City must be a string");
    } else if (data.city.length > 100) {
      errors.push("City cannot exceed 100 characters");
    }
  }

  if (data.state !== undefined && data.state !== null) {
    if (typeof data.state !== "string") {
      errors.push("State must be a string");
    } else if (data.state.length > 100) {
      errors.push("State cannot exceed 100 characters");
    }
  }

  if (data.country !== undefined && data.country !== null) {
    if (typeof data.country !== "string") {
      errors.push("Country must be a string");
    } else if (data.country.length > 100) {
      errors.push("Country cannot exceed 100 characters");
    }
  }

  // Validate description if provided
  if (data.description !== undefined && data.description !== null) {
    if (typeof data.description !== "string") {
      errors.push("Description must be a string");
    } else if (data.description.length > 500) {
      errors.push("Description cannot exceed 500 characters");
    }
  }

  // Validate status if provided
  if (data.status !== undefined) {
    const validStatuses = ["active", "inactive", "suspended"];
    if (!validStatuses.includes(data.status)) {
      errors.push(`Status must be one of: ${validStatuses.join(", ")}`);
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
  };
}

// Helper function to validate email format
function isValidEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

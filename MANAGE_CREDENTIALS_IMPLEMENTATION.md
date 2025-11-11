# Manage Credentials Edge Function - Implementation Summary

## Overview

Created a new Supabase Edge Function called **`manage-credentials`** that provides Super Admin functionality for managing organization credentials stored in the `credentials` table.

## Purpose

This edge function allows the Super Admin to:

1. View all organization credentials (email/password combinations)
2. View specific credential by partner ID or organization ID
3. Reset/update passwords for organizations with security verification
4. Generate secure random passwords

---

## Security Features

### 1. Super Admin Only Access

- **All endpoints** require authentication with `role = 'super_admin'`
- Non-super-admin users receive `401 Unauthorized` response
- Authentication verified on every request

### 2. Password Reset Security (Critical Feature)

When resetting an organization's password, the Super Admin must:

- Provide the **organization's partner ID**
- Provide the **new password** for the organization
- **Provide their own email**
- **Provide their own password** (for verification)

This prevents unauthorized password changes even if someone gains access to a Super Admin's session.

---

## API Endpoints

### 1. GET `/manage-credentials`

**Purpose**: Fetch all organization credentials

**Response**:

```json
{
  "success": true,
  "count": 25,
  "data": [
    {
      "partner_id": "598581",
      "partner_name": "LAPO MFB GBONGAN",
      "email": "lapo_mfb_gbongan_598581@atmosfair.site",
      "password": "aB3d5FgH9!kL",
      "is_dummy_email": true,
      "created_at": "2025-11-06T10:30:00Z",
      "organizations": {
        "partner_name": "LAPO MFB GBONGAN",
        "contact_person": "John Doe",
        "state": "Osun",
        "branch": "Gbongan"
      }
    }
  ]
}
```

### 2. GET `/manage-credentials?partner_id=598581`

**Purpose**: Get credential for specific organization by partner ID

### 3. GET `/manage-credentials?organization_id=uuid`

**Purpose**: Get credential for specific organization by organization UUID

### 4. PUT `/manage-credentials/update-password`

**Purpose**: Reset organization password with Super Admin verification

**Request Body**:

```json
{
  "partner_id": "598581",
  "new_password": "NewSecureP@ssw0rd123",
  "super_admin_email": "admin@acsl.com",
  "super_admin_password": "SuperAdminCurrentPassword"
}
```

**What Happens**:

1. Verifies Super Admin's password using Supabase Auth
2. If valid, fetches credential record by partner_id
3. Updates password in `auth.users` table (hashed)
4. Updates password in `credentials` table (plaintext for reference)
5. Returns success message

### 5. POST `/manage-credentials/generate-password`

**Purpose**: Generate a secure random password (helper endpoint)

**Request Body** (optional):

```json
{
  "length": 16
}
```

**Response**:

```json
{
  "success": true,
  "password": "aB3d5FgH9!kL2pQ7"
}
```

---

## File Structure

```
supabase/functions/manage-credentials/
├── index.ts                    # Main entry point
├── authenticate.ts             # Super Admin authentication & verification
├── cors.ts                     # CORS configuration
├── route-handler.ts            # Request routing logic
├── read-operations.ts          # GET operations (fetch credentials)
├── update-operations.ts        # UPDATE operations (password reset)
└── API_DOCUMENTATION.md        # Complete API docs for frontend
```

---

## Technical Implementation

### Authentication Flow

```typescript
1. Request arrives with Authorization header
2. authenticateSuperAdmin() extracts JWT token
3. Verifies token with Supabase Auth
4. Fetches user profile from profiles table
5. Checks if role === 'super_admin'
6. If valid: Proceeds to route handler
7. If invalid: Returns 401 Unauthorized
```

### Password Reset Flow

```typescript
1. Request includes:
   - partner_id (organization to reset)
   - new_password (new password for org)
   - super_admin_email (who's doing the reset)
   - super_admin_password (their password)

2. Verify Super Admin password:
   - Create separate Supabase client
   - Attempt signInWithPassword()
   - If fails: Return "Invalid Super Admin password"

3. Fetch credential record by partner_id

4. Update auth.users password:
   - Use service role client
   - admin.updateUserById(user_id, { password: new_password })

5. Update credentials table:
   - Update password field
   - Update updated_at timestamp

6. Return success message
```

---

## Key Features

### 1. Dual Password Update

When resetting a password, the system updates **both**:

- `auth.users` table (Supabase Auth - hashed password)
- `credentials` table (plaintext for admin reference)

This ensures consistency between authentication and credential records.

### 2. Security Verification

The Super Admin must prove their identity by entering their own password. This:

- Prevents session hijacking exploits
- Provides audit trail
- Follows security best practices

### 3. Comprehensive Logging

All operations include detailed console logging with emojis:

- 🔐 Authentication events
- ✅ Success operations
- ❌ Error operations
- 📋 Data fetching
- 🔑 Password operations

---

## Frontend Integration

### React Example - Fetch Credentials

```typescript
const fetchCredentials = async () => {
  const token = localStorage.getItem("supabase_auth_token");

  const response = await fetch(
    "https://[project-ref].supabase.co/functions/v1/manage-credentials",
    {
      method: "GET",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
    }
  );

  const data = await response.json();
  return data;
};
```

### React Example - Reset Password

```typescript
const resetPassword = async (
  partnerId: string,
  newPassword: string,
  adminPassword: string
) => {
  const token = localStorage.getItem("supabase_auth_token");
  const adminEmail = localStorage.getItem("user_email");

  const response = await fetch(
    "https://[project-ref].supabase.co/functions/v1/manage-credentials/update-password",
    {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        partner_id: partnerId,
        new_password: newPassword,
        super_admin_email: adminEmail,
        super_admin_password: adminPassword, // User must enter this
      }),
    }
  );

  const data = await response.json();
  return data;
};
```

---

## Database Schema (credentials table)

The edge function works with the existing `credentials` table:

```sql
credentials (
  id UUID PRIMARY KEY,
  partner_id TEXT NOT NULL,
  partner_name TEXT NOT NULL,
  email TEXT NOT NULL,
  password TEXT NOT NULL,              -- Plaintext password for admin reference
  organization_id UUID REFERENCES organizations(id),
  user_id UUID REFERENCES auth.users(id),
  is_dummy_email BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
)
```

---

## Error Handling

The API returns specific error messages for different scenarios:

| Error                                        | Status | Meaning                     |
| -------------------------------------------- | ------ | --------------------------- |
| "Missing Authorization header"               | 401    | No auth token provided      |
| "Invalid or expired token"                   | 401    | Bad auth token              |
| "Access denied. Only Super Admin can access" | 401    | User is not super_admin     |
| "Invalid Super Admin password"               | 400    | Wrong password during reset |
| "Credential not found for this partner"      | 404    | Partner ID doesn't exist    |
| "Failed to update authentication password"   | 400    | Supabase Auth error         |
| "Failed to update credential record"         | 400    | Database update error       |

---

## Testing

### Using cURL - Get All Credentials

```bash
curl -X GET \
  'https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials' \
  -H 'Authorization: Bearer YOUR_SUPER_ADMIN_TOKEN' \
  -H 'Content-Type: application/json'
```

### Using cURL - Reset Password

```bash
curl -X PUT \
  'https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials/update-password' \
  -H 'Authorization: Bearer YOUR_SUPER_ADMIN_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "partner_id": "598581",
    "new_password": "NewP@ssw0rd123",
    "super_admin_email": "admin@acsl.com",
    "super_admin_password": "YourCurrentPassword"
  }'
```

### Using Postman

1. **Import Collection**: Create a new collection called "Manage Credentials"
2. **Set Variables**:
   - `base_url`: `https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1`
   - `auth_token`: Your Super Admin JWT token
3. **Add Requests**: For each endpoint above

---

## Deployment Status

✅ **Edge Function Deployed**: `manage-credentials`
✅ **Backup Created**: `supabase_codes/edge_functions/manage-credentials/`
✅ **API Documentation**: Complete with React examples
✅ **Security Features**: Password verification implemented
✅ **Error Handling**: Comprehensive error messages

---

## Files Created

### Deployment (supabase/functions/manage-credentials/)

1. `index.ts` - Main entry point
2. `authenticate.ts` - Authentication utilities
3. `cors.ts` - CORS configuration
4. `route-handler.ts` - Request routing
5. `read-operations.ts` - GET operations
6. `update-operations.ts` - UPDATE operations
7. `API_DOCUMENTATION.md` - Complete API docs

### Backup (supabase_codes/edge_functions/manage-credentials/)

- Same files copied for version control

---

## Next Steps for Frontend Developer

1. **Read API_DOCUMENTATION.md**: Complete guide with React examples
2. **Test Endpoints**: Use cURL or Postman to verify functionality
3. **Implement UI**:
   - Credentials list table
   - Password reset modal with password input
   - Password generator button
   - Copy-to-clipboard functionality
4. **Handle Errors**: Show user-friendly error messages
5. **Security**: Clear password fields after operations

---

## Important Notes

### For Super Admin Users

1. **You must enter your own password** when resetting another user's password
2. **Passwords are visible** in plaintext in the credentials table (by design for admin reference)
3. **All actions are logged** in the Supabase console
4. **Only Super Admins** can access this functionality

### For Frontend Developers

1. **Always prompt for Super Admin password** when resetting passwords
2. **Use password input type** to hide password entry
3. **Clear sensitive data** from state after operations
4. **Implement confirmation dialogs** before password resets
5. **Handle network errors** with retry logic

### Security Considerations

1. **Password Verification**: Prevents unauthorized changes even with session access
2. **Super Admin Only**: Role-based access control enforced
3. **Audit Trail**: All operations logged with user identification
4. **Dual Storage**: Passwords stored in both auth (hashed) and credentials (plaintext for admin)

---

## Comparison with Similar Functions

| Feature               | manage-organizations | manage-credentials       |
| --------------------- | -------------------- | ------------------------ |
| Authentication        | Super Admin          | Super Admin              |
| Main Purpose          | CRUD organizations   | View/reset credentials   |
| Password Verification | Not required         | Required for resets      |
| Key Operation         | Create/Update orgs   | Reset passwords          |
| Data Modified         | organizations table  | credentials + auth.users |

---

## Summary

The **Manage Credentials** edge function provides a secure, Super Admin-only interface for credential management. Key highlights:

✅ **Secure password resets** with Super Admin verification
✅ **Complete API documentation** for React developers
✅ **Comprehensive error handling** with specific messages
✅ **Dual password updates** (auth + credentials table)
✅ **Helper functions** (generate password, fetch credentials)

**Ready for frontend integration!** Send the `API_DOCUMENTATION.md` file to your React developer.

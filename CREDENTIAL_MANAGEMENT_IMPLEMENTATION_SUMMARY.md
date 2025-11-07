# Credential Management Implementation Summary

## Overview
Implemented automatic user credential generation for external sync API partners who don't provide email addresses in their CSV/sync data.

## Implementation Date
November 6, 2025

---

## What Was Added

### 1. Database Schema - Credentials Table
**File:** `supabase_codes/sql_queries/create-credentials-table.sql`

**Purpose:** Store auto-generated login credentials for partners without email addresses

**Columns:**
- `id` (UUID, primary key)
- `partner_id` (text, indexed)
- `partner_name` (text)
- `email` (text, indexed)
- `password` (text, stored in plaintext for partner reference)
- `organization_id` (UUID, references organizations table, indexed)
- `user_id` (UUID, references auth.users, indexed)
- `is_dummy_email` (boolean, indicates if email was auto-generated)
- `created_at` (timestamptz)
- `updated_at` (timestamptz, with auto-update trigger)

**Security (RLS Policies):**
- `admin_view_credentials`: Admins and super admins can view all credentials
- `service_role_insert_update`: Only service role can insert/update (via edge functions)
- `super_admin_delete`: Only super admins can delete credentials

---

### 2. Edge Function Updates

#### A. External-Sync Function (`external-sync/index.ts`)
**New Interfaces:**
```typescript
interface UserCreationResult {
  userId: string;
  email: string;
  password: string;
  isDummyEmail: boolean;
}
```

**New Utility Functions:**

1. **`generatePassword(length = 16)`**
   - Generates secure random passwords
   - Uses mix of letters, numbers, and special characters
   - Default length: 16 characters

2. **`generateDummyEmail(partnerName, partnerId)`**
   - Creates emails in format: `partner_name_partnerId@atmosfair.site`
   - Sanitizes partner name (lowercase, removes special chars, replaces spaces with underscores)
   - Limits length to 50 characters

3. **`createUserForOrganization(supabase, email, password, partnerName, organizationId)`**
   - Creates user in `auth.users` via Supabase Admin API
   - Auto-confirms email
   - Creates corresponding entry in `profiles` table
   - Sets default role as 'admin'
   - Rolls back auth user if profile creation fails

4. **`saveCredentials(supabase, partnerId, partnerName, email, password, organizationId, userId, isDummyEmail)`**
   - Saves credentials to `credentials` table
   - Stores password in plaintext for partner reference
   - Marks dummy emails with `is_dummy_email` flag

**Modified Function:**
`processOrganizationSync()` - Enhanced to:
- Check if organization exists (by `partner_id`)
- **For existing orgs:** Update only (no user creation)
- **For new orgs:**
  1. Create organization
  2. Determine email (use provided or generate dummy)
  3. Generate secure password
  4. Create auth user + profile
  5. Save credentials to database
- Return user creation status in response

**Response Format (New Organization):**
```json
{
  "organization": {
    "id": "uuid",
    "partner_id": "123",
    "partner_name": "Partner Name",
    "action": "created"
  },
  "user": {
    "created": true,
    "email": "partner_name_123@atmosfair.site",
    "password": "generated_password",
    "is_dummy_email": true
  },
  "stove_ids": [...],
  "summary": {
    "organization_action": "created",
    "user_created": true,
    "stove_ids_processed": 3,
    "stove_ids_created": 3,
    "stove_ids_skipped": 0
  }
}
```

#### B. External-CSV-Sync Function (`external-csv-sync/index.ts`)
**Identical Changes:**
- Same interfaces and utility functions added
- Same user creation logic in `processOrganizationSync()`
- Same response format with user credentials

---

## How It Works

### Flow for New Organizations

1. **External partner sends CSV with organization data**
   - Email field can be empty/missing

2. **API validates token and parses CSV**
   - Flexible column mapping handles various header names

3. **For each organization:**
   - Check if `partner_id` exists in database
   
4. **If organization doesn't exist:**
   - Create organization record
   - **Email determination:**
     - If email provided → use it
     - If email missing → generate: `partner_name_partnerId@atmosfair.site`
   - Generate secure random password (16 chars)
   - Create user in `auth.users` (auto-confirmed)
   - Create profile entry (role: 'admin')
   - Save credentials to `credentials` table
   - Return credentials in API response

5. **If organization exists:**
   - Update organization data only
   - No user creation
   - Return updated organization info

### Flow for Existing Organizations
- Update operation only (preserves existing flow)
- No user creation attempts
- No credential changes

---

## Key Features

### ✅ Preserves Existing Flow
- Existing organizations are updated, not recreated
- No duplicate user creation for existing partners

### ✅ Conditional User Creation
- Users created ONLY for new organizations
- Credentials saved for both real and dummy emails

### ✅ Dummy Email Generation
- Format: `partner_name_partnerId@atmosfair.site`
- Sanitized (lowercase, no special chars, underscores for spaces)
- Unique per partner

### ✅ Secure Password Generation
- 16 characters by default
- Mix of uppercase, lowercase, numbers, special chars
- Cryptographically secure random generation

### ✅ Automatic Profile Creation
- Creates auth user + profile in one transaction
- Default role: 'admin'
- Links to organization via `organization_id`

### ✅ Credential Storage
- Stored in dedicated `credentials` table
- Password in plaintext for partner reference
- Flagged if email is dummy (`is_dummy_email`)
- Indexed for fast lookups

### ✅ Error Handling
- User creation failure doesn't block organization creation
- Errors logged but sync continues
- Rollback auth user if profile creation fails

---

## Security Considerations

### Row-Level Security (RLS)
- **View:** Only admins and super admins
- **Insert/Update:** Service role only (via edge functions)
- **Delete:** Super admins only

### Password Storage
- Stored in plaintext in `credentials` table
- **Reason:** Partners need access to their auto-generated credentials
- **Mitigation:** Protected by RLS, only admins can view

### Email Validation
- Dummy emails use controlled domain: `@atmosfair.site`
- Real emails used as-is if provided
- All emails auto-confirmed in auth system

---

## Deployment Steps

### 1. Deploy Database Schema
```sql
-- Run in Supabase SQL Editor
-- File: supabase_codes/sql_queries/create-credentials-table.sql
```
This creates:
- `credentials` table
- RLS policies
- Indexes
- Auto-update trigger

### 2. Update Edge Functions
**Via Supabase Dashboard:**
1. Navigate to Edge Functions
2. Update `external-sync` function
   - Copy content from `supabase_codes/edge_functions/external-sync/index.ts`
3. Update `external-csv-sync` function
   - Copy content from `supabase_codes/edge_functions/external-csv-sync/index.ts`
4. Deploy both functions

**Via CLI (alternative):**
```bash
# Deploy external-sync
supabase functions deploy external-sync

# Deploy external-csv-sync
supabase functions deploy external-csv-sync
```

---

## Testing Guide

### Test Case 1: New Organization Without Email
**Input CSV:**
```csv
partner_id,partner_name,contact_person,contact_phone,address,state,stove_ids
NEW001,Test Partner,John Doe,1234567890,123 Main St,CA,STOVE001;STOVE002
```

**Expected Result:**
- Organization created
- User created with email: `test_partner_NEW001@atmosfair.site`
- Password auto-generated (returned in response)
- Profile created with role 'admin'
- Credentials saved to database
- 2 stove IDs created

**API Response:**
```json
{
  "success": true,
  "organization": { "action": "created", ... },
  "user": {
    "created": true,
    "email": "test_partner_NEW001@atmosfair.site",
    "password": "Xy7#kL9pQ2mN5vB8",
    "is_dummy_email": true
  }
}
```

### Test Case 2: New Organization With Email
**Input CSV:**
```csv
partner_id,partner_name,email,contact_person,stove_ids
NEW002,Another Partner,partner@example.com,Jane Smith,STOVE003
```

**Expected Result:**
- Organization created
- User created with provided email: `partner@example.com`
- Password auto-generated
- Credentials saved with `is_dummy_email = false`

### Test Case 3: Existing Organization Update
**Input CSV:**
```csv
partner_id,partner_name,contact_phone,stove_ids
EXIST001,Existing Partner,9876543210,STOVE004;STOVE005
```

**Expected Result:**
- Organization updated
- NO user creation
- New stove IDs added
- Response indicates `user.created = false`

---

## Database Queries for Verification

### Check Created Credentials
```sql
SELECT 
  partner_id,
  partner_name,
  email,
  is_dummy_email,
  organization_id,
  created_at
FROM credentials
ORDER BY created_at DESC;
```

### View All Dummy Email Accounts
```sql
SELECT 
  c.partner_name,
  c.email,
  c.password,
  o.partner_id,
  p.role
FROM credentials c
JOIN organizations o ON c.organization_id = o.id
JOIN profiles p ON c.user_id = p.id
WHERE c.is_dummy_email = true
ORDER BY c.created_at DESC;
```

### Count Organizations With/Without User Credentials
```sql
SELECT 
  COUNT(DISTINCT o.id) as total_orgs,
  COUNT(DISTINCT c.organization_id) as orgs_with_credentials,
  COUNT(DISTINCT o.id) - COUNT(DISTINCT c.organization_id) as orgs_without_credentials
FROM organizations o
LEFT JOIN credentials c ON o.id = c.organization_id;
```

---

## Files Modified/Created

### Created Files
1. `supabase_codes/sql_queries/create-credentials-table.sql`
2. `CREDENTIAL_MANAGEMENT_IMPLEMENTATION_SUMMARY.md` (this file)

### Modified Files
1. `supabase_codes/edge_functions/external-sync/index.ts`
2. `supabase_codes/edge_functions/external-csv-sync/index.ts`

---

## API Response Changes

### Before (Old Response)
```json
{
  "success": true,
  "organization": { ... },
  "stove_ids": [ ... ],
  "summary": { ... }
}
```

### After (New Response)
```json
{
  "success": true,
  "organization": { ... },
  "user": {
    "created": true/false,
    "email": "email@domain.com",
    "password": "generated_password",
    "is_dummy_email": true/false,
    "reason": "Optional reason if not created"
  },
  "stove_ids": [ ... ],
  "summary": {
    "user_created": true/false,
    ...
  }
}
```

---

## Important Notes

### ⚠️ Breaking Changes
**None** - Existing flow preserved:
- Existing organizations continue to be updated without user creation
- API request format unchanged
- Token authentication unchanged

### 🔒 Security Notes
1. Passwords stored in plaintext in `credentials` table (by design)
2. Only admins/super admins can view credentials (RLS enforced)
3. Service role required for edge function operations
4. All auth users auto-confirmed (no email verification needed)

### 📝 Business Logic
1. **One user per organization** (created on first sync)
2. **Admin role by default** (can be changed manually)
3. **Credentials table is audit trail** (tracks all generated logins)
4. **Dummy emails use @atmosfair.site domain** (can be updated if needed)

---

## Next Steps

1. ✅ Deploy `create-credentials-table.sql` to Supabase
2. ✅ Update edge functions in Supabase dashboard
3. ⏳ Test with sample CSV (with and without emails)
4. ⏳ Verify credentials in database
5. ⏳ Test login with generated credentials
6. ⏳ Document credential distribution process for partners

---

## Support & Troubleshooting

### Common Issues

**Issue:** User creation fails but organization created
- **Cause:** Profile table RLS policy or foreign key constraint
- **Fix:** User creation is non-blocking, organization still synced
- **Check:** Edge function logs for detailed error

**Issue:** Duplicate email error
- **Cause:** Email already exists in auth.users
- **Fix:** Each partner_id generates unique email (includes partner_id)
- **Prevention:** Partner_id must be unique

**Issue:** Can't view credentials
- **Cause:** RLS policy requires admin/super_admin role
- **Fix:** Check user role in profiles table

### Debugging Queries

```sql
-- Check if user was created for organization
SELECT 
  o.partner_name,
  o.partner_id,
  c.email,
  c.is_dummy_email,
  au.email as auth_email,
  au.email_confirmed_at
FROM organizations o
LEFT JOIN credentials c ON o.id = c.organization_id
LEFT JOIN auth.users au ON c.user_id = au.id
WHERE o.partner_id = 'YOUR_PARTNER_ID';
```

---

**End of Document**

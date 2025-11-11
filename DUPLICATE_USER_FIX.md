# Duplicate User Creation Fix

## Problem

When syncing organizations via the external sync API, users were being created **every time** an organization was synced, even if a user already existed for that organization. This caused a duplicate key violation error:

```
duplicate key value violates unique constraint "profiles_email_key"
```

### Error Example

```
Organization: LAPO MFB GBONGAN
Generated dummy email: lapo_mfb_gbongan_598581@atmosfair.site
Error: Profile creation failed: duplicate key value violates unique constraint "profiles_email_key"
```

---

## Root Cause

The code was creating a user for **every new organization**, but it didn't check if a user already existed for that organization before attempting to create one.

### Previous Logic Flow

```
1. Check if organization exists
2. If organization DOES NOT exist:
   - Create organization
   - ALWAYS create user (❌ Problem here!)
3. If organization DOES exist:
   - Update organization
   - No user creation
```

### The Issue

If you synced the same organization multiple times (e.g., to update stove IDs), the system would:

1. First sync: Create organization ✅ → Create user ✅
2. Second sync: Organization exists, so update ✅ (no user creation)
3. **BUT** if the organization was deleted and re-created, it would try to create a duplicate user ❌

---

## Solution

Added a check to see if a user/profile already exists for the organization **before** attempting to create a new user.

### New Logic Flow

```
1. Check if organization exists
2. If organization DOES NOT exist:
   - Create organization
   - Check if user already exists for this organization ID
     - If user EXISTS: Skip user creation ✅
     - If user DOES NOT exist: Create user ✅
3. If organization DOES exist:
   - Update organization
   - No user creation
```

---

## Code Changes

### Added Profile Check

```typescript
// First, check if a user already exists for this organization
const { data: existingProfile, error: profileCheckError } = await supabase
  .from("profiles")
  .select("*")
  .eq("organization_id", organization.id)
  .maybeSingle();

if (existingProfile) {
  console.log(
    `ℹ️ User already exists for organization (email: ${existingProfile.email}), skipping user creation`
  );
} else {
  console.log(`👤 No existing user found, creating admin user...`);
  // ... proceed with user creation
}
```

### Key Points

1. **Uses `maybeSingle()`**: Returns `null` if no profile exists (instead of throwing an error)
2. **Checks by `organization_id`**: Ensures we're checking for users of THIS specific organization
3. **Logs the result**: Makes it easy to see in logs whether a user was created or skipped
4. **Preserves all existing logic**: Email validation, dummy email generation, and credential storage all still work

---

## What This Fixes

✅ **No more duplicate user errors** when syncing existing organizations  
✅ **Idempotent sync operations** - you can run the same sync multiple times safely  
✅ **Credentials are only created once** per organization  
✅ **Existing users are preserved** and not overwritten

---

## Updated Behavior

### Scenario 1: First-time sync of new organization

```
Input: Organization "LAPO MFB GBONGAN" with email "N/A"

Flow:
1. Organization doesn't exist → Create organization ✅
2. Check for existing user → None found
3. Generate dummy email: lapo_mfb_gbongan_598581@atmosfair.site
4. Create user in auth.users ✅
5. Create profile in profiles table ✅
6. Save credentials to credentials table ✅

Result: Organization created with new user account
```

### Scenario 2: Syncing same organization again (e.g., updating stove IDs)

```
Input: Same organization "LAPO MFB GBONGAN" with new stove IDs

Flow:
1. Organization exists → Update organization ✅
2. No user creation attempted (existing org branch)
3. Process new stove IDs ✅

Result: Organization updated, existing user preserved
```

### Scenario 3: Organization was deleted and recreated

```
Input: Organization "LAPO MFB GBONGAN" (recreated after deletion)

Flow:
1. Organization doesn't exist → Create organization ✅
2. Check for existing user → User still exists!
3. Skip user creation (log: "User already exists")
4. Process stove IDs ✅

Result: Organization recreated, existing user preserved, no duplicate error
```

---

## Testing

You can now safely:

1. **Sync the same organization multiple times** - no duplicate errors
2. **Update stove IDs** without worrying about user creation
3. **Re-sync organizations** after database changes

### Test Command (Postman or API call)

```bash
POST https://[project-ref].supabase.co/functions/v1/external-csv-sync
Content-Type: application/json

{
  "token": "your-token",
  "secret_key": "your-secret",
  "application_name": "Atmosfair ERP System",
  "csv_data": "partner_id,partner_name,email\n598581,LAPO MFB GBONGAN,N/A"
}
```

**Expected Log Output:**

First sync:

```
🆕 New organization created, checking if user needs to be created...
👤 No existing user found, creating admin user...
✅ Admin user created successfully
```

Second sync (same organization):

```
ℹ️ Organization already exists, updating...
✅ Organization updated successfully
```

Third sync (if organization recreated):

```
🆕 New organization created, checking if user needs to be created...
ℹ️ User already exists for organization (email: lapo_mfb_gbongan_598581@atmosfair.site), skipping user creation
```

---

## Files Modified

✅ `supabase/functions/external-csv-sync/index.ts` - CSV bulk sync endpoint  
✅ `supabase/functions/external-sync/index.ts` - Single organization sync endpoint  
✅ `supabase_codes/edge_functions/external-csv-sync/index.ts` - Backup copy  
✅ `supabase_codes/edge_functions/external-sync/index.ts` - Backup copy

---

## Deployment Status

✅ Both edge functions deployed successfully to Supabase  
✅ Backup files synchronized  
✅ Ready for production use

---

## Summary

This fix ensures **idempotent sync operations** - you can safely sync organizations multiple times without creating duplicate users. The system now checks if a user already exists before attempting to create one, preventing the duplicate key constraint violation error.

The fix maintains all existing functionality:

- Email validation
- Dummy email generation for invalid emails
- Secure password generation
- Credential storage for admin reference
- Comprehensive logging

**You can now re-run your CSV sync safely!** 🎉

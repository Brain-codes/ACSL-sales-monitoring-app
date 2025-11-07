# Primary Key Conflict Fix (profiles_pkey)

## Problem

When syncing a **brand new organization** for the first time, the system was throwing a primary key violation error:

```
duplicate key value violates unique constraint "profiles_pkey"
```

### Error Example

```
Organization: LAPO MFB IKEJA 1 (First time sync - never existed before)
Generated dummy email: lapo_mfb_ikeja_1_E49196@atmosfair.site
Error: Profile creation failed: duplicate key value violates unique constraint "profiles_pkey"
```

---

## Root Cause

The `profiles_pkey` error means there was a conflict with the **UUID** (the `id` column in the profiles table), not the email. This happens when:

1. **First sync attempt**: Creates user in `auth.users` ✅ → Tries to create profile ❌ (Fails for some reason)
2. **Cleanup attempt**: Tries to delete auth user (but might fail silently or partially)
3. **Second sync attempt**: Tries to create auth user again
   - **Either**: Gets same UUID from auth.users (if deletion failed)
   - **Or**: Creates new auth user but UUID conflicts with orphaned profile
4. **Result**: Profile creation fails with `duplicate key value violates unique constraint "profiles_pkey"`

### Why This Happens

The previous code flow was:

```typescript
1. Create user in auth.users
2. Try to create profile
3. If profile creation fails:
   - Try to delete auth user (cleanup)
   - But cleanup might not work properly
4. Next sync: Creates auth user again with same/conflicting UUID
```

**The problem**: There was no check to see if:
- An auth user already exists with this email
- A profile already exists with this user ID

---

## Solution

Added **comprehensive checks** before creating users:

### 1. Check Auth Users First

```typescript
// Check if user already exists in auth.users by email
const { data: existingAuthUsers } = await supabase.auth.admin.listUsers();

const existingUser = existingAuthUsers.users.find((u: any) => u.email === email);
if (existingUser) {
  console.log(`⚠️ Auth user already exists, using existing user`);
  authUserId = existingUser.id;
}
```

### 2. Only Create Auth User If Needed

```typescript
if (!authUserId) {
  // Create new auth user
  const { data: newAuthUser } = await supabase.auth.admin.createUser({...});
  authUserId = newAuthUser.user.id;
}
```

### 3. Check Profile Before Creating

```typescript
// Check if profile already exists for this user ID
const { data: existingProfile } = await supabase
  .from('profiles')
  .select('*')
  .eq('id', authUserId)
  .maybeSingle();

if (existingProfile) {
  console.log(`ℹ️ Profile already exists, skipping creation`);
  return { userId: authUserId, email, password };
}
```

### 4. Better Cleanup on Failure

```typescript
if (profileError) {
  // Only clean up if we JUST created this auth user
  if (!existingAuthUsers?.users?.find((u: any) => u.id === authUserId)) {
    await supabase.auth.admin.deleteUser(authUserId);
  }
  throw new Error(`Profile creation failed`);
}
```

---

## New Logic Flow

```
1. Check if auth user exists with this email
   - If YES: Use existing auth user ID
   - If NO: Create new auth user

2. Check if profile exists for this user ID
   - If YES: Skip profile creation, return existing user
   - If NO: Create profile

3. If profile creation fails:
   - Only clean up auth user if we just created it
   - Don't try to delete pre-existing auth users
```

---

## What This Fixes

✅ **No more primary key conflicts** - checks before creating  
✅ **Handles orphaned profiles** - reuses existing profiles  
✅ **Handles failed cleanups** - doesn't try to recreate conflicting users  
✅ **Idempotent operations** - can safely retry failed syncs  
✅ **Better error recovery** - smarter cleanup logic  

---

## Scenarios Fixed

### Scenario 1: Clean First-Time Sync
```
Input: New organization "LAPO MFB IKEJA 1" (never synced before)

Flow:
1. Check auth.users → No user with this email ✅
2. Create new auth user ✅
3. Check profiles → No profile with this user ID ✅
4. Create new profile ✅

Result: SUCCESS - Organization created with new user
```

### Scenario 2: Retry After Failed Sync
```
Input: Organization "LAPO MFB IKEJA 1" (failed on first attempt)
State: Auth user exists, but profile creation failed previously

Flow:
1. Check auth.users → User EXISTS with email ✅
2. Use existing auth user ID (skip creation) ✅
3. Check profiles → No profile found (previous creation failed) ✅
4. Create profile with existing auth user ID ✅

Result: SUCCESS - Profile created for existing auth user
```

### Scenario 3: Orphaned Profile (Worst Case)
```
Input: Organization "LAPO MFB IKEJA 1"
State: Both auth user AND profile exist (orphaned from previous sync)

Flow:
1. Check auth.users → User EXISTS ✅
2. Use existing auth user ID ✅
3. Check profiles → Profile EXISTS ✅
4. Skip profile creation, return existing user ✅

Result: SUCCESS - Reuses existing user, no duplication
```

### Scenario 4: Multiple Sync Retries
```
Input: Same organization synced 5 times in a row

Flow (every time):
1. Check auth.users → User EXISTS ✅
2. Check profiles → Profile EXISTS ✅
3. Skip all creation, return existing user ✅

Result: SUCCESS - Safe to retry unlimited times
```

---

## Technical Details

### Primary Key in Profiles Table

```sql
profiles (
  id UUID PRIMARY KEY,  -- Same as auth.users.id (one-to-one relationship)
  email TEXT UNIQUE,    -- Separate unique constraint
  ...
)
```

The `profiles_pkey` constraint is on the `id` column (UUID), which must match the user's auth.users.id.

### Why Email Check Is Not Enough

Checking only the email can miss cases where:
- Auth user was deleted but profile remains (orphaned profile)
- Profile was created with different email than auth.users
- Email was updated in auth.users but not in profiles

**Solution**: Check both by email (for auth.users) AND by ID (for profiles).

---

## Code Changes Summary

### Added Functions

1. **Check existing auth users by email**
   ```typescript
   const { data: existingAuthUsers } = await supabase.auth.admin.listUsers();
   const existingUser = existingAuthUsers.users.find(u => u.email === email);
   ```

2. **Check existing profile by user ID**
   ```typescript
   const { data: existingProfile } = await supabase
     .from('profiles')
     .select('*')
     .eq('id', authUserId)
     .maybeSingle();
   ```

3. **Conditional auth user creation**
   ```typescript
   if (!authUserId) {
     // Only create if doesn't exist
   }
   ```

4. **Smarter cleanup on failure**
   ```typescript
   if (!existingAuthUsers?.users?.find(u => u.id === authUserId)) {
     // Only clean up newly created users
   }
   ```

---

## Testing

You can now safely:

1. **Sync new organizations** - no primary key conflicts
2. **Retry failed syncs** - system recovers gracefully
3. **Sync multiple times** - idempotent, no errors
4. **Handle edge cases** - orphaned profiles, failed cleanups, etc.

### Test Command

```bash
POST https://[project-ref].supabase.co/functions/v1/external-csv-sync

{
  "token": "your-token",
  "secret_key": "your-secret",
  "application_name": "Atmosfair ERP System",
  "csv_data": "partner_id,partner_name,email\nE49196,LAPO MFB IKEJA 1,N/A"
}
```

**Expected Log Output (First Sync):**

```
📧 ========== EMAIL DETERMINATION ==========
⚠️ Invalid email provided (N/A), generated dummy email: lapo_mfb_ikeja_1_E49196@atmosfair.site
✅ New auth user created with ID: abc-123-def-456
📝 Creating profile for user ID: abc-123-def-456
✅ Profile created successfully for user: abc-123-def-456
```

**Expected Log Output (Retry After Failure):**

```
📧 ========== EMAIL DETERMINATION ==========
⚠️ Auth user already exists with this email (ID: abc-123-def-456), using existing user
ℹ️ Profile already exists for user ID: abc-123-def-456, skipping profile creation
```

**Expected Log Output (Clean Retry - Profile Missing):**

```
⚠️ Auth user already exists with this email (ID: abc-123-def-456), using existing user
📝 Creating profile for user ID: abc-123-def-456
✅ Profile created successfully for user: abc-123-def-456
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

## Comparison with Previous Fix

### Previous Fix (DUPLICATE_USER_FIX.md)
- Fixed: `duplicate key value violates unique constraint "profiles_email_key"`
- Issue: Trying to create user for existing organization
- Solution: Check if organization already has a user

### This Fix (PRIMARY_KEY_CONFLICT_FIX.md)
- Fixed: `duplicate key value violates unique constraint "profiles_pkey"`
- Issue: UUID conflicts from failed syncs or orphaned profiles
- Solution: Check both auth.users (by email) and profiles (by ID) before creating

**Both fixes work together** to ensure:
1. No duplicate users for same organization
2. No UUID conflicts from failed syncs
3. Complete idempotency and retry safety

---

## Summary

This fix resolves the `profiles_pkey` (primary key) constraint violation by:

1. **Checking auth.users** before creating auth user (reuses existing)
2. **Checking profiles table** before creating profile (skips if exists)
3. **Smart cleanup** on failure (only deletes newly created users)
4. **Idempotent operations** (safe to retry unlimited times)

The system now gracefully handles:
- First-time syncs
- Failed sync retries
- Orphaned profiles
- Partial failures
- Multiple sync attempts

**You can now sync "LAPO MFB IKEJA 1" and any other organization safely!** 🎉

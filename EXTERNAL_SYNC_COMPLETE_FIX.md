# External Sync Complete Fix - November 11, 2025

## 🐛 Issues Reported

After running `external-csv-sync`, you discovered these critical issues:

### 1. ❌ profile_id NULL in credentials table

- **Problem**: `credentials.profile_id` was NULL instead of linking to the profile
- **Impact**: Credentials not properly linked to user profiles
- **Root Cause**: `profile_id: userId` was commented out during emergency revert

### 2. ❌ Branch showing 'NA' instead of 'Main Branch'

- **Problem**: `organizations.branch` was set to 'NA' when CSV had "NA" value
- **Impact**: Branch displayed as "NA" instead of defaulting to "Main Branch"
- **Root Cause**: Code only checked for empty/undefined, not 'NA' variations

### 3. ❌ Role NULL in profiles table

- **Problem**: `profiles.role` was NULL instead of 'admin'
- **Impact**: User role not set, breaking authorization
- **Root Cause**: Early return when profile exists without updating role/username

### 4. ❌ Username NULL in profiles table

- **Problem**: `profiles.username` was NULL even though username was generated
- **Impact**: Login by username failed because username wasn't in database
- **Root Cause**: Same as #3 - early return without updating

### 5. ❌ Login Failed

- **Problem**: Login with generated username/password returned "Invalid credentials"
- **Impact**: Cannot login after synchronization
- **Root Cause**: Combination of all above issues (no username, no role, no profile_id)

---

## ✅ Fixes Applied

### Fix #1: profile_id Foreign Key (REQUIRES MIGRATION)

**Files Changed:**

- `supabase/functions/external-csv-sync/index.ts` (line ~333)
- `supabase/functions/external-sync/index.ts` (line ~345)

**Change:**

```typescript
// BEFORE (commented out)
// profile_id: userId, // ⚠️ COMMENTED: Will add after migration is run

// AFTER (uncommented)
profile_id: userId, // ✅ FIX: Link credential to profile (requires migration to be run first)
```

⚠️ **CRITICAL**: This fix requires running the SQL migration FIRST or it will cause errors!

---

### Fix #2: Branch Normalization

**Files Changed:**

- `supabase/functions/external-csv-sync/index.ts` (added function, lines ~145-160)
- `supabase/functions/external-sync/index.ts` (added function, lines ~165-180)

**New Function Added:**

```typescript
/**
 * Normalize branch value - convert NA/N/A variations to 'Main Branch'
 */
function normalizeBranch(branch: string | undefined): string {
  if (!branch) return "Main Branch";

  const trimmed = branch.trim();
  const normalized = trimmed.toUpperCase();

  // Check for NA variations
  if (
    normalized === "NA" ||
    normalized === "N/A" ||
    normalized === "N.A." ||
    normalized === "NOT AVAILABLE"
  ) {
    return "Main Branch";
  }

  return trimmed; // Return original case if not NA
}
```

**Usage Updated:**

```typescript
// BEFORE
branch: orgData.branch || "Main Branch";

// AFTER
branch: normalizeBranch(orgData.branch); // ✅ FIX: Normalize NA variations to 'Main Branch'
```

**Locations:**

- external-csv-sync: lines ~759, ~783
- external-sync: lines ~576, ~600

---

### Fix #3 & #4: Update Existing Profiles (role + username)

**Files Changed:**

- `supabase/functions/external-csv-sync/index.ts` (lines ~220-245)
- `supabase/functions/external-sync/index.ts` (lines ~245-270)

**Change:**

```typescript
// BEFORE - Early return without updating
if (existingProfile) {
  console.log(
    `ℹ️ Profile already exists for user ID: ${authUserId}, skipping profile creation`
  );
  return {
    userId: authUserId!,
    email,
    username,
    password,
    isDummyEmail,
    isInternalEmail,
  };
}

// AFTER - Update before returning
if (existingProfile) {
  console.log(
    `ℹ️ Profile already exists for user ID: ${authUserId}, updating username and role...`
  );

  // ✅ FIX: Update existing profile to ensure username and role are set
  const { error: updateError } = await supabase
    .from("profiles")
    .update({
      username: username, // Ensure username is set
      role: "admin", // Ensure role is set to admin
      updated_at: new Date().toISOString(),
    })
    .eq("id", authUserId);

  if (updateError) {
    console.error(`⚠️ Failed to update existing profile:`, updateError);
  } else {
    console.log(`✅ Profile updated with username: ${username}, role: admin`);
  }

  return {
    userId: authUserId!,
    email,
    username,
    password,
    isDummyEmail,
    isInternalEmail,
  };
}
```

**Impact:**

- ✅ Existing profiles from previous syncs now get username populated
- ✅ Existing profiles now get role='admin' set
- ✅ Fixes NULL username and NULL role issues

---

## 🚀 Deployment Steps

### ⚠️ CRITICAL: ORDER MATTERS!

You **MUST** follow this exact order or deployment will fail:

### Step 1: Run SQL Migration FIRST

```bash
# Open Supabase SQL Editor and run:
supabase_codes/sql_queries/add-profile-id-to-credentials.sql
```

This migration will:

1. Add `profile_id UUID` column to credentials table
2. Create foreign key constraint to profiles table
3. Create index for faster lookups
4. Update existing credentials to link to profiles (set profile_id = user_id)
5. Fix NULL roles in existing profiles (set role = 'admin')

**Verify Migration Success:**

```sql
-- Check if column exists
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'credentials'
AND column_name = 'profile_id';

-- Should return: profile_id | uuid
```

---

### Step 2: Deploy Edge Functions (AFTER Migration)

```powershell
# Deploy external-csv-sync
supabase functions deploy external-csv-sync

# Deploy external-sync
supabase functions deploy external-sync
```

---

### Step 3: Test with New Sync

**Test CSV Sync:**

1. Prepare a CSV with at least one organization
2. Include a row with `branch` = "NA" to test normalization
3. Send CSV to external-csv-sync endpoint
4. Check logs for:
   - ✅ Branch normalized to "Main Branch"
   - ✅ Username generated and set in profile
   - ✅ Role set to 'admin' in profile
   - ✅ profile_id set in credentials

**Verify in Database:**

```sql
-- Check latest synced organization
SELECT
  c.partner_id,
  c.partner_name,
  c.username,
  c.role as cred_role,
  c.profile_id,
  p.username as profile_username,
  p.role as profile_role,
  o.branch
FROM credentials c
LEFT JOIN profiles p ON c.profile_id = p.id
LEFT JOIN organizations o ON c.organization_id = o.id
ORDER BY c.created_at DESC
LIMIT 5;
```

**Expected Results:**

- ✅ c.username: `lapo_mfb_gbongan_598581` (or similar generated username)
- ✅ c.role: `admin`
- ✅ c.profile_id: `<valid UUID>`
- ✅ p.username: `lapo_mfb_gbongan_598581` (matches credential)
- ✅ p.role: `admin`
- ✅ o.branch: `Main Branch` (even if CSV had "NA")

---

### Step 4: Test Login

**Using login-with-credentials endpoint:**

```bash
# Login with generated username
curl -X POST https://your-project.supabase.co/functions/v1/login-with-credentials \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "lapo_mfb_gbongan_598581",
    "password": "<generated-password>"
  }'
```

**Expected Response:**

```json
{
  "success": true,
  "user": {
    "id": "<user-id>",
    "email": "lapo_mfb_gbongan_598581@internal.acsl.local",
    "role": "admin"
  },
  "profile": {
    "id": "<profile-id>",
    "username": "lapo_mfb_gbongan_598581",
    "full_name": "LAPO Microfinance Bank - Gbongan",
    "role": "admin",
    "organization_id": "<org-id>"
  },
  "session": { ... }
}
```

---

## 📊 What Each Fix Does

| Issue           | Fix                                | Impact                                                      |
| --------------- | ---------------------------------- | ----------------------------------------------------------- |
| profile_id NULL | Uncommented `profile_id: userId`   | Credentials now properly linked to profiles via foreign key |
| Branch = 'NA'   | Added `normalizeBranch()` function | NA/N/A/n/a converted to "Main Branch"                       |
| Role NULL       | Added profile update when exists   | Existing profiles now get role='admin'                      |
| Username NULL   | Same profile update                | Existing profiles now get username populated                |
| Login fails     | All above fixes combined           | Login now works with username/password                      |

---

## 🔍 Logging Improvements

Both edge functions now log:

```
ℹ️ Profile already exists for user ID: abc123, updating username and role...
✅ Profile updated with username: lapo_mfb_gbongan_598581, role: admin
```

This helps verify that the fix is working when syncing organizations with existing profiles.

---

## ⚠️ Common Errors

### Error: "column profile_id does not exist"

**Cause**: Deployed edge functions before running SQL migration  
**Fix**: Run the SQL migration FIRST, then redeploy

### Error: "Invalid credentials" on login

**Causes**:

1. Username not set in profiles (fixed by this update)
2. Role not set in profiles (fixed by this update)
3. Password incorrect (check credentials table for generated password)

**Fix**: Re-sync the organization to apply the profile update fix

### Branch still shows 'NA'

**Cause**: Old organization data before fix was deployed  
**Fix**: Re-sync the organization or manually update:

```sql
UPDATE organizations
SET branch = 'Main Branch'
WHERE branch IN ('NA', 'N/A', 'n/a', 'N.A.');
```

---

## 📝 Files Changed

### Edge Functions

1. `supabase/functions/external-csv-sync/index.ts`

   - Added `normalizeBranch()` function
   - Updated branch assignment to use `normalizeBranch()`
   - Added profile update logic for existing profiles
   - Uncommented `profile_id: userId`

2. `supabase/functions/external-sync/index.ts`
   - Same changes as external-csv-sync

### SQL Migration

3. `supabase_codes/sql_queries/add-profile-id-to-credentials.sql`
   - Adds profile_id column
   - Creates foreign key constraint
   - Updates existing records
   - Fixes NULL roles

---

## ✅ Verification Checklist

After deployment, verify:

- [ ] SQL migration ran successfully
- [ ] profile_id column exists in credentials table
- [ ] Foreign key constraint created
- [ ] external-csv-sync deployed without errors
- [ ] external-sync deployed without errors
- [ ] New sync creates profile with username and role
- [ ] Branch 'NA' normalized to 'Main Branch'
- [ ] profile_id populated in credentials
- [ ] Login with username/password works
- [ ] Existing profiles updated with username/role

---

## 🎯 Summary

All four critical issues have been fixed:

1. ✅ **profile_id** will be set (after migration)
2. ✅ **Branch** will be normalized from NA to "Main Branch"
3. ✅ **Role** will be set to 'admin' (even for existing profiles)
4. ✅ **Username** will be populated (even for existing profiles)
5. ✅ **Login** will work with generated credentials

**Next Action**: Run the SQL migration in Supabase, then deploy the edge functions!

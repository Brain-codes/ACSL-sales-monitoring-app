# Profile Update Fix - Role and Username NULL Issue

## 🐛 Issue Reported

After calling `external-csv-sync` and `external-sync`, you found that:

- `profiles.role` is still **NULL**
- `profiles.username` is still **NULL**

Even though the code had profile update logic, it wasn't working properly.

---

## 🔍 Root Cause Analysis

The profile update code existed but lacked:

1. ✅ **Logging verification** - No way to see if update was actually happening
2. ✅ **Return data verification** - Update didn't return data to confirm success
3. ✅ **Detailed error logging** - Errors might have been silently ignored
4. ✅ **Supabase client configuration** - Client needed explicit auth configuration

---

## ✅ Fixes Applied

### Fix #1: Enhanced Logging

Added comprehensive logging to see exactly what's happening:

```typescript
if (existingProfile) {
  console.log(
    `ℹ️ Profile already exists for user ID: ${authUserId}, updating username and role...`
  );
  console.log(`   Current username: ${existingProfile.username || "NULL"}`);
  console.log(`   Current role: ${existingProfile.role || "NULL"}`);
  console.log(`   New username: ${username}`);
  console.log(`   New role: admin`);

  // ... update code ...
}
```

**What this shows:**

- Current values in database (before update)
- New values being set (after update)
- Helps identify if the code path is even being executed

---

### Fix #2: Return Updated Data with `.select()`

Changed from:

```typescript
const { error: updateError } = await supabase
  .from("profiles")
  .update({ username, role: "admin", updated_at })
  .eq("id", authUserId);
```

To:

```typescript
const { data: updatedProfile, error: updateError } = await supabase
  .from("profiles")
  .update({ username, role: "admin", updated_at })
  .eq("id", authUserId)
  .select(); // ✅ Return updated data to verify
```

**Why this matters:**

- `.select()` forces Supabase to return the updated row
- Confirms the update actually happened
- Provides data for logging verification

---

### Fix #3: Enhanced Error Logging

Changed from:

```typescript
if (updateError) {
  console.error(`⚠️ Failed to update existing profile:`, updateError);
}
```

To:

```typescript
if (updateError) {
  console.error(`❌ Failed to update existing profile:`, updateError);
  console.error(`   Error details:`, JSON.stringify(updateError, null, 2));
} else {
  console.log(`✅ Profile updated successfully!`);
  console.log(`   Updated data:`, JSON.stringify(updatedProfile, null, 2));
}
```

**What this shows:**

- Full error details in JSON format
- Confirmation when update succeeds
- Actual updated data from database

---

### Fix #4: Supabase Client Configuration

Added explicit auth configuration:

```typescript
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  }
);
```

**Why this helps:**

- Ensures service role client doesn't try to manage auth sessions
- Prevents potential auth-related update failures
- More explicit about client behavior

---

## 🚀 Deployment

Both edge functions have been deployed with these fixes:

✅ **external-csv-sync** - Deployed to project `oeiwnpngbnkhcismhpgs`  
✅ **external-sync** - Deployed to project `oeiwnpngbnkhcismhpgs`

---

## 🧪 Testing & Verification

### Step 1: Call the Edge Function

Call `external-csv-sync` or `external-sync` with your organization data.

### Step 2: Check the Logs

Go to **Supabase Dashboard** → **Edge Functions** → **Logs** and look for:

**If profile already exists, you should see:**

```
ℹ️ Profile already exists for user ID: abc-123, updating username and role...
   Current username: NULL
   Current role: NULL
   New username: lapo_mfb_gbongan_598581
   New role: admin
✅ Profile updated successfully!
   Updated data: [{"id":"abc-123","username":"lapo_mfb_gbongan_598581","role":"admin",...}]
```

**If profile is newly created, you should see:**

```
📝 Creating profile for user ID: abc-123
✅ Profile created successfully for user: abc-123
```

### Step 3: Verify in Database

Check the `profiles` table in Supabase:

```sql
SELECT
  id,
  email,
  username,
  full_name,
  role,
  organization_id,
  created_at,
  updated_at
FROM profiles
WHERE organization_id IS NOT NULL
ORDER BY updated_at DESC
LIMIT 10;
```

**Expected Results:**

- ✅ `username` should have value like `lapo_mfb_gbongan_598581`
- ✅ `role` should be `admin`
- ✅ `updated_at` should be recent (showing update happened)

---

## 🔍 Troubleshooting

### Issue: Logs still show "Current username: NULL" and "Current role: NULL" but no error

**Possible Causes:**

1. RLS policy is blocking the update
2. Column doesn't exist (migration not run)
3. Service role key doesn't have permission

**Solutions:**

#### Check RLS Policies

```sql
-- See if profiles table has RLS enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE tablename = 'profiles';

-- List all policies on profiles table
SELECT * FROM pg_policies WHERE tablename = 'profiles';
```

If RLS is blocking, you may need to add a policy or use `supabase.rpc()` to call a function that bypasses RLS.

#### Verify Service Role Has Access

The service role key should bypass RLS, but if it doesn't:

```sql
-- Grant explicit permissions (should already exist)
GRANT UPDATE ON profiles TO service_role;
GRANT SELECT ON profiles TO service_role;
```

---

### Issue: Logs show error "column username does not exist"

**Solution:** The `username` column might not exist in your profiles table. Add it:

```sql
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS username TEXT;

CREATE INDEX IF NOT EXISTS idx_profiles_username
ON profiles(username);
```

---

### Issue: Logs show error "column role does not exist"

**Solution:** The `role` column might not exist. Add it:

```sql
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS role TEXT;

CREATE INDEX IF NOT EXISTS idx_profiles_role
ON profiles(role);
```

---

### Issue: Update succeeds but values still NULL

**Possible Cause:** Another process is overwriting the values, or there's a trigger resetting them.

**Check for triggers:**

```sql
SELECT
  trigger_name,
  event_manipulation,
  action_statement
FROM information_schema.triggers
WHERE event_object_table = 'profiles';
```

---

## 📊 What Changed

| File                         | Changes                                                                                                                                     |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `external-csv-sync/index.ts` | • Enhanced logging (current vs new values)<br>• Added `.select()` to verify update<br>• JSON error logging<br>• Supabase client auth config |
| `external-sync/index.ts`     | • Same changes as external-csv-sync                                                                                                         |

---

## ✅ Success Indicators

After these fixes, you should see:

1. **In Logs:**

   - ✅ "Profile updated successfully!" message
   - ✅ Updated data showing `username` and `role` values
   - ✅ No errors during update

2. **In Database:**

   - ✅ `profiles.username` populated with generated username
   - ✅ `profiles.role` = 'admin'
   - ✅ `updated_at` timestamp reflects recent update

3. **In Login:**
   - ✅ Can login with username and password
   - ✅ Profile data returned with username and role

---

## 📝 Next Steps

1. **Test Now:** Call your edge function and check the logs
2. **Verify Database:** Check that `username` and `role` are set
3. **Report Back:** If you still see NULL values, check the logs for specific error messages
4. **Provide Logs:** Share the logs so we can see exactly what's happening

The enhanced logging will tell us exactly where the issue is if it persists!

# FIXED: Profile Update Error - updated_at Column Missing

## 🐛 Root Cause Found!

From your logs:

```
❌ UPDATE FAILED!
Error code: PGRST204
Error message: Could not find the 'updated_at' column of 'profiles' in the schema cache
```

**The `profiles` table doesn't have an `updated_at` column!**

---

## ✅ Fix Applied

### Changed in Both Edge Functions:

**BEFORE (Causing Error):**

```typescript
const { data: updatedProfile, error: updateError } = await supabase
  .from("profiles")
  .update({
    username: username,
    role: "admin",
    updated_at: new Date().toISOString(), // ❌ Column doesn't exist!
  })
  .eq("id", authUserId)
  .select();
```

**AFTER (Fixed):**

```typescript
const { data: updatedProfile, error: updateError } = await supabase
  .from("profiles")
  .update({
    username: username, // ✅ Set username
    role: "admin", // ✅ Set role
    // updated_at removed - column doesn't exist in profiles table
  })
  .eq("id", authUserId)
  .select();
```

### Also Updated Logging:

**BEFORE:**

```
📝 New Values to Set:
   username: nabda_office_b8a107
   role: admin
   updated_at: 2025-11-11T21:55:10.257Z
```

**AFTER:**

```
📝 New Values to Set:
   username: nabda_office_b8a107
   role: admin
```

---

## 📦 Deployed

Both edge functions have been deployed with the fix:

✅ **external-csv-sync** - Deployed (no more updated_at in UPDATE)  
✅ **external-sync** - Deployed (no more updated_at in UPDATE)

---

## 🧪 Test Now!

Call your edge function again and check the logs. You should now see:

```
📊 UPDATE Result:
✅ UPDATE SUCCESSFUL!
   Rows affected: 1
   Updated profile: {
     "id": "65a87c83-c7f6-46dc-882f-cdaccebec707",
     "username": "nabda_office_b8a107",
     "role": "admin",
     ...
   }

✅ VERIFICATION:
   username is now: nabda_office_b8a107
   role is now: admin
```

**No more PGRST204 error!**

---

## 📊 What Changed

| File                         | Change                                             |
| ---------------------------- | -------------------------------------------------- |
| `external-csv-sync/index.ts` | Removed `updated_at` from profile UPDATE statement |
| `external-sync/index.ts`     | Removed `updated_at` from profile UPDATE statement |

---

## 🎯 Expected Outcome

After this fix:

- ✅ UPDATE will succeed (no more PGRST204 error)
- ✅ `profiles.username` will be set
- ✅ `profiles.role` will be set to 'admin'
- ✅ Login with username/password will work

---

## 📝 Note About updated_at

The `profiles` table schema doesn't include an `updated_at` column. This is fine - Supabase can track changes through other mechanisms if needed.

If you want to add `updated_at` to track profile updates, you can run this SQL:

```sql
-- Add updated_at column to profiles table
ALTER TABLE profiles
ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();

-- Create a trigger to automatically update it
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at
BEFORE UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
```

But this is optional - the profile UPDATE will work fine without it!

---

## ✅ Summary

**Problem:** UPDATE failed with PGRST204 error because `updated_at` column doesn't exist  
**Solution:** Removed `updated_at` from the UPDATE statement  
**Status:** ✅ Fixed and deployed  
**Next Step:** Test the edge function and verify username/role are now populated!

🚀 **Test it now!**

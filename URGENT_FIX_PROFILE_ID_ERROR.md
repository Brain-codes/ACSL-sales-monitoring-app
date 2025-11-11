# URGENT FIX - Profile_id Column Error ✅

## 🚨 WHAT HAPPENED

Your frontend dev was getting errors when calling `external-csv-sync` endpoint.

**The Error:**

```
column "profile_id" of relation "credentials" does not exist
```

---

## 🐛 ROOT CAUSE

I made a mistake in the deployment order! Here's what happened:

### **What I Did (WRONG ORDER):**

1. ✅ Created SQL migration to add `profile_id` column
2. ✅ Updated edge functions to use `profile_id`
3. ✅ **Deployed edge functions** → LIVE NOW
4. ❌ **Did NOT run SQL migration** → Column doesn't exist!

**Result:** Edge functions try to insert `profile_id` but the column doesn't exist in the database → ERROR!

---

## ✅ IMMEDIATE FIX (DEPLOYED)

I've **reverted both edge functions** and **redeployed**:

### Changed Line (in both external-sync and external-csv-sync):

**Before (BROKEN):**

```typescript
const { error } = await supabase.from("credentials").insert({
  partner_id: partnerId,
  partner_name: partnerName,
  email: email,
  username: username,
  password: password,
  organization_id: organizationId,
  user_id: userId,
  profile_id: userId, // ❌ This breaks because column doesn't exist!
  role: "admin",
  ...
});
```

**After (FIXED):**

```typescript
const { error } = await supabase.from("credentials").insert({
  partner_id: partnerId,
  partner_name: partnerName,
  email: email,
  username: username,
  password: password,
  organization_id: organizationId,
  user_id: userId,
  // profile_id: userId, // ⚠️ COMMENTED: Will add after migration is run
  role: "admin",
  ...
});
```

### **Status:**

- ✅ external-csv-sync - DEPLOYED (profile_id removed)
- ✅ external-sync - DEPLOYED (profile_id removed)

**Your frontend dev can now call the endpoint without errors!** 🎉

---

## 📋 CORRECT DEPLOYMENT ORDER

Here's the **RIGHT way** to do database schema changes:

### **Step 1: Run SQL Migration FIRST**

```sql
-- In Supabase SQL Editor
-- Run: supabase_codes/sql_queries/add-profile-id-to-credentials.sql

ALTER TABLE credentials
ADD COLUMN IF NOT EXISTS profile_id UUID;

ALTER TABLE credentials
ADD CONSTRAINT fk_credentials_profile
FOREIGN KEY (profile_id)
REFERENCES profiles(id)
ON DELETE CASCADE;
```

### **Step 2: Verify Column Exists**

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'credentials'
  AND column_name = 'profile_id';

-- Expected: 1 row showing profile_id | uuid
```

### **Step 3: THEN Update & Deploy Edge Functions**

```typescript
// Only after Step 1 & 2 are complete!
profile_id: userId,  // Now safe to use
```

---

## 🔄 WHEN YOU'RE READY TO ADD profile_id

When you want to properly add the `profile_id` column:

### **1. Run the SQL Migration**

Go to: `https://supabase.com/dashboard/project/oeiwnpngbnkhcismhpgs/sql/new`

Run the entire file:

```
supabase_codes/sql_queries/add-profile-id-to-credentials.sql
```

### **2. Uncomment profile_id in Edge Functions**

In both files:

- `supabase/functions/external-csv-sync/index.ts`
- `supabase/functions/external-sync/index.ts`

**Find this line:**

```typescript
// profile_id: userId, // ⚠️ COMMENTED: Will add after migration is run
```

**Change to:**

```typescript
profile_id: userId, // ✅ Safe now - column exists
```

### **3. Deploy Edge Functions**

```powershell
supabase functions deploy external-csv-sync
supabase functions deploy external-sync
```

### **4. Test**

```sql
-- Verify new records have profile_id
SELECT partner_id, profile_id
FROM credentials
WHERE created_at > NOW() - INTERVAL '1 hour';
-- Should see profile_id populated
```

---

## ⚠️ LESSON LEARNED

**Always follow this order for database changes:**

1. **Database schema changes** (ALTER TABLE, CREATE TABLE, etc.)
2. **Verify changes** (check column exists)
3. **Code changes** (edge functions, app code)
4. **Deploy code**
5. **Test**

**Never deploy code that depends on database changes before the database is updated!**

---

## ✅ CURRENT STATUS

### **Right Now:**

- ✅ Edge functions work (profile_id commented out)
- ✅ Frontend dev can call endpoint without errors
- ✅ All existing functionality preserved
- ⏳ profile_id migration ready but NOT applied yet

### **Next Steps (When Ready):**

1. Run SQL migration in Supabase
2. Uncomment profile_id in edge functions
3. Deploy edge functions
4. Test thoroughly

---

## 📝 SUMMARY

**What broke:**

- I added `profile_id` to edge function inserts
- But database column doesn't exist yet
- Result: Column "profile_id" does not exist error

**What I fixed:**

- Commented out `profile_id` in both edge functions
- Deployed fixed versions immediately
- Edge functions work again

**What to do next:**

- When ready, run SQL migration FIRST
- Then uncomment and deploy edge functions
- Never reverse this order!

**Your frontend dev should be good now! 🚀**

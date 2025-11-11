# Quick Troubleshooting Checklist - Manage Credentials 401 Error

## 🚀 How to View Logs

**Supabase Dashboard:**
https://supabase.com/dashboard/project/oeiwnpngbnkhcismhpgs/logs/edge-functions

Click on `manage-credentials` → View logs in real-time

**OR via CLI:**

```powershell
supabase functions logs manage-credentials --tail
```

---

## ✅ Checklist - What to Look for in Logs

### 1. Is Authorization Header Present?

```
Look for: 📋 Authorization header present: true/false
```

- [ ] ✅ **true** → Go to Step 2
- [ ] ❌ **false** → **FIX:** Frontend must send `Authorization: Bearer <token>` header

---

### 2. Is Token Format Correct?

```
Look for: 🔑 Authorization header format: Bearer eyJhbGc...
```

- [ ] ✅ **"Bearer ..."** → Go to Step 3
- [ ] ❌ **No "Bearer "** → **FIX:** Add "Bearer " prefix to token

---

### 3. Is User Authenticated?

```
Look for: ✅ User authenticated: user-uuid
OR
Look for: ❌ Auth error: JWT expired / Invalid JWT
```

- [ ] ✅ **User authenticated** → Go to Step 4
- [ ] ❌ **JWT expired** → **FIX:** Refresh token or re-login
- [ ] ❌ **Invalid JWT** → **FIX:** Use valid token from login response

---

### 4. Is Profile Found?

```
Look for: ✅ Profile found: user-uuid
OR
Look for: ❌ No profile found for user: user-uuid
```

- [ ] ✅ **Profile found** → Go to Step 5
- [ ] ❌ **No profile found** → **FIX:** User exists in auth but has no profile in database

**SQL Fix:**

```sql
-- Check if profile exists
SELECT id, email, role FROM profiles WHERE id = 'user-uuid';

-- If missing, create profile
INSERT INTO profiles (id, email, full_name, role)
VALUES ('user-uuid', 'user@example.com', 'User Name', 'super_admin');
```

---

### 5. Is User Super Admin?

```
Look for: 🎭 User role: super_admin
OR
Look for: ❌ Access denied - User role is: admin/agent
```

- [ ] ✅ **User role: super_admin** → Should work! Check Step 6
- [ ] ❌ **User role: admin/agent** → **FIX:** Update user role to super_admin

**SQL Fix:**

```sql
-- Update user role to super_admin
UPDATE profiles
SET role = 'super_admin'
WHERE id = 'user-uuid';
```

---

### 6. Check Full Request Log

If all above pass but still getting 401, look for:

```
Look for: ✅ Super Admin verified successfully!
AND
Look for: ✅ Request processed successfully
```

If you see these but still get 401, check:

- [ ] Response status in logs
- [ ] CORS headers
- [ ] Frontend error handling

---

## 🔍 Common Scenarios

### Scenario A: Frontend Not Sending Token

**Log Output:**

```
📋 Authorization header present: false
```

**Fix:** Add Authorization header in frontend:

```javascript
headers: {
  'Authorization': `Bearer ${token}`
}
```

---

### Scenario B: Token Expired

**Log Output:**

```
👤 Attempting to get user from token...
❌ Auth error: JWT expired
```

**Fix:** Implement token refresh or re-login flow

---

### Scenario C: User is Regular Admin, Not Super Admin

**Log Output:**

```
🎭 User role: admin
❌ Access denied - User role is: admin
```

**Fix:** Run SQL to update role:

```sql
UPDATE profiles SET role = 'super_admin' WHERE email = 'admin@example.com';
```

---

### Scenario D: User Has No Profile

**Log Output:**

```
✅ User authenticated: abc-123
❌ No profile found for user: abc-123
```

**Fix:** Create profile with super_admin role:

```sql
INSERT INTO profiles (id, email, full_name, role)
SELECT
  auth.users.id,
  auth.users.email,
  auth.users.raw_user_meta_data->>'full_name',
  'super_admin'
FROM auth.users
WHERE auth.users.id = 'abc-123';
```

---

## 📝 How to Report Issue

After checking logs, provide:

1. **What you see in logs** (copy the relevant section)
2. **Which checkbox failed** (from checklist above)
3. **User details:**
   - Email: ******\_\_\_******
   - Expected role: super_admin
   - Actual role: ******\_\_\_******

---

## 🎯 Quick Test Commands

### Test 1: Check User Profile

```sql
-- Run in Supabase SQL Editor
SELECT id, email, full_name, role
FROM profiles
WHERE email = 'YOUR_ADMIN_EMAIL';
```

### Test 2: Check All Super Admins

```sql
SELECT id, email, full_name, role
FROM profiles
WHERE role = 'super_admin';
```

### Test 3: Make API Request

```bash
# Replace YOUR_TOKEN with actual token
curl -X GET \
  https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials \
  -H 'Authorization: Bearer YOUR_TOKEN'
```

---

## ✅ Expected Success Log

When everything works correctly, you should see:

```
================================================================================
🔐 Manage Credentials Request Received
📅 Timestamp: 2025-11-11T10:30:45.123Z
================================================================================
🔍 Starting authentication process...
📋 Authorization header present: true
🔑 Authorization header format: Bearer eyJhbGc...
🔐 Creating Supabase client with token...
👤 Attempting to get user from token...
✅ User authenticated: user-uuid
📧 User email: admin@example.com
🔍 Fetching user profile from database...
✅ Profile found: user-uuid
🎭 User role: super_admin
✅ Super Admin verified successfully!
✅ Authentication successful!
📋 Route matched: GET all credentials
✅ Request processed successfully
================================================================================
```

If you see all these ✅ checkmarks, authentication is working!

---

## 🆘 Still Having Issues?

1. Check logs (they will show exactly where it fails)
2. Complete the checklist above
3. Share the log output and which step failed
4. We'll identify the exact issue!

The logs are very detailed now - they will pinpoint the problem! 🎯

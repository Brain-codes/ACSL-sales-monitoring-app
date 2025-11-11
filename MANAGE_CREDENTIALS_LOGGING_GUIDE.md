# Manage Credentials - Enhanced Logging Guide

## 🎯 Purpose

Added comprehensive logging to the `manage-credentials` edge function to help diagnose authentication issues.

---

## 📊 What Was Added

### 1. **Main Index Handler Logs**

Every request now logs:

- ✅ Timestamp
- ✅ HTTP Method
- ✅ Full URL
- ✅ All request headers
- ✅ Authentication status
- ✅ User details (ID, email, role)

### 2. **Authentication Process Logs**

Step-by-step authentication logging:

- 🔍 Authorization header presence check
- 🔑 Token format verification
- 🌐 Supabase client creation
- 👤 User authentication from token
- 📋 Profile database lookup
- 🎭 Role verification (super_admin check)

### 3. **Route Handler Logs**

Route processing information:

- 📍 Matched route
- 🔍 Query parameters
- 📊 Database operation results
- ✅ Success/failure status

---

## 🔍 How to View Logs

### Option 1: Supabase Dashboard (Real-Time)

1. **Go to Supabase Dashboard:**

   ```
   https://supabase.com/dashboard/project/oeiwnpngbnkhcismhpgs/logs/edge-functions
   ```

2. **Select the function:**

   - Click on `manage-credentials`

3. **View logs in real-time:**
   - Logs appear automatically as requests come in
   - Filter by time range, severity, etc.

### Option 2: CLI Command

```powershell
# View live logs
supabase functions logs manage-credentials --tail

# View recent logs
supabase functions logs manage-credentials --limit 50
```

---

## 📝 Log Output Example

When your frontend makes a request, you'll see:

```
================================================================================
🔐 Manage Credentials Request Received
📅 Timestamp: 2025-11-11T10:30:45.123Z
🌐 Method: GET
🔗 URL: https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials
📋 Headers: {
  "authorization": "Bearer eyJhbGc...",
  "content-type": "application/json",
  ...
}
================================================================================
🔍 Starting authentication...
🔍 Starting authentication process...
📋 Authorization header present: true
🔑 Authorization header format: Bearer eyJhbGciOiJI...
🌐 Supabase URL: https://oeiwnpngbnkhcismhpgs.supabase.co
🔐 Creating Supabase client with token...
👤 Attempting to get user from token...
✅ User authenticated: user-uuid
📧 User email: admin@example.com
🔍 Fetching user profile from database...
✅ Profile found: user-uuid
👤 Profile full name: Admin User
🎭 User role: admin
❌ Access denied - User role is: admin
❌ Required role: super_admin
❌ Authentication failed!
❌ Error: Access denied. Only Super Admin can access this resource.
================================================================================
```

---

## 🐛 Common Issues & What Logs Show

### Issue 1: Missing Authorization Header

**Log Output:**

```
📋 Authorization header present: false
❌ Missing Authorization header
```

**Fix:** Frontend must include `Authorization: Bearer <token>` header

---

### Issue 2: Invalid Token Format

**Log Output:**

```
📋 Authorization header present: true
🔑 Authorization header format: eyJhbGc... (no "Bearer ")
❌ Auth error: Invalid JWT
```

**Fix:** Token must be prefixed with "Bearer "

---

### Issue 3: Expired Token

**Log Output:**

```
👤 Attempting to get user from token...
❌ Auth error: JWT expired
❌ Auth error details: {
  "message": "JWT expired",
  "status": 401
}
```

**Fix:** Use refresh token or ask user to login again

---

### Issue 4: User Not Super Admin

**Log Output:**

```
✅ User authenticated: user-uuid
📧 User email: admin@example.com
🎭 User role: admin
❌ Access denied - User role is: admin
❌ Required role: super_admin
```

**Fix:** User must have role = 'super_admin' in profiles table

---

### Issue 5: Profile Not Found

**Log Output:**

```
✅ User authenticated: user-uuid
🔍 Fetching user profile from database...
❌ Profile fetch error: No rows found
❌ No profile found for user: user-uuid
```

**Fix:** User exists in auth but has no profile in profiles table

---

## 📋 Debugging Steps

### Step 1: Check Request Headers

Look for the headers section in logs:

```
📋 Headers: {
  "authorization": "Bearer eyJhbGc...",  ← Should be present
  "content-type": "application/json"
}
```

### Step 2: Verify Token

Check if token is valid:

```
👤 Attempting to get user from token...
✅ User authenticated: user-uuid  ← Should succeed
```

### Step 3: Check Profile

Verify profile exists and has correct role:

```
✅ Profile found: user-uuid
🎭 User role: super_admin  ← Must be "super_admin"
```

### Step 4: Check Database

If profile not found, check database:

```sql
-- Check if user has a profile
SELECT id, email, role FROM profiles WHERE id = 'user-uuid';

-- Check all super admins
SELECT id, email, full_name, role FROM profiles WHERE role = 'super_admin';
```

---

## 🔧 Testing with Logs

### Test 1: Valid Super Admin Request

```bash
# Make request
curl -X GET \
  https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials \
  -H 'Authorization: Bearer YOUR_TOKEN'

# Check logs - Should see:
# ✅ User authenticated
# ✅ Profile found
# ✅ User role: super_admin
# ✅ Super Admin verified successfully!
# ✅ Request processed successfully
```

### Test 2: Regular Admin Request (Should Fail)

```bash
# Make request with regular admin token
curl -X GET \
  https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials \
  -H 'Authorization: Bearer ADMIN_TOKEN'

# Check logs - Should see:
# ✅ User authenticated
# ✅ Profile found
# 🎭 User role: admin
# ❌ Access denied - User role is: admin
# ❌ Required role: super_admin
```

### Test 3: No Token (Should Fail)

```bash
# Make request without token
curl -X GET \
  https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials

# Check logs - Should see:
# 📋 Authorization header present: false
# ❌ Missing Authorization header
```

---

## 📊 What to Send to Frontend Developer

After your frontend makes a request, check the logs and send them:

1. **Go to Supabase Dashboard:**

   ```
   https://supabase.com/dashboard/project/oeiwnpngbnkhcismhpgs/logs/edge-functions
   ```

2. **Select `manage-credentials`**

3. **Copy the complete log output** for the failed request

4. **Send to frontend developer** - The logs will show exactly where the authentication fails

---

## ✅ Deployment Complete

The enhanced logging is now live!

**Next Steps:**

1. Ask your frontend developer to make a request
2. Check the logs in Supabase Dashboard
3. The logs will show exactly what's failing:
   - Missing header?
   - Invalid token?
   - Expired token?
   - Wrong role?

The detailed logs will pinpoint the exact issue! 🎯

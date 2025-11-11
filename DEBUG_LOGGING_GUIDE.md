# Debug Logging Guide - External Sync API

## ✅ Comprehensive Logging Added

Both edge functions (`external-sync` and `external-csv-sync`) now have detailed logging to help debug the email validation issue.

## 📋 What's Been Logged

### 1. **Request Data (external-sync)**

```
📥 ========== REQUEST RECEIVED ==========
Application: Atmosfair ERP System
Organization Data: {
  "partner_id": "...",
  "partner_name": "...",
  "email": "...",
  ...
}
Stove IDs: [...]
=========================================
```

### 2. **CSV Data (external-csv-sync)**

```
📄 ========== CSV DATA RECEIVED ==========
Raw CSV Data: partner_id,partner_name,email...
=========================================

✅ CSV parsed successfully
📊 Total organizations parsed: 3
📋 Field mappings used: {...}
```

### 3. **Organization Processing**

```
🔄 ========== PROCESSING ORGANIZATION ==========
Partner ID: P001
Partner Name: Test Partner
Email (raw): N/A
Email type: string
Email value (JSON): "N/A"
Full org data: {...}
==============================================
```

### 4. **Email Validation (Most Important)**

```
🔍 ========== EMAIL VALIDATION ==========
Input email: N/A
Input type: string
Input value (JSON): "N/A"
Trimmed & lowercase: n/a
❌ Validation failed: Email matches invalid value (n/a)
======================================
```

### 5. **Email Determination**

```
📧 ========== EMAIL DETERMINATION ==========
Provided email: N/A
===========================================

⚠️ Invalid email provided (N/A), generated dummy email: test_partner_p001@atmosfair.site
🔑 Password generated (length): 16
🚀 Attempting to create user with email: test_partner_p001@atmosfair.site
```

### 6. **Success or Failure**

**Success:**

```
✅ Admin user created successfully for organization: [uuid]
```

**Failure:**

```
❌ ========== USER CREATION FAILED ==========
Organization: Test Partner
Error message: Auth user creation failed: Unable to validate email address: invalid format
Full error: {...}
============================================
```

## 🔍 How to View Logs in Supabase

### Method 1: Supabase Dashboard (Recommended)

1. Go to https://supabase.com/dashboard/project/oeiwnpngbnkhcismhpgs/functions
2. Click on the function name (`external-sync` or `external-csv-sync`)
3. Click on the "**Logs**" tab
4. Set time range to "Last hour" or "Last 15 minutes"
5. Look for the emoji markers (📥, 🔍, ⚠️, ❌, ✅) to quickly find relevant logs

### Method 2: Real-time Logs via CLI

```powershell
# Watch logs for external-csv-sync
supabase functions logs external-csv-sync --tail

# Or for external-sync
supabase functions logs external-sync --tail
```

## 📤 What to Send Me

After running your CSV sync request, please copy and send me:

### 1. **CSV Data Received Section**

```
📄 ========== CSV DATA RECEIVED ==========
Raw CSV Data: [COPY THIS]
=========================================
```

### 2. **Processing Organization Section** (for the failing org)

```
🔄 ========== PROCESSING ORGANIZATION ==========
Partner ID: [COPY THIS]
Partner Name: [COPY THIS]
Email (raw): [COPY THIS]
Email type: [COPY THIS]
Email value (JSON): [COPY THIS]
Full org data: [COPY THIS]
==============================================
```

### 3. **Email Validation Section**

```
🔍 ========== EMAIL VALIDATION ==========
[COPY EVERYTHING IN THIS SECTION]
======================================
```

### 4. **User Creation Failed Section** (if it fails)

```
❌ ========== USER CREATION FAILED ==========
[COPY EVERYTHING IN THIS SECTION]
============================================
```

## 🎯 Quick Test

Run your CSV sync again with the same data that was failing. The logs will now show:

1. ✅ Exact CSV data received
2. ✅ How each email value is parsed
3. ✅ Email validation step-by-step
4. ✅ Whether dummy email was generated
5. ✅ Exact error if user creation still fails

## 📋 Example Log Output

Here's what you should see for an organization with "N/A" email:

```
🔄 ========== PROCESSING ORGANIZATION ==========
Partner ID: P001
Partner Name: Test Partner
Email (raw): N/A
Email type: string
Email value (JSON): "N/A"
Full org data: {
  "partner_id": "P001",
  "partner_name": "Test Partner",
  "email": "N/A",
  ...
}
==============================================

🆕 New organization created, creating admin user...

📧 ========== EMAIL DETERMINATION ==========
Provided email: N/A
===========================================

🔍 ========== EMAIL VALIDATION ==========
Input email: N/A
Input type: string
Input value (JSON): "N/A"
Trimmed & lowercase: n/a
❌ Validation failed: Email matches invalid value (n/a)
======================================

⚠️ Invalid email provided (N/A), generated dummy email: test_partner_p001@atmosfair.site
🔑 Password generated (length): 16
🚀 Attempting to create user with email: test_partner_p001@atmosfair.site
✅ Admin user created successfully for organization: [uuid]
```

## 🚨 If Still Failing

If the email validation shows success but user creation still fails, the logs will show:

```
🔍 ========== EMAIL VALIDATION ==========
Input email: [the problematic email]
...
✅ Validation passed: Email is valid  <-- BUT STILL FAILING BELOW
======================================

❌ ========== USER CREATION FAILED ==========
Organization: [name]
Error message: [exact error from Supabase Auth]
Full error: [complete error object]
============================================
```

This will tell us if:

- The email is passing validation but Supabase Auth still rejects it
- There's another issue (like duplicate email, profile creation failure, etc.)

---

## 📍 Next Steps

1. Run your CSV sync request
2. Go to Supabase Dashboard > Functions > Logs
3. Copy the sections mentioned above
4. Send them to me so I can see exactly what's happening
5. I'll be able to fix the issue based on the exact data

The logs are now super detailed with emoji markers (📥🔍📧⚠️❌✅) making it easy to find what you need!

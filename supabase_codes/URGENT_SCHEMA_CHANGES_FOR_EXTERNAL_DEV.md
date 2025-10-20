# 🚨 URGENT: Database Schema Changes - Organization Structure Update

## Critical Change for External Apps

**⚠️ BREAKING CHANGE:** The organization table structure has been completely updated to a simplified 8-field structure. **Any direct REST API calls to fetch organization data must be updated immediately.**

## What Changed

### ❌ OLD Organization Fields (No longer exist)

```sql
-- These columns have been REMOVED from the database:
name              -- ❌ Removed
partner_email     -- ❌ Removed
organization_name -- ❌ Removed
city             -- ❌ Removed
country          -- ❌ Removed
description      -- ❌ Removed
status           -- ❌ Removed
```

### ✅ NEW Organization Fields (Current structure)

```sql
-- New 8-field organization structure:
id                  -- UUID (unchanged)
partner_name        -- Required - Partner name (replaces 'name')
branch             -- Required - Branch name
state              -- Required - State
contact_person     -- Optional - Contact person
contact_phone      -- Optional - Contact phone number
alternative_phone  -- Optional - Alternative phone number
email              -- Optional - Email (replaces 'partner_email')
address            -- Optional - Address
created_at         -- Timestamp (unchanged)
updated_at         -- Timestamp (unchanged)
created_by         -- UUID - Who created the record
updated_by         -- UUID - Who last updated the record
```

## 🔥 Fix Your REST API Calls IMMEDIATELY

### Current Error

Your REST API call is failing because you're using old column names:

```http
❌ BROKEN - This will fail:
GET /rest/v1/profiles?select=id,email,full_name,phone,role,has_changed_password,created_at,organization_id,organizations(id,name,created_at,partner_email)&id=eq.4e5bd539-7b5b-470e-b46f-ba2a9bbf593d
```

**Error:** `column organizations_1.name does not exist`

### ✅ FIXED - Use this instead:

```http
✅ CORRECT - Use new column names:
GET /rest/v1/profiles?select=id,email,full_name,phone,role,has_changed_password,created_at,organization_id,organizations(id,partner_name,branch,state,contact_person,contact_phone,alternative_phone,email,address,created_at)&id=eq.4e5bd539-7b5b-470e-b46f-ba2a9bbf593d
```

## Updated Query Examples

### 1. Get Profile with Organization (Full)

```http
GET /rest/v1/profiles?select=id,email,full_name,phone,role,has_changed_password,created_at,organization_id,organizations(id,partner_name,branch,state,contact_person,contact_phone,alternative_phone,email,address,created_at,updated_at)&id=eq.USER_ID_HERE
```

### 2. Get Profile with Organization (Minimal)

```http
GET /rest/v1/profiles?select=id,email,full_name,phone,role,organization_id,organizations(id,partner_name,branch,state,email)&id=eq.USER_ID_HERE
```

### 3. Get Organizations Directly

```http
GET /rest/v1/organizations?select=id,partner_name,branch,state,contact_person,contact_phone,alternative_phone,email,address,created_at
```

### 4. Search Organizations by State

```http
GET /rest/v1/organizations?select=id,partner_name,branch,state,email&state=eq.Lagos
```

## Frontend Code Updates Required

### JavaScript/TypeScript Examples

#### ❌ OLD Code (Will fail):

```javascript
// This will cause "column does not exist" errors
const { data } = await supabase
  .from("profiles")
  .select(
    `
    id, email, full_name, phone, role,
    organization_id,
    organizations(id, name, partner_email, created_at)
  `
  )
  .eq("id", userId);
```

#### ✅ NEW Code (Correct):

```javascript
// Use the new 8-field organization structure
const { data } = await supabase
  .from("profiles")
  .select(
    `
    id, email, full_name, phone, role,
    organization_id,
    organizations(
      id, 
      partner_name, 
      branch, 
      state, 
      contact_person, 
      contact_phone, 
      alternative_phone, 
      email, 
      address, 
      created_at
    )
  `
  )
  .eq("id", userId);
```

### Data Access Pattern Changes

#### ❌ OLD Data Access:

```javascript
// This will be undefined now
const orgName = profile.organizations.name; // ❌ undefined
const orgEmail = profile.organizations.partner_email; // ❌ undefined
```

#### ✅ NEW Data Access:

```javascript
// Use the new field names
const orgName = profile.organizations.partner_name; // ✅ Correct
const orgEmail = profile.organizations.email; // ✅ Correct
const orgBranch = profile.organizations.branch; // ✅ New field
const orgState = profile.organizations.state; // ✅ New field
```

## Response Data Structure

### Before (Old structure):

```json
{
  "organizations": {
    "id": "uuid",
    "name": "Partner Company", // ❌ No longer exists
    "partner_email": "email@company.com", // ❌ No longer exists
    "created_at": "2025-10-02T..."
  }
}
```

### After (New 8-field structure):

```json
{
  "organizations": {
    "id": "uuid",
    "partner_name": "Partner Company", // ✅ New (replaces 'name')
    "branch": "Main Branch", // ✅ New (required)
    "state": "Lagos", // ✅ New (required)
    "contact_person": "John Doe", // ✅ New (optional)
    "contact_phone": "+234123456789", // ✅ New (optional)
    "alternative_phone": "+234987654321", // ✅ New (optional)
    "email": "email@company.com", // ✅ New (replaces 'partner_email')
    "address": "123 Business Street", // ✅ New (optional)
    "created_at": "2025-10-02T...",
    "updated_at": "2025-10-02T..."
  }
}
```

## Migration Checklist for External Developer

- [ ] **Update all organization SELECT queries** to use new column names
- [ ] **Replace `name` with `partner_name`** in all queries
- [ ] **Replace `partner_email` with `email`** in all queries
- [ ] **Add required fields `branch` and `state`** to SELECT statements
- [ ] **Update data access code** to use new field names
- [ ] **Test all organization-related API calls**
- [ ] **Update any organization creation/update code** to use new structure
- [ ] **Remove references to deleted fields** (city, country, description, status)

## Quick Test

To verify your fixes work, test this API call:

```http
GET https://oeiwnpngbnkhcismhpgs.supabase.co/rest/v1/organizations?select=id,partner_name,branch,state,email&limit=1
Authorization: Bearer YOUR_JWT_TOKEN
```

Expected response:

```json
[
  {
    "id": "uuid-here",
    "partner_name": "Some Partner Name",
    "branch": "Some Branch",
    "state": "Some State",
    "email": "email@example.com"
  }
]
```

## Need Help?

If you encounter any issues after making these changes:

1. **Check your SELECT statements** - Make sure you're not using any old column names
2. **Verify the database migration** - The backend team may need to run database updates
3. **Test with minimal queries first** - Start with simple organization queries before complex joins
4. **Check for typos** - Column names are case-sensitive

**The key change: `name` → `partner_name` and `partner_email` → `email`**

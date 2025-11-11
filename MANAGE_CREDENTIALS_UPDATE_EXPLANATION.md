# Manage Credentials Update Explanation

## What Needs to Be Updated

The `manage-credentials` edge function currently returns **email** for all users when displaying credentials. This needs to be updated to show **username** for username-based users instead of their internal email.

---

## The Problem

### Current Behavior

When Super Admin fetches credentials, the response is:

```json
{
  "success": true,
  "credentials": [
    {
      "id": "uuid",
      "organization_id": "uuid",
      "email": "lapo_mfb_gbongan_598581@internal.acsl.local", // ❌ Internal email exposed
      "password": "AutoPass123!",
      "organization": {
        "partner_name": "Lapo MFB Gbongan",
        "branch": "Main"
      }
    }
  ]
}
```

**Issue:** Users who log in with username `lapo_mfb_gbongan_598581` see an internal email `lapo_mfb_gbongan_598581@internal.acsl.local` which:

- Is confusing (they never use this email)
- Looks unprofessional
- Exposes internal implementation details

---

## What Should Happen

### Expected Behavior

```json
{
  "success": true,
  "credentials": [
    {
      "id": "uuid",
      "organization_id": "uuid",
      "username": "lapo_mfb_gbongan_598581", // ✅ Show username instead
      "password": "AutoPass123!",
      "organization": {
        "partner_name": "Lapo MFB Gbongan",
        "branch": "Main"
      }
    }
  ]
}
```

**For email-based users:**

```json
{
  "id": "uuid",
  "email": "john@example.com", // ✅ Show actual email
  "password": "Pass123!"
}
```

---

## Technical Implementation

### File to Update

`supabase/functions/manage-credentials/read-operations.ts`

### Current Code (Line ~20-30)

```typescript
const credentials = await supabase
  .from("credentials")
  .select(
    `
    id,
    organization_id,
    email,           // ❌ Always shows email
    password,
    organizations (
      id,
      partner_name,
      branch,
      state
    )
  `
  )
  .order("created_at", { ascending: false });
```

### Updated Code Should Be

```typescript
const credentials = await supabase
  .from("credentials")
  .select(
    `
    id,
    organization_id,
    email,
    username,        // ✅ Also select username
    password,
    organizations (
      id,
      partner_name,
      branch,
      state
    )
  `
  )
  .order("created_at", { ascending: false });

// Map the response to show username if available, otherwise email
const mappedCredentials = credentials.data.map((cred) => ({
  id: cred.id,
  organization_id: cred.organization_id,
  ...(cred.username
    ? { username: cred.username } // Show username if exists
    : { email: cred.email }), // Otherwise show email
  password: cred.password,
  organization: cred.organizations,
}));
```

---

## Why This Matters

1. **User Experience:** Super Admins see the actual credentials users need to log in
2. **Security:** Hides internal email implementation from UI
3. **Consistency:** Matches the login flow (username or email)
4. **Professionalism:** Clean, understandable credentials display

---

## Files Affected

### Directly

- `supabase/functions/manage-credentials/read-operations.ts` - Update GET methods

### Indirectly

- `supabase/functions/manage-credentials/API_DOCUMENTATION.md` - Update response examples

---

## Example Response Comparison

### Before Update

```json
[
  {
    "email": "lapo_mfb_gbongan@internal.acsl.local", // Confusing
    "password": "Pass123!"
  },
  {
    "email": "real_user@gmail.com", // Real email
    "password": "Pass456!"
  }
]
```

### After Update

```json
[
  {
    "username": "lapo_mfb_gbongan", // ✅ Clear and correct
    "password": "Pass123!"
  },
  {
    "email": "real_user@gmail.com", // ✅ Still shows email
    "password": "Pass456!"
  }
]
```

---

## Summary

The update ensures Super Admins see:

- **Username** for users who log in with username (external synced organizations)
- **Email** for users who log in with email (manually created users)

This makes the credentials display match the actual login experience.

# Manage Credentials API - Authentication Guide

## 🔐 Authentication Requirement

The `manage-credentials` endpoint requires **Super Admin authentication**. Only users with `role = 'super_admin'` can access this endpoint.

---

## ❌ Current Error

```json
{
  "success": false,
  "error": "Invalid or expired token"
}
```

**Status Code:** 401 Unauthorized

---

## ✅ How to Fix

### Step 1: Login as Super Admin

Before calling the manage-credentials endpoint, the user must be logged in as a Super Admin.

**Login Endpoint:**

```
POST https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/login-with-credentials
```

**Request Body:**

```json
{
  "identifier": "superadmin@example.com", // or username
  "password": "your_password"
}
```

**Response:**

```json
{
  "success": true,
  "session": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...", // ← Use this token
    "refresh_token": "v1.MR5m...",
    "expires_in": 3600,
    "token_type": "bearer",
    "user": {
      "id": "user-uuid",
      "email": "superadmin@example.com"
    }
  },
  "profile": {
    "id": "user-uuid",
    "email": "superadmin@example.com",
    "role": "super_admin", // ← Must be "super_admin"
    "full_name": "Super Admin"
  }
}
```

---

### Step 2: Store the Access Token

After successful login, store the `access_token` from the response:

```javascript
const loginResponse = await fetch(
  "https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/login-with-credentials",
  {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      identifier: "superadmin@example.com",
      password: "password123",
    }),
  }
);

const data = await loginResponse.json();

if (data.success && data.profile.role === "super_admin") {
  // Store the token
  const accessToken = data.session.access_token;
  localStorage.setItem("access_token", accessToken);
  localStorage.setItem("user_role", data.profile.role);
}
```

---

### Step 3: Include Token in Manage Credentials Requests

**GET - Fetch All Credentials**

```javascript
const accessToken = localStorage.getItem("access_token");

const response = await fetch(
  "https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials",
  {
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`, // ← Required!
      "Content-Type": "application/json",
    },
  }
);

const credentials = await response.json();
```

**POST - Reset Password**

```javascript
const accessToken = localStorage.getItem("access_token");

const response = await fetch(
  "https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials",
  {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`, // ← Required!
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      action: "reset-password",
      partner_id: "12345",
      super_admin_password: "your_password", // Super Admin must verify their password
    }),
  }
);

const result = await response.json();
```

---

## 🔑 Authorization Header Format

**Correct Format:**

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Common Mistakes:**

- ❌ Missing "Bearer " prefix: `Authorization: eyJhbGc...`
- ❌ No Authorization header at all
- ❌ Using expired token
- ❌ Using token from non-Super Admin user

---

## 🚫 Access Control

The endpoint checks:

1. **Valid Token** - Must be a valid, non-expired Supabase access token
2. **User Exists** - Token must belong to an existing user
3. **Super Admin Role** - User's role in profiles table must be `'super_admin'`

**If any check fails:** Returns 401 with `"Invalid or expired token"` or `"Access denied"`

---

## 🧪 Testing Checklist

### Test 1: Login as Super Admin

```bash
curl -X POST \
  https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/login-with-credentials \
  -H 'Content-Type: application/json' \
  -d '{
    "identifier": "superadmin@example.com",
    "password": "password123"
  }'
```

**Expected:** Returns session with access_token and profile.role = "super_admin"

### Test 2: Get Credentials (No Token)

```bash
curl -X GET \
  https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials
```

**Expected:** 401 with `"Missing Authorization header"`

### Test 3: Get Credentials (With Token)

```bash
curl -X GET \
  https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials \
  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN_HERE'
```

**Expected:** 200 with list of credentials

### Test 4: Login as Regular Admin (Not Super Admin)

```bash
# Login as regular admin
curl -X POST \
  https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/login-with-credentials \
  -H 'Content-Type: application/json' \
  -d '{
    "identifier": "admin@example.com",
    "password": "password123"
  }'

# Try to access manage-credentials with admin token
curl -X GET \
  https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials \
  -H 'Authorization: Bearer ADMIN_TOKEN'
```

**Expected:** 401 with `"Access denied. Only Super Admin can access this resource."`

---

## 🔄 Token Refresh

Access tokens expire after 1 hour (3600 seconds). When a token expires:

1. **Detect expiration:** Check if response is 401
2. **Refresh token:** Use the `refresh_token` to get a new access token
3. **Retry request:** Use the new access token

```javascript
async function refreshAccessToken(refreshToken) {
  // Use Supabase client to refresh
  const { data, error } = await supabase.auth.refreshSession({
    refresh_token: refreshToken,
  });

  if (error) {
    // Refresh failed - require re-login
    window.location.href = "/login";
    return null;
  }

  // Store new tokens
  localStorage.setItem("access_token", data.session.access_token);
  localStorage.setItem("refresh_token", data.session.refresh_token);

  return data.session.access_token;
}
```

---

## 📋 Complete Example - React Component

```jsx
import { useState, useEffect } from "react";

function ManageCredentials() {
  const [credentials, setCredentials] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchCredentials();
  }, []);

  async function fetchCredentials() {
    try {
      const accessToken = localStorage.getItem("access_token");
      const userRole = localStorage.getItem("user_role");

      // Check if user is Super Admin
      if (userRole !== "super_admin") {
        setError("Access denied. Super Admin only.");
        setLoading(false);
        return;
      }

      if (!accessToken) {
        setError("Not logged in");
        setLoading(false);
        return;
      }

      const response = await fetch(
        "https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials",
        {
          method: "GET",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
        }
      );

      const data = await response.json();

      if (response.ok && data.success) {
        setCredentials(data.data);
      } else {
        // Handle 401 - Token expired or invalid
        if (response.status === 401) {
          setError("Session expired. Please login again.");
          // Redirect to login
          window.location.href = "/login";
        } else {
          setError(data.error || "Failed to fetch credentials");
        }
      }
    } catch (err) {
      setError("Network error: " + err.message);
    } finally {
      setLoading(false);
    }
  }

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error}</div>;

  return (
    <div>
      <h2>Manage Credentials</h2>
      <table>
        <thead>
          <tr>
            <th>Partner ID</th>
            <th>Partner Name</th>
            <th>Username/Email</th>
            <th>Password</th>
            <th>Role</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {credentials.map((cred) => (
            <tr key={cred.id}>
              <td>{cred.partner_id}</td>
              <td>{cred.partner_name}</td>
              <td>{cred.username || cred.email}</td>
              <td>{cred.password}</td>
              <td>{cred.role}</td>
              <td>
                <button onClick={() => resetPassword(cred.partner_id)}>
                  Reset Password
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

---

## ✅ Quick Fix Summary

**Your frontend developer needs to:**

1. ✅ Login user as Super Admin first
2. ✅ Extract `access_token` from login response
3. ✅ Store token in localStorage or state
4. ✅ Include token in Authorization header: `Bearer ${token}`
5. ✅ Verify user role is `'super_admin'` before showing credentials page

**The error `"Invalid or expired token"`** means:

- No Authorization header, OR
- Token is expired, OR
- Token is invalid, OR
- User is not a Super Admin

**Fix:** Add the Authorization header with a valid Super Admin token!

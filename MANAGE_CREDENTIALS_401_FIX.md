# Manage Credentials - 401 Error Troubleshooting

## ❌ Error Received

```json
{
  "success": false,
  "error": "Invalid or expired token"
}
```

---

## ✅ Quick Fix Checklist

### 1. Is the Authorization Header Included?

**Check the request headers:**

```javascript
// ❌ WRONG - No Authorization header
fetch(
  "https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials",
  {
    method: "GET",
    headers: {
      "Content-Type": "application/json",
    },
  }
);

// ✅ CORRECT - Authorization header included
fetch(
  "https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials",
  {
    method: "GET",
    headers: {
      Authorization: "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "Content-Type": "application/json",
    },
  }
);
```

---

### 2. Is the Token Format Correct?

**Correct format:** `Bearer <token>`

```javascript
// ❌ WRONG - Missing "Bearer " prefix
headers: {
  'Authorization': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
}

// ✅ CORRECT - Has "Bearer " prefix
headers: {
  'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
}
```

---

### 3. Did You Login First?

**You must login before accessing manage-credentials:**

```javascript
// Step 1: Login as Super Admin
const loginResponse = await fetch(
  "https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/login-with-credentials",
  {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      identifier: "superadmin@example.com",
      password: "your_password",
    }),
  }
);

const loginData = await loginResponse.json();

// Step 2: Extract and store token
const accessToken = loginData.session.access_token;
localStorage.setItem("access_token", accessToken);

// Step 3: Use token to access manage-credentials
const credentialsResponse = await fetch(
  "https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials",
  {
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
  }
);
```

---

### 4. Is the User a Super Admin?

**The endpoint requires `role = 'super_admin'`**

Check the login response:

```json
{
  "success": true,
  "profile": {
    "role": "super_admin" // ← Must be "super_admin", not "admin"
  }
}
```

**If role is NOT "super_admin":**

- The user cannot access manage-credentials
- You'll get: `"Access denied. Only Super Admin can access this resource."`

---

### 5. Has the Token Expired?

Access tokens expire after 1 hour (3600 seconds).

**How to check if token is expired:**

```javascript
// Check token expiration from login response
const expiresIn = loginData.session.expires_in; // 3600 seconds
const loginTime = Date.now();
const expiryTime = loginTime + expiresIn * 1000;

// Before making request, check if expired
if (Date.now() >= expiryTime) {
  // Token expired - need to refresh or re-login
  console.log("Token expired!");
}
```

**Solution:** Refresh the token or ask user to login again

---

### 6. Are You Using the Correct Token?

**Common mistakes:**

```javascript
// ❌ WRONG - Using refresh_token instead of access_token
const token = loginData.session.refresh_token;

// ✅ CORRECT - Using access_token
const token = loginData.session.access_token;
```

---

## 🔧 Complete Working Example

```javascript
class CredentialsManager {
  constructor() {
    this.baseUrl = "https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1";
    this.accessToken = null;
  }

  // Step 1: Login
  async login(identifier, password) {
    const response = await fetch(`${this.baseUrl}/login-with-credentials`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ identifier, password }),
    });

    const data = await response.json();

    if (!data.success) {
      throw new Error(data.error || "Login failed");
    }

    // Verify Super Admin
    if (data.profile.role !== "super_admin") {
      throw new Error("Access denied. Super Admin only.");
    }

    // Store token
    this.accessToken = data.session.access_token;
    localStorage.setItem("access_token", this.accessToken);
    localStorage.setItem("refresh_token", data.session.refresh_token);

    return data;
  }

  // Step 2: Get Credentials
  async getCredentials() {
    // Get token from storage if not in memory
    if (!this.accessToken) {
      this.accessToken = localStorage.getItem("access_token");
    }

    if (!this.accessToken) {
      throw new Error("Not logged in. Please login first.");
    }

    const response = await fetch(`${this.baseUrl}/manage-credentials`, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${this.accessToken}`,
        "Content-Type": "application/json",
      },
    });

    const data = await response.json();

    if (response.status === 401) {
      // Token expired or invalid
      throw new Error("Session expired. Please login again.");
    }

    if (!data.success) {
      throw new Error(data.error || "Failed to fetch credentials");
    }

    return data.data;
  }

  // Step 3: Reset Password
  async resetPassword(partnerId, superAdminPassword) {
    if (!this.accessToken) {
      this.accessToken = localStorage.getItem("access_token");
    }

    const response = await fetch(`${this.baseUrl}/manage-credentials`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        action: "reset-password",
        partner_id: partnerId,
        super_admin_password: superAdminPassword,
      }),
    });

    const data = await response.json();

    if (!data.success) {
      throw new Error(data.error || "Password reset failed");
    }

    return data;
  }
}

// Usage:
const manager = new CredentialsManager();

try {
  // Login first
  await manager.login("superadmin@example.com", "password123");

  // Then get credentials
  const credentials = await manager.getCredentials();
  console.log("Credentials:", credentials);
} catch (error) {
  console.error("Error:", error.message);
}
```

---

## 🧪 Test Your Fix

### Browser Console Test

```javascript
// 1. Login
const loginResp = await fetch(
  "https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/login-with-credentials",
  {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      identifier: "superadmin@example.com",
      password: "your_password",
    }),
  }
);
const loginData = await loginResp.json();
console.log("Login:", loginData);

// 2. Get token
const token = loginData.session.access_token;
console.log("Token:", token);

// 3. Test manage-credentials
const credsResp = await fetch(
  "https://oeiwnpngbnkhcismhpgs.supabase.co/functions/v1/manage-credentials",
  {
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
  }
);
const credsData = await credsResp.json();
console.log("Credentials:", credsData);
```

**Expected Result:** Should return list of credentials with no 401 error

---

## 📝 Summary

**The 401 error happens because:**

1. ❌ No Authorization header in request
2. ❌ Token is missing or invalid
3. ❌ Token format is wrong (missing "Bearer ")
4. ❌ Token has expired
5. ❌ User is not a Super Admin

**To fix:**

1. ✅ Login as Super Admin
2. ✅ Get access_token from login response
3. ✅ Include token in Authorization header as `Bearer ${token}`
4. ✅ Make sure user role is `'super_admin'`

**Tell your frontend dev:** Add the Authorization header with the access token from the login response!

# React API Update Summary - Username/Email Login

## What Changed

We've added flexible authentication that supports **both username and email** login using the same input field. Users can enter either their username or email address to log in.

---

## API Endpoint Change

### ❌ Old Endpoint (Deprecated)

```
Direct Supabase Auth signInWithPassword
```

### ✅ New Endpoint

```
POST /login-with-credentials
```

**Base URL:** `https://your-supabase-url.supabase.co/functions/v1`

---

## Request Format

### Old Request Body

```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

### New Request Body

```json
{
  "identifier": "username_or_email",
  "password": "password123"
}
```

**Key Change:** Replace `email` field with `identifier` field. The backend automatically detects if it's a username or email.

---

## Response Format

### Success Response (200)

```json
{
  "success": true,
  "session": {
    "access_token": "eyJhbGc...",
    "refresh_token": "v1.MR5m...",
    "expires_in": 3600,
    "token_type": "bearer",
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "user_metadata": {
        "role": "agent",
        "full_name": "John Doe"
      }
    }
  },
  "profile": {
    "id": "uuid",
    "email": "user@example.com",
    "username": "john_doe_123",
    "full_name": "John Doe",
    "role": "agent",
    "organization": {
      /* org data */
    }
  }
}
```

### Error Response (401)

```json
{
  "error": "Invalid credentials"
}
```

---

## How to Update Your Code

### 1. Update Login Form Field

Change your email input to accept both:

```jsx
// Before
<input
  type="email"
  name="email"
  placeholder="Enter your email"
/>

// After
<input
  type="text"
  name="identifier"
  placeholder="Username or Email"
/>
```

### 2. Update API Call

```javascript
// Before
const response = await supabase.auth.signInWithPassword({
  email: formData.email,
  password: formData.password,
});

// After
const response = await fetch(
  `${SUPABASE_URL}/functions/v1/login-with-credentials`,
  {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      identifier: formData.identifier, // Changed from 'email'
      password: formData.password,
    }),
  }
);

const data = await response.json();
```

### 3. Handle Response

```javascript
if (response.ok && data.success) {
  // Store session
  const { session, profile } = data;
  localStorage.setItem("access_token", session.access_token);
  localStorage.setItem("refresh_token", session.refresh_token);
  localStorage.setItem("profile", JSON.stringify(profile));

  // Redirect based on role
  if (profile.role === "admin") {
    navigate("/admin");
  } else {
    navigate("/agent");
  }
} else {
  // Show error
  setError(data.error || "Login failed");
}
```

---

## Client-Side Username vs Email Detection (Optional)

If you want to show different UI feedback, detect the input type:

```javascript
const isEmail = identifier.includes("@");
const loginType = isEmail ? "email" : "username";
console.log(`Logging in with ${loginType}`);
```

---

## Backward Compatibility

✅ **Users with email addresses can still log in with email**  
✅ **New users created via external-sync get username-based login**  
✅ **No breaking changes - both methods work**

---

## Notes for Your Implementation

- **No form validation change needed** - Accept any text input
- **Same session handling** - Token storage and refresh work the same way
- **Profile object now includes username** - Available at `profile.username`
- **Internal emails hidden** - Users with username-based accounts won't see `username@internal.acsl.local`

---

## Testing Checklist

- [ ] Test login with valid email + password
- [ ] Test login with valid username + password
- [ ] Test login with invalid credentials (both formats)
- [ ] Verify session token storage
- [ ] Verify profile data includes username field
- [ ] Test role-based redirection (admin vs agent)

---

## Questions?

This update maintains full backward compatibility. Your existing email-based users can continue using email, while new users synced from external systems can use their username.

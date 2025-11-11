# React Login Integration Guide

## 📋 Overview

This guide provides for integrating flexible username/email authentication into your React application. The authentication system supports login with **EITHER username OR email** using the same input field.

### Authentication Flow

1. User enters identifier (username or email) + password
2. System automatically detects type (email has `@`, username doesn't)
3. Backend handles lookup and authentication
4. Session tokens returned for authenticated requests

---

## 🚀 Quick Start (Copy & Paste)

### Step 1: Install Dependencies

```bash
npm install axios
# or
yarn add axios
```

### Step 2: Environment Configuration

Create a `.env` file:

```env
REACT_APP_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
REACT_APP_SUPABASE_ANON_KEY=your_anon_key_here
```

### Step 3: Create API Client (`src/api/client.ts`)

```typescript
import axios from "axios";

const API_BASE_URL = process.env.REACT_APP_SUPABASE_URL;

export const apiClient = axios.create({
  baseURL: `${API_BASE_URL}/functions/v1`,
  headers: {
    "Content-Type": "application/json",
  },
});

// Add authentication interceptor
apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem("access_token");
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

export default apiClient;
```

---

## 🔐 Authentication Types

### TypeScript Interfaces (`src/types/auth.ts`)

```typescript
export interface LoginRequest {
  identifier: string; // Username OR Email
  password: string;
}

export interface User {
  id: string;
  username?: string;
  email?: string;
  full_name: string;
  role: string;
  organization_id: string;
  has_changed_password: boolean;
  display_name: string;
}

export interface Session {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  token_type: string;
  user: {
    id: string;
    email: string;
    role: string;
  };
}

export interface LoginResponse {
  success: boolean;
  session?: Session;
  user?: User;
  error?: string;
}

export interface AuthState {
  user: User | null;
  session: Session | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
}
```

---

## 🎯 Authentication Service (`src/services/authService.ts`)

```typescript
import apiClient from "../api/client";
import { LoginRequest, LoginResponse, User, Session } from "../types/auth";

class AuthService {
  /**
   * Login with username or email
   * @param identifier - Username (no @) or Email (has @)
   * @param password - User password
   */
  async login(identifier: string, password: string): Promise<LoginResponse> {
    try {
      const response = await apiClient.post<LoginResponse>(
        "/login-with-credentials",
        {
          identifier: identifier.trim(),
          password,
        }
      );

      if (
        response.data.success &&
        response.data.session &&
        response.data.user
      ) {
        // Store session tokens
        this.storeSession(response.data.session, response.data.user);
      }

      return response.data;
    } catch (error: any) {
      console.error("Login error:", error);
      return {
        success: false,
        error:
          error.response?.data?.error || "Network error. Please try again.",
      };
    }
  }

  /**
   * Store session data in localStorage
   */
  private storeSession(session: Session, user: User): void {
    localStorage.setItem("access_token", session.access_token);
    localStorage.setItem("refresh_token", session.refresh_token);
    localStorage.setItem("user", JSON.stringify(user));
    localStorage.setItem("session", JSON.stringify(session));
  }

  /**
   * Get current user from localStorage
   */
  getUser(): User | null {
    const userStr = localStorage.getItem("user");
    if (!userStr) return null;

    try {
      return JSON.parse(userStr);
    } catch {
      return null;
    }
  }

  /**
   * Get current session from localStorage
   */
  getSession(): Session | null {
    const sessionStr = localStorage.getItem("session");
    if (!sessionStr) return null;

    try {
      return JSON.parse(sessionStr);
    } catch {
      return null;
    }
  }

  /**
   * Check if user is authenticated
   */
  isAuthenticated(): boolean {
    const token = localStorage.getItem("access_token");
    const user = this.getUser();
    return !!token && !!user;
  }

  /**
   * Logout and clear session
   */
  logout(): void {
    localStorage.removeItem("access_token");
    localStorage.removeItem("refresh_token");
    localStorage.removeItem("user");
    localStorage.removeItem("session");
  }

  /**
   * Get display name for UI
   */
  getDisplayName(): string {
    const user = this.getUser();
    if (!user) return "Guest";
    return user.display_name || user.full_name || "User";
  }

  /**
   * Get login identifier (username or email) for display
   */
  getLoginIdentifier(): string {
    const user = this.getUser();
    if (!user) return "";
    return user.username || user.email || "";
  }
}

export default new AuthService();
```

---

## 🎨 Login Component (`src/components/Login.tsx`)

### Full Component with Styling

```typescript
import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import authService from "../services/authService";
import "../styles/Login.css";

const Login: React.FC = () => {
  const navigate = useNavigate();
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [showPassword, setShowPassword] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!identifier.trim() || !password) {
      setError("Please enter your username/email and password");
      return;
    }

    setLoading(true);
    setError("");

    const result = await authService.login(identifier, password);

    setLoading(false);

    if (result.success && result.user) {
      console.log("Login successful:", result.user.display_name);
      navigate("/dashboard");
    } else {
      setError(result.error || "Login failed. Please try again.");
    }
  };

  return (
    <div className="login-container">
      <div className="login-card">
        <div className="login-header">
          <h1>Welcome Back</h1>
          <p>Enter your credentials to continue</p>
        </div>

        <form onSubmit={handleSubmit} className="login-form">
          <div className="form-group">
            <label htmlFor="identifier">Username or Email</label>
            <input
              id="identifier"
              type="text"
              placeholder="Enter username or email"
              value={identifier}
              onChange={(e) => setIdentifier(e.target.value)}
              disabled={loading}
              required
              autoComplete="username"
            />
          </div>

          <div className="form-group">
            <label htmlFor="password">Password</label>
            <div className="password-input">
              <input
                id="password"
                type={showPassword ? "text" : "password"}
                placeholder="Enter password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                disabled={loading}
                required
                autoComplete="current-password"
              />
              <button
                type="button"
                className="toggle-password"
                onClick={() => setShowPassword(!showPassword)}
                tabIndex={-1}
              >
                {showPassword ? "👁️" : "👁️‍🗨️"}
              </button>
            </div>
          </div>

          {error && (
            <div className="error-message">
              <span className="error-icon">⚠️</span>
              {error}
            </div>
          )}

          <button type="submit" className="submit-button" disabled={loading}>
            {loading ? (
              <>
                <span className="spinner"></span>
                Logging in...
              </>
            ) : (
              "Login"
            )}
          </button>
        </form>

        <div className="login-footer">
          <p className="help-text">
            Enter either your <strong>username</strong> or{" "}
            <strong>email</strong>
          </p>
        </div>
      </div>
    </div>
  );
};

export default Login;
```

### CSS Styling (`src/styles/Login.css`)

```css
.login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 20px;
}

.login-card {
  background: white;
  border-radius: 16px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  padding: 40px;
  max-width: 400px;
  width: 100%;
}

.login-header {
  text-align: center;
  margin-bottom: 32px;
}

.login-header h1 {
  font-size: 28px;
  color: #1a202c;
  margin: 0 0 8px 0;
}

.login-header p {
  color: #718096;
  margin: 0;
}

.login-form {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.form-group label {
  font-size: 14px;
  font-weight: 600;
  color: #2d3748;
}

.form-group input {
  padding: 12px 16px;
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  font-size: 16px;
  transition: border-color 0.2s;
}

.form-group input:focus {
  outline: none;
  border-color: #667eea;
}

.form-group input:disabled {
  background-color: #f7fafc;
  cursor: not-allowed;
}

.password-input {
  position: relative;
}

.password-input input {
  width: 100%;
  padding-right: 48px;
}

.toggle-password {
  position: absolute;
  right: 12px;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  cursor: pointer;
  font-size: 20px;
  padding: 4px;
}

.error-message {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
  background-color: #fff5f5;
  border: 1px solid #fc8181;
  border-radius: 8px;
  color: #c53030;
  font-size: 14px;
}

.error-icon {
  font-size: 18px;
}

.submit-button {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 14px 24px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
  transition: transform 0.2s, box-shadow 0.2s;
}

.submit-button:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 8px 20px rgba(102, 126, 234, 0.4);
}

.submit-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.spinner {
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.login-footer {
  margin-top: 24px;
  text-align: center;
}

.help-text {
  font-size: 13px;
  color: #718096;
  margin: 0;
}

.help-text strong {
  color: #2d3748;
}
```

---

## 🔒 Protected Route Component (`src/components/ProtectedRoute.tsx`)

```typescript
import React from "react";
import { Navigate, Outlet } from "react-router-dom";
import authService from "../services/authService";

const ProtectedRoute: React.FC = () => {
  const isAuthenticated = authService.isAuthenticated();

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return <Outlet />;
};

export default ProtectedRoute;
```

---

## 🗺️ Router Setup (`src/App.tsx`)

```typescript
import React from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import Login from "./components/Login";
import Dashboard from "./components/Dashboard";
import ProtectedRoute from "./components/ProtectedRoute";

const App: React.FC = () => {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />

        {/* Protected routes */}
        <Route element={<ProtectedRoute />}>
          <Route path="/dashboard" element={<Dashboard />} />
          {/* Add more protected routes here */}
        </Route>

        {/* Redirect root to dashboard or login */}
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </BrowserRouter>
  );
};

export default App;
```

---

## 📱 Dashboard Example (`src/components/Dashboard.tsx`)

```typescript
import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import authService from "../services/authService";
import { User } from "../types/auth";
import "../styles/Dashboard.css";

const Dashboard: React.FC = () => {
  const navigate = useNavigate();
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    const currentUser = authService.getUser();
    if (currentUser) {
      setUser(currentUser);
    }
  }, []);

  const handleLogout = () => {
    authService.logout();
    navigate("/login");
  };

  if (!user) {
    return <div>Loading...</div>;
  }

  return (
    <div className="dashboard-container">
      <div className="dashboard-header">
        <h1>Dashboard</h1>
        <button onClick={handleLogout} className="logout-button">
          Logout
        </button>
      </div>

      <div className="user-info-card">
        <h2>Welcome, {user.full_name}!</h2>
        <div className="user-details">
          <div className="detail-row">
            <span className="label">Login ID:</span>
            <span className="value">{user.username || user.email}</span>
          </div>
          <div className="detail-row">
            <span className="label">Role:</span>
            <span className="value">{user.role}</span>
          </div>
          <div className="detail-row">
            <span className="label">Organization:</span>
            <span className="value">{user.organization_id}</span>
          </div>
        </div>

        {!user.has_changed_password && (
          <div className="warning-banner">
            ⚠️ Please change your default password for security
          </div>
        )}
      </div>
    </div>
  );
};

export default Dashboard;
```

### Dashboard CSS (`src/styles/Dashboard.css`)

```css
.dashboard-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 40px 20px;
}

.dashboard-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 32px;
}

.dashboard-header h1 {
  font-size: 32px;
  color: #1a202c;
  margin: 0;
}

.logout-button {
  padding: 10px 20px;
  background-color: #e53e3e;
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: background-color 0.2s;
}

.logout-button:hover {
  background-color: #c53030;
}

.user-info-card {
  background: white;
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  padding: 32px;
}

.user-info-card h2 {
  font-size: 24px;
  color: #2d3748;
  margin: 0 0 24px 0;
}

.user-details {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.detail-row {
  display: flex;
  gap: 12px;
}

.detail-row .label {
  font-weight: 600;
  color: #4a5568;
  min-width: 140px;
}

.detail-row .value {
  color: #1a202c;
}

.warning-banner {
  margin-top: 24px;
  padding: 16px;
  background-color: #fffbeb;
  border: 1px solid #f59e0b;
  border-radius: 8px;
  color: #92400e;
  font-size: 14px;
}
```

---

## 🧪 Testing Examples

### Manual Testing

#### Test with Username

```typescript
// In browser console or test file
authService.login("lapo_mfb_gbongan_598581", "Password123!");
```

#### Test with Email

```typescript
authService.login("admin@acsl.com", "AdminPassword123!");
```

### Unit Test Example (`src/services/__tests__/authService.test.ts`)

```typescript
import authService from "../authService";

describe("AuthService", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it("should detect username (no @)", () => {
    const identifier = "lapo_mfb_gbongan_598581";
    expect(identifier.includes("@")).toBe(false);
  });

  it("should detect email (has @)", () => {
    const identifier = "user@example.com";
    expect(identifier.includes("@")).toBe(true);
  });

  it("should store session after successful login", async () => {
    // Mock successful response
    const mockUser = {
      id: "123",
      username: "test_user",
      full_name: "Test User",
      role: "Agent",
      organization_id: "org-123",
      has_changed_password: false,
      display_name: "test_user",
    };

    // Simulate login (you'll need to mock apiClient)
    // authService.login(...) would call apiClient.post()
    // For this example, just test storage

    localStorage.setItem("user", JSON.stringify(mockUser));
    const stored = authService.getUser();

    expect(stored).toEqual(mockUser);
  });
});
```

---

## 🚨 Error Handling

### Common Errors and Solutions

```typescript
// Handle network errors
try {
  const result = await authService.login(identifier, password);
  if (!result.success) {
    // Show user-friendly error
    console.error("Login failed:", result.error);
  }
} catch (error) {
  console.error("Network error:", error);
  alert("Cannot connect to server. Please check your internet connection.");
}

// Handle expired tokens
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Token expired - logout user
      authService.logout();
      window.location.href = "/login";
    }
    return Promise.reject(error);
  }
);
```

---

## 🎯 GitHub Copilot Prompts

Use these prompts with GitHub Copilot to generate code:

### Prompt 1: Create Login Component

```
Create a React login component that accepts username or email in a single input field, with password field and validation. Use authService.login() for authentication. Include loading states and error handling.
```

### Prompt 2: Create Protected Route

```
Create a ProtectedRoute component that checks if user is authenticated using authService.isAuthenticated(). If not authenticated, redirect to /login. Use React Router's Outlet for nested routes.
```

### Prompt 3: Add Logout Functionality

```
Create a logout button component that calls authService.logout() and redirects to /login using React Router's useNavigate hook. Include confirmation dialog.
```

---

## 📋 Deployment Checklist

- [ ] Set `REACT_APP_SUPABASE_URL` in production environment
- [ ] Set `REACT_APP_SUPABASE_ANON_KEY` in production environment
- [ ] Test login with username
- [ ] Test login with email
- [ ] Test logout functionality
- [ ] Test protected routes
- [ ] Test token expiration handling
- [ ] Verify error messages are user-friendly
- [ ] Check responsive design on mobile
- [ ] Test accessibility (keyboard navigation, screen readers)

---

## 🔧 Advanced Features

### Auto-Login on App Load

```typescript
// In App.tsx
useEffect(() => {
  const session = authService.getSession();
  if (session) {
    const expiresAt = new Date(session.expires_in * 1000);
    if (expiresAt > new Date()) {
      // Session still valid
      navigate("/dashboard");
    } else {
      // Session expired
      authService.logout();
    }
  }
}, []);
```

### Remember Me Functionality

```typescript
// Modify storeSession to use sessionStorage for temporary sessions
private storeSession(session: Session, user: User, rememberMe: boolean): void {
  const storage = rememberMe ? localStorage : sessionStorage;
  storage.setItem('access_token', session.access_token);
  storage.setItem('user', JSON.stringify(user));
}
```

---

## 📚 Additional Resources

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [React Router Documentation](https://reactrouter.com/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)

---

## ❓ FAQ

**Q: Can I use this with NextJS?**  
A: Yes! Replace `react-router-dom` with NextJS's `useRouter` and adjust file structure accordingly.

**Q: How do I refresh tokens?**  
A: Implement token refresh in the axios interceptor using the refresh_token.

**Q: Can I customize the UI?**  
A: Absolutely! The CSS is modular and can be customized or replaced with your design system.

---

**Need help?** Contact the backend team or check the API documentation in `supabase/functions/login-with-credentials/API_DOCUMENTATION.md`

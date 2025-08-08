# Get Sales Agents Edge Function

## 🎯 Purpose

Allows admins and super admins to fetch sales agents with proper role-based access control.

## 🚀 Deployment Steps

1. **Create edge function** in Supabase dashboard named `get-sales-agents`
2. **Copy the content** from `get-sales-agents/index.ts` into the dashboard
3. **Deploy the function**

## 🔐 Access Control Logic

### **Super Admin**

- Can see **ALL** sales agents across all organizations
- No organization filtering applied

### **Admin**

- Can see **ONLY** sales agents from their own organization
- Must have `organization_id` set in their profile
- Filtered by `organization_id = admin's organization_id`

### **Other Roles**

- Access denied with 403 error

## 🧪 Testing

**Headers:**

```
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json
```

**Body:**

```json
{}
```

**Expected Response:**

```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "full_name": "Agent Name",
      "email": "agent@example.com",
      "phone": "1234567890",
      "role": "agent",
      "organization_id": "org-uuid",
      "created_at": "2025-01-01T00:00:00Z"
    }
  ],
  "message": "Found X sales agents",
  "userRole": "admin",
  "userOrganization": "org-uuid"
}
```

## ✅ Benefits

- **No RLS recursion issues** - Uses service role to bypass RLS entirely
- **Scalable role checking** - No hardcoded emails, works with unlimited admins/super admins
- **Proper organization filtering** - Admins only see their agents
- **Clear error messages** - Easy to debug permission issues
- **Future-proof** - Easy to extend with additional filters if needed

## 🔍 Logging

The function logs:

- 🚀 Function start
- 🔧 Supabase initialization
- 🔐 Authentication steps
- 👤 User profile fetch
- 🏢 Organization filtering
- 🔍 Query execution
- ✅ Success/error results

Much cleaner than RLS policies! 🎉

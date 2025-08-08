# Row Level Security (RLS) Policy for Super Admin Access

## Issue Identified

Your edge function is working correctly, but Row Level Security (RLS) policies on the `sales` table are preventing the super_admin from seeing all sales records.

## Current Situation

- ✅ Authentication working
- ✅ Super admin role confirmed
- ✅ Sales table has data
- ❌ RLS policies blocking access to sales data

## Solution: Update RLS Policies

### 1. Current RLS Policy Check

First, check your current policies:

```sql
-- Check existing policies on sales table
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'sales';
```

### 2. Create Super Admin RLS Policy

Add this policy to allow super_admin to see all sales:

```sql
-- Create policy for super_admin to access all sales
CREATE POLICY "super_admin_all_access"
ON sales
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'super_admin'
    )
);
```

### 3. Alternative: Modify Existing Policy

If you already have a policy, modify it to include super_admin:

```sql
-- Example: Update existing policy to include super_admin
ALTER POLICY "existing_policy_name"
ON sales
USING (
    organization_id = (
        SELECT organization_id FROM profiles
        WHERE id = auth.uid()
    )
    OR
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'super_admin'
    )
);
```

### 4. Complete Super Admin Policy Set

For comprehensive access, create these policies:

```sql
-- Super admin can SELECT all sales
CREATE POLICY "super_admin_select_all"
ON sales
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'super_admin'
    )
);

-- Super admin can INSERT sales for any organization
CREATE POLICY "super_admin_insert_all"
ON sales
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'super_admin'
    )
);

-- Super admin can UPDATE any sales
CREATE POLICY "super_admin_update_all"
ON sales
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'super_admin'
    )
);

-- Super admin can DELETE any sales
CREATE POLICY "super_admin_delete_all"
ON sales
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'super_admin'
    )
);
```

### 5. Quick Fix Script

Run this complete script to fix the issue:

```sql
-- Enable RLS if not already enabled
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;

-- Drop existing policies that might conflict (adjust names as needed)
-- DROP POLICY IF EXISTS "existing_policy_name" ON sales;

-- Create comprehensive super admin access
CREATE POLICY "super_admin_full_access"
ON sales
FOR ALL
TO authenticated
USING (
    -- Regular users see their organization's sales
    organization_id = (
        SELECT organization_id FROM profiles
        WHERE id = auth.uid()
    )
    OR
    -- Super admins see all sales
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'super_admin'
    )
)
WITH CHECK (
    -- Regular users can only create/update for their organization
    organization_id = (
        SELECT organization_id FROM profiles
        WHERE id = auth.uid()
    )
    OR
    -- Super admins can create/update for any organization
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'super_admin'
    )
);
```

## Testing

After applying the policy, test with:

```sql
-- Test as super admin
SELECT COUNT(*) FROM sales;

-- Test specific user
SELECT
    auth.uid() as current_user,
    (SELECT role FROM profiles WHERE id = auth.uid()) as user_role,
    COUNT(*) as accessible_sales
FROM sales;
```

## Expected Result

After fixing the RLS policies:

- Super admin should see ALL sales across ALL organizations
- Regular users should see only their organization's sales
- Your edge function should return the correct data

The edge function debug logs will then show:

- ✅ Records returned > 0
- ✅ Total records matching query results

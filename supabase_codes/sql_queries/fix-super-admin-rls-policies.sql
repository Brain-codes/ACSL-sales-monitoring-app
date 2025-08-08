-- Fix RLS Policies for Super Admin Access
-- Current issue: Super admin (organization_id = null) cannot access any sales data

-- 1. First, let's update the SELECT policy to include super_admin access
DROP POLICY IF EXISTS "Users can view sales from their org" ON sales;

CREATE POLICY "Users can view sales from their org" 
ON sales 
FOR SELECT 
TO authenticated 
USING (
    -- Super admins can see ALL sales
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'super_admin'
    )
    OR
    -- Regular users can only see their organization's sales
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.organization_id = sales.organization_id
    )
);

-- 2. Update INSERT policy to allow super_admin to insert for any organization
DROP POLICY IF EXISTS "Allow insert for user's org" ON sales;

CREATE POLICY "Allow insert for user's org" 
ON sales 
FOR INSERT 
TO authenticated 
WITH CHECK (
    -- Super admins can insert for any organization
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'super_admin'
    )
    OR
    -- Regular users can only insert for their organization
    (created_by = auth.uid() AND organization_id IN (
        SELECT profiles.organization_id
        FROM profiles
        WHERE profiles.id = auth.uid()
    ))
);

-- 3. Clean up duplicate UPDATE policies and create one comprehensive policy
DROP POLICY IF EXISTS "Allow update for user's org" ON sales;
DROP POLICY IF EXISTS "Allow updates for user's org" ON sales;

CREATE POLICY "Allow update for user's org" 
ON sales 
FOR UPDATE 
TO authenticated 
USING (
    -- Super admins can update any sales
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'super_admin'
    )
    OR
    -- Regular users can only update their organization's sales
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.organization_id = sales.organization_id
    )
)
WITH CHECK (
    -- Super admins can update any sales
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'super_admin'
    )
    OR
    -- Regular users can only update their organization's sales
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.organization_id = sales.organization_id
    )
);

-- 4. Add DELETE policy for completeness
CREATE POLICY "Allow delete for user's org" 
ON sales 
FOR DELETE 
TO authenticated 
USING (
    -- Super admins can delete any sales
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'super_admin'
    )
    OR
    -- Regular users can only delete their organization's sales
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.organization_id = sales.organization_id
    )
);

-- 5. Verify the policies are created correctly
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'sales'
ORDER BY cmd, policyname;

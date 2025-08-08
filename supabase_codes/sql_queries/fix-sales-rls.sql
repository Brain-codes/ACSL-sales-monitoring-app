-- Fix RLS policies for sales table to allow super_admin access
-- This script creates RLS policies for the sales table

-- Drop ALL existing policies for sales table
DO $$
DECLARE
    rec RECORD;
BEGIN
    -- Get all policies for the sales table and drop them
    FOR rec IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'sales' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || rec.policyname || '" ON public.sales';
    END LOOP;
END $$;

-- Create new policies for sales table

-- 1. Super admin can access all sales (check role from profiles table)
CREATE POLICY "super_admin_sales_access" ON public.sales
FOR ALL
TO authenticated
USING (
    -- Check if user has super_admin role in profiles table
    EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND role = 'super_admin'
    )
)
WITH CHECK (
    -- Same logic for updates/inserts
    EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND role = 'super_admin'
    )
);

-- 2. Users can access sales they created
CREATE POLICY "users_own_sales" ON public.sales
FOR ALL
TO authenticated
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- 3. Users can access sales from their organization
CREATE POLICY "users_org_sales" ON public.sales
FOR SELECT
TO authenticated
USING (
    organization_id IN (
        SELECT organization_id 
        FROM public.profiles 
        WHERE id = auth.uid() 
        LIMIT 1
    )
);

-- 4. Admin users can manage sales in their organization
CREATE POLICY "admin_org_sales_management" ON public.sales
FOR ALL
TO authenticated
USING (
    organization_id IN (
        SELECT organization_id 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND role IN ('admin', 'super_admin')
    )
)
WITH CHECK (
    organization_id IN (
        SELECT organization_id 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND role IN ('admin', 'super_admin')
    )
);

-- Ensure RLS is enabled
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;

-- Test the policies
SELECT 'Sales RLS policies updated successfully' as message;

-- Show current policies
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'sales' 
AND schemaname = 'public'
ORDER BY policyname;

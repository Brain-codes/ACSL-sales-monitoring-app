-- Fix RLS policies for organizations table to allow super_admin access
-- This script creates RLS policies for the organizations table

-- Drop ALL existing policies for organizations table
DO $$
DECLARE
    rec RECORD;
BEGIN
    -- Get all policies for the organizations table and drop them
    FOR rec IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'organizations' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || rec.policyname || '" ON public.organizations';
    END LOOP;
END $$;

-- Create new policies for organizations table

-- 1. Super admin can access all organizations (check role from profiles table)
CREATE POLICY "super_admin_organizations_access" ON public.organizations
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

-- 2. Users can access organizations they belong to
CREATE POLICY "users_organization_access" ON public.organizations
FOR SELECT
TO authenticated
USING (
    id IN (
        SELECT organization_id 
        FROM public.profiles 
        WHERE id = auth.uid()
    )
);

-- 3. Admin users can manage their organization
CREATE POLICY "admin_organization_management" ON public.organizations
FOR ALL
TO authenticated
USING (
    id IN (
        SELECT organization_id 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND role = 'admin'
    )
)
WITH CHECK (
    id IN (
        SELECT organization_id 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND role = 'admin'
    )
);

-- Ensure RLS is enabled
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

-- Test the policies
SELECT 'Organizations RLS policies updated successfully' as message;

-- Show current policies
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'organizations' 
AND schemaname = 'public'
ORDER BY policyname;

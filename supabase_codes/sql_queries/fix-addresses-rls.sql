-- Fix RLS policies for addresses table to allow super_admin access
-- This script creates RLS policies for the addresses table

-- Drop ALL existing policies for addresses table
DO $$
DECLARE
    rec RECORD;
BEGIN
    -- Get all policies for the addresses table and drop them
    FOR rec IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'addresses' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || rec.policyname || '" ON public.addresses';
    END LOOP;
END $$;

-- Create new policies for addresses table

-- 1. Super admin can access all addresses (check role from profiles table)
CREATE POLICY "super_admin_addresses_access" ON public.addresses
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

-- 2. Allow all authenticated users to read addresses (since there's no ownership/organization field)
-- This is necessary for the sales relationships to work
CREATE POLICY "authenticated_users_read_addresses" ON public.addresses
FOR SELECT
TO authenticated
USING (true);

-- 3. Allow authenticated users to insert addresses
CREATE POLICY "authenticated_users_insert_addresses" ON public.addresses
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Ensure RLS is enabled
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;

-- Test the policies
SELECT 'Addresses RLS policies updated successfully' as message;

-- Show current policies
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'addresses' 
AND schemaname = 'public'
ORDER BY policyname;

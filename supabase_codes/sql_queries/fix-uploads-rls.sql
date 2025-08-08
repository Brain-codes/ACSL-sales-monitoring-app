-- Fix RLS policies for uploads table to allow super_admin access
-- This script creates RLS policies for the uploads table

-- Drop ALL existing policies for uploads table
DO $$
DECLARE
    rec RECORD;
BEGIN
    -- Get all policies for the uploads table and drop them
    FOR rec IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'uploads' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || rec.policyname || '" ON public.uploads';
    END LOOP;
END $$;

-- Create new policies for uploads table

-- 1. Super admin can access all uploads (check role from profiles table)
CREATE POLICY "super_admin_uploads_access" ON public.uploads
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

-- 2. Users can access uploads they created
CREATE POLICY "users_own_uploads" ON public.uploads
FOR ALL
TO authenticated
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- Ensure RLS is enabled
ALTER TABLE public.uploads ENABLE ROW LEVEL SECURITY;

-- Test the policies
SELECT 'Uploads RLS policies updated successfully' as message;

-- Show current policies
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'uploads' 
AND schemaname = 'public'
ORDER BY policyname;

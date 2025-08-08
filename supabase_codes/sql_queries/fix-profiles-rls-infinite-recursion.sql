-- Fix infinite recursion in profiles table RLS policies
-- This script creates proper RLS policies for the profiles table that don't cause infinite recursion

-- Drop existing problematic policies
DROP POLICY IF EXISTS "SELECT" ON public.profiles;
DROP POLICY IF EXISTS "UPDATE" ON public.profiles;
DROP POLICY IF EXISTS "Users Cm read their" ON public.profiles;
DROP POLICY IF EXISTS "update their" ON public.profiles;
DROP POLICY IF EXISTS "Users view from thü org" ON public.profiles;

-- Drop any other policies that might exist
DO $$
DECLARE
    rec RECORD;
BEGIN
    -- Get all policies for the profiles table and drop them
    FOR rec IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'profiles' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || rec.policyname || '" ON public.profiles';
    END LOOP;
END $$;

-- Create new non-recursive policies

-- 1. Super admin can view all profiles
CREATE POLICY "super_admin_select_all_profiles" ON public.profiles
FOR SELECT
TO authenticated
USING (
    -- Check user role directly from auth.users metadata or use a simple approach
    (auth.jwt() ->> 'email') IN (
        'superadmin@mail.com',
        'admin@stove.com',
        'super.admin@mail.com'
    )
    OR
    -- Alternative: Check if user has super_admin role in a non-recursive way
    EXISTS (
        SELECT 1 
        FROM auth.users 
        WHERE auth.users.id = auth.uid() 
        AND (auth.users.raw_user_meta_data ->> 'role') = 'super_admin'
    )
);

-- 2. Users can view their own profile
CREATE POLICY "users_select_own_profile" ON public.profiles
FOR SELECT
TO authenticated
USING (id = auth.uid());

-- 3. Users can view profiles from their organization (non-recursive)
CREATE POLICY "users_select_org_profiles" ON public.profiles
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

-- 4. Super admin can update all profiles
CREATE POLICY "super_admin_update_all_profiles" ON public.profiles
FOR UPDATE
TO authenticated
USING (
    (auth.jwt() ->> 'email') IN (
        'superadmin@mail.com',
        'admin@stove.com',
        'super.admin@mail.com'
    )
    OR
    EXISTS (
        SELECT 1 
        FROM auth.users 
        WHERE auth.users.id = auth.uid() 
        AND (auth.users.raw_user_meta_data ->> 'role') = 'super_admin'
    )
);

-- 5. Users can update their own profile
CREATE POLICY "users_update_own_profile" ON public.profiles
FOR UPDATE
TO authenticated
USING (id = auth.uid());

-- 6. Super admin can insert profiles
CREATE POLICY "super_admin_insert_profiles" ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (
    (auth.jwt() ->> 'email') IN (
        'superadmin@mail.com',
        'admin@stove.com',
        'super.admin@mail.com'
    )
    OR
    EXISTS (
        SELECT 1 
        FROM auth.users 
        WHERE auth.users.id = auth.uid() 
        AND (auth.users.raw_user_meta_data ->> 'role') = 'super_admin'
    )
);

-- 7. Allow profile creation during signup
CREATE POLICY "allow_profile_creation" ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

-- Ensure RLS is enabled
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Test the policies
-- This should work for superadmin@mail.com
SELECT 'Testing profiles access...' as test_message;

-- Show current policies
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'profiles' 
AND schemaname = 'public'
ORDER BY policyname;

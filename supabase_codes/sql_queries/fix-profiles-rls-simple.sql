-- Fix infinite recursion in profiles table RLS policies (SIMPLIFIED VERSION)
-- This script creates simple, non-recursive RLS policies for the profiles table

-- Drop ALL existing policies to start fresh
DROP POLICY IF EXISTS "SELECT" ON public.profiles;
DROP POLICY IF EXISTS "UPDATE" ON public.profiles;
DROP POLICY IF EXISTS "Users Cm read their" ON public.profiles;
DROP POLICY IF EXISTS "update their" ON public.profiles;
DROP POLICY IF EXISTS "Users view from thü org" ON public.profiles;
DROP POLICY IF EXISTS "allow_profile_creation" ON public.profiles;
DROP POLICY IF EXISTS "super_admin_insert_profiles" ON public.profiles;
DROP POLICY IF EXISTS "super_admin_select_all_profiles" ON public.profiles;
DROP POLICY IF EXISTS "super_admin_update_all_profiles" ON public.profiles;
DROP POLICY IF EXISTS "users_select_org_profiles" ON public.profiles;
DROP POLICY IF EXISTS "users_select_own_profile" ON public.profiles;
DROP POLICY IF EXISTS "users_update_own_profile" ON public.profiles;

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

-- Create simple, non-recursive policies

-- 1. Super admin access - check role from auth metadata (no database recursion)
CREATE POLICY "super_admin_full_access" ON public.profiles
FOR ALL
TO authenticated
USING (
    -- Check if user has super_admin role in their auth metadata
    (auth.jwt() ->> 'role') = 'super_admin'
    OR
    -- Check raw_user_meta_data for role
    EXISTS (
        SELECT 1 
        FROM auth.users 
        WHERE auth.users.id = auth.uid() 
        AND (auth.users.raw_user_meta_data ->> 'role') = 'super_admin'
    )
)
WITH CHECK (
    -- Same logic for updates/inserts
    (auth.jwt() ->> 'role') = 'super_admin'
    OR
    EXISTS (
        SELECT 1 
        FROM auth.users 
        WHERE auth.users.id = auth.uid() 
        AND (auth.users.raw_user_meta_data ->> 'role') = 'super_admin'
    )
);

-- 2. Users can access their own profile (no recursion)
CREATE POLICY "users_own_profile_access" ON public.profiles
FOR ALL
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- 3. Allow profile creation during signup
CREATE POLICY "signup_profile_creation" ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

-- Ensure RLS is enabled
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Test the policies
SELECT 'Profiles RLS policies updated successfully' as message;

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

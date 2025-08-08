-- Fix profiles RLS policies - ULTRA SIMPLE VERSION
-- This script creates the most basic RLS policies for profiles table

-- Drop ALL existing policies for profiles table
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

-- Create extremely simple policies

-- 1. Allow users to read their own profile (by primary key match)
CREATE POLICY "users_read_own_profile" ON public.profiles
FOR SELECT
TO authenticated
USING (id = auth.uid());

-- 2. Allow users to update their own profile  
CREATE POLICY "users_update_own_profile" ON public.profiles
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- 3. Allow profile creation during signup (insert policy)
CREATE POLICY "allow_profile_creation" ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

-- 4. Allow super admin identified by email to access all profiles
-- Replace 'superadmin@mail.com' with your actual super admin email
CREATE POLICY "superadmin_email_access" ON public.profiles
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 
        FROM auth.users 
        WHERE auth.users.id = auth.uid() 
        AND auth.users.email = 'superadmin@mail.com'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 
        FROM auth.users 
        WHERE auth.users.id = auth.uid() 
        AND auth.users.email = 'superadmin@mail.com'
    )
);

-- Ensure RLS is enabled
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Test the policies
SELECT 'Ultra-simple profiles RLS policies created successfully' as message;

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

-- Fix RLS policies for super_admin access to related tables
-- This script ensures super_admin can access all related data

-- 1. UPLOADS TABLE - Enable super_admin access
-- Drop existing policies if they exist
DROP POLICY IF EXISTS "super_admin_uploads_select" ON public.uploads;

-- Create comprehensive super_admin policy for uploads
CREATE POLICY "super_admin_uploads_select" ON public.uploads
FOR SELECT 
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role = 'super_admin'
  )
);

-- 2. ADDRESSES TABLE - Enable super_admin access
-- Drop existing policies if they exist
DROP POLICY IF EXISTS "super_admin_addresses_select" ON public.addresses;

-- Create comprehensive super_admin policy for addresses
CREATE POLICY "super_admin_addresses_select" ON public.addresses
FOR SELECT 
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role = 'super_admin'
  )
);

-- 3. PROFILES TABLE - Enable super_admin access to other profiles
-- Drop existing policies if they exist
DROP POLICY IF EXISTS "super_admin_profiles_select" ON public.profiles;

-- Create comprehensive super_admin policy for profiles
CREATE POLICY "super_admin_profiles_select" ON public.profiles
FOR SELECT 
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles p2
    WHERE p2.id = auth.uid() 
    AND p2.role = 'super_admin'
  )
  OR 
  id = auth.uid()
);

-- 4. Verify RLS is enabled on all tables
ALTER TABLE public.uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 5. Check existing policies (for debugging)
SELECT schemaname, tablename, policyname, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('uploads', 'addresses', 'profiles')
ORDER BY tablename, policyname;

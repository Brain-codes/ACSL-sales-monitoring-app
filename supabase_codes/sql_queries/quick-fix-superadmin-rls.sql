-- Quick fix RLS policies for edge function access
-- Run this FIRST before testing the edge function

-- Fix profiles table access
DROP POLICY IF EXISTS "superadmin_email_access" ON public.profiles;
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

-- Fix sales table access  
DROP POLICY IF EXISTS "superadmin_sales_access" ON public.sales;
CREATE POLICY "superadmin_sales_access" ON public.sales
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

-- Fix organizations table access
DROP POLICY IF EXISTS "superadmin_organizations_access" ON public.organizations;
CREATE POLICY "superadmin_organizations_access" ON public.organizations
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 
        FROM auth.users 
        WHERE auth.users.id = auth.uid() 
        AND auth.users.email = 'superadmin@mail.com'
    )
);

-- Fix uploads table access
DROP POLICY IF EXISTS "superadmin_uploads_access" ON public.uploads;
CREATE POLICY "superadmin_uploads_access" ON public.uploads
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 
        FROM auth.users 
        WHERE auth.users.id = auth.uid() 
        AND auth.users.email = 'superadmin@mail.com'
    )
);

-- Fix addresses table access
DROP POLICY IF EXISTS "superadmin_addresses_access" ON public.addresses;
CREATE POLICY "superadmin_addresses_access" ON public.addresses
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 
        FROM auth.users 
        WHERE auth.users.id = auth.uid() 
        AND auth.users.email = 'superadmin@mail.com'
    )
);

-- Ensure RLS is enabled on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;

SELECT 'Super admin RLS policies created successfully!' as message;

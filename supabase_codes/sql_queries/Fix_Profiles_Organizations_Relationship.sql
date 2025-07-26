-- Fix the foreign key relationship between profiles and organizations tables

-- 1. First, ensure the profiles table has the organization_id column with proper type
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS organization_id uuid;

-- 2. Create the foreign key constraint
ALTER TABLE public.profiles 
ADD CONSTRAINT profiles_organization_id_fkey 
FOREIGN KEY (organization_id) 
REFERENCES public.organizations(id) 
ON DELETE SET NULL;

-- 3. Create an index for better performance
CREATE INDEX IF NOT EXISTS idx_profiles_organization_id 
ON public.profiles(organization_id);

-- 4. Update any existing profiles without organization_id (optional)
-- This is only needed if you have existing profiles that need to be linked
-- UPDATE public.profiles 
-- SET organization_id = (SELECT id FROM public.organizations LIMIT 1)
-- WHERE organization_id IS NULL;

-- Verify the relationship was created
SELECT 
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    tc.constraint_name
FROM 
    information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_name='profiles'
  AND kcu.column_name = 'organization_id';

-- Sync user roles from profiles table to auth.users raw_user_meta_data
-- This script will update all existing users and create a trigger for new ones

-- First, let's create a function to sync role from profiles to auth metadata
CREATE OR REPLACE FUNCTION sync_user_role_to_auth()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the auth.users raw_user_meta_data with the role from profiles
    UPDATE auth.users 
    SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('role', NEW.role)
    WHERE id = NEW.id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically sync role when profiles are inserted or updated
DROP TRIGGER IF EXISTS sync_profile_role_trigger ON public.profiles;
CREATE TRIGGER sync_profile_role_trigger
    AFTER INSERT OR UPDATE OF role ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION sync_user_role_to_auth();

-- Now sync all existing users' roles from profiles to auth.users
DO $$
DECLARE
    profile_record RECORD;
    update_count INTEGER := 0;
BEGIN
    -- Loop through all profiles and sync their roles
    FOR profile_record IN 
        SELECT id, role 
        FROM public.profiles 
        WHERE role IS NOT NULL
    LOOP
        -- Update the auth.users table with role from profiles
        UPDATE auth.users 
        SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('role', profile_record.role)
        WHERE id = profile_record.id;
        
        IF FOUND THEN
            update_count := update_count + 1;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Updated % user records with roles from profiles table', update_count;
END $$;

-- Verify the sync worked
SELECT 
    'Role sync completed successfully' as message,
    COUNT(*) as total_users_with_roles
FROM auth.users 
WHERE raw_user_meta_data ? 'role';

-- Show sample of synced data
SELECT 
    email,
    raw_user_meta_data ->> 'role' as auth_role,
    p.role as profile_role
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
WHERE raw_user_meta_data ? 'role'
LIMIT 5;

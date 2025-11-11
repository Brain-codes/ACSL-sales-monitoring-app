-- ================================================================
-- Migration: Add profile_id to credentials table
-- Description: Make credentials table properly relational with profiles
-- Date: November 11, 2025
-- ================================================================

-- Step 1: Add profile_id column to credentials table (nullable initially)
ALTER TABLE credentials 
ADD COLUMN IF NOT EXISTS profile_id UUID;

-- Step 2: Add foreign key constraint to profiles table
ALTER TABLE credentials 
ADD CONSTRAINT fk_credentials_profile 
FOREIGN KEY (profile_id) 
REFERENCES profiles(id) 
ON DELETE CASCADE;

-- Step 3: Create index on profile_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_credentials_profile_id 
ON credentials(profile_id);

-- Step 4: Update existing credentials to link to profiles
-- Match by user_id (which should be the same as profile id)
UPDATE credentials 
SET profile_id = user_id 
WHERE profile_id IS NULL 
  AND user_id IS NOT NULL;

-- Step 5: Verify the update
-- This query shows credentials that are now linked to profiles
SELECT 
  c.partner_id,
  c.partner_name,
  c.email,
  c.username,
  c.role as credentials_role,
  c.profile_id,
  p.id as profile_id_check,
  p.role as profile_role,
  CASE 
    WHEN c.profile_id = p.id THEN '✅ Linked'
    ELSE '❌ Not Linked'
  END as link_status
FROM credentials c
LEFT JOIN profiles p ON c.profile_id = p.id
WHERE c.organization_id IS NOT NULL
ORDER BY c.created_at DESC
LIMIT 20;

-- ================================================================
-- OPTIONAL: Fix NULL roles in profiles table
-- ================================================================

-- Update NULL roles in profiles table to 'admin' for synced organizations
UPDATE profiles 
SET role = 'admin' 
WHERE role IS NULL 
  AND organization_id IS NOT NULL;

-- Verify the fix
SELECT 
  id,
  email,
  username,
  full_name,
  role,
  organization_id,
  created_at
FROM profiles
WHERE organization_id IS NOT NULL
ORDER BY created_at DESC
LIMIT 20;

-- ================================================================
-- Add comment to document the column
-- ================================================================

COMMENT ON COLUMN credentials.profile_id IS 'Foreign key reference to profiles table. Links credentials to their corresponding user profile.';

-- ================================================================
-- Verification Queries
-- ================================================================

-- 1. Check credentials without profile_id
SELECT 
  partner_id, 
  partner_name, 
  email, 
  username,
  user_id,
  profile_id,
  CASE 
    WHEN profile_id IS NULL THEN '⚠️ Missing profile_id'
    ELSE '✅ Has profile_id'
  END as status
FROM credentials
WHERE organization_id IS NOT NULL;

-- 2. Check for orphaned credentials (profile_id not in profiles)
SELECT 
  c.partner_id,
  c.partner_name,
  c.profile_id,
  'Profile does not exist' as issue
FROM credentials c
LEFT JOIN profiles p ON c.profile_id = p.id
WHERE c.profile_id IS NOT NULL 
  AND p.id IS NULL;

-- 3. Compare roles between credentials and profiles
SELECT 
  c.partner_id,
  c.partner_name,
  c.role as credentials_role,
  p.role as profile_role,
  CASE 
    WHEN c.role = p.role THEN '✅ Roles match'
    WHEN c.role IS NOT NULL AND p.role IS NULL THEN '⚠️ Profile role is NULL'
    WHEN c.role IS NULL AND p.role IS NOT NULL THEN '⚠️ Credential role is NULL'
    WHEN c.role != p.role THEN '❌ Roles mismatch'
  END as role_status
FROM credentials c
INNER JOIN profiles p ON c.profile_id = p.id
WHERE c.organization_id IS NOT NULL
ORDER BY c.created_at DESC;

-- ================================================================
-- Success Message
-- ================================================================
-- If you see this, the migration completed successfully!
-- Next steps:
-- 1. Update edge functions to set profile_id when creating credentials
-- 2. Update edge functions to ensure role='admin' in profiles table
-- 3. Test with new CSV sync
-- ================================================================

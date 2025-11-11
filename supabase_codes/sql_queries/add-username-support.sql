-- Migration: Add username support to profiles and credentials tables
-- Purpose: Support flexible login with username OR email
-- Date: 2025-11-10

-- ============================================
-- PART 1: Add username to profiles table
-- ============================================

-- Add username column (nullable because existing users have email, not username)
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS username TEXT UNIQUE;

-- Create index for fast username lookups
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);

-- Add comment for documentation
COMMENT ON COLUMN profiles.username IS 'Unique username for users who do not have a valid email. Used for login alongside email. Either username or email is required.';


-- ============================================
-- PART 2: Update credentials table
-- ============================================

-- Add username column to credentials (nullable for backward compatibility)
ALTER TABLE credentials 
ADD COLUMN IF NOT EXISTS username TEXT;

-- Add comment
COMMENT ON COLUMN credentials.username IS 'Username for organizations without valid email. Stored for Super Admin reference.';


-- ============================================
-- PART 3: Migration for existing users
-- ============================================

-- For users with dummy emails (@atmosfair.site), generate username from email
UPDATE profiles
SET username = REPLACE(email, '@atmosfair.site', '')
WHERE email LIKE '%@atmosfair.site'
AND username IS NULL;

-- Update credentials table to match
UPDATE credentials
SET username = REPLACE(email, '@atmosfair.site', '')
WHERE email LIKE '%@atmosfair.site'
AND username IS NULL;


-- ============================================
-- PART 4: Validation
-- ============================================

-- Verify: Show users with usernames
SELECT 
  id,
  email,
  username,
  full_name,
  role,
  CASE 
    WHEN username IS NOT NULL THEN 'Has Username'
    ELSE 'Email Only'
  END as login_method
FROM profiles
ORDER BY created_at DESC
LIMIT 20;

-- Count users by login method
SELECT 
  CASE 
    WHEN username IS NOT NULL THEN 'Username Login'
    ELSE 'Email Login'
  END as login_type,
  COUNT(*) as user_count
FROM profiles
GROUP BY login_type;


-- ============================================
-- NOTES:
-- ============================================
-- 1. Existing users with valid emails: Keep using email login
-- 2. New users without valid emails: Get username, use username login
-- 3. Both login methods work with the same login endpoint
-- 4. Username format: partner_name_partnerId (e.g., lapo_mfb_gbongan_598581)
-- 5. Internal email format for username users: username@internal.acsl.local

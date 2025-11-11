-- Add role column to credentials table
-- This migration adds a role column to track the user role for each credential
-- Role will always be 'admin' for externally synced organizations

-- Add role column to credentials table
ALTER TABLE credentials 
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'admin';

-- Add comment for documentation
COMMENT ON COLUMN credentials.role IS 'User role for the credential (admin, agent, super_admin). Defaults to admin for synced organizations.';

-- Update existing records to have 'admin' role
UPDATE credentials 
SET role = 'admin' 
WHERE role IS NULL;

-- Create index on role for faster queries
CREATE INDEX IF NOT EXISTS idx_credentials_role ON credentials(role);

-- Verify the changes
SELECT 
  column_name, 
  data_type, 
  column_default,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'credentials' 
  AND column_name = 'role';

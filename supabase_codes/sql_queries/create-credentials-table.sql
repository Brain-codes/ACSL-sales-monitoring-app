-- ============================================================================
-- Create credentials table for external sync partners
-- ============================================================================
-- This table stores auto-generated credentials for partners that don't have
-- email addresses in the CSV data during external synchronization.
-- It provides a reference for partners to log in with auto-generated emails.
-- ============================================================================

-- Create the credentials table
CREATE TABLE IF NOT EXISTS public.credentials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id VARCHAR(255) NOT NULL UNIQUE,
  partner_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  password TEXT NOT NULL, -- Stores plaintext password for reference (admin access only)
  organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  is_dummy_email BOOLEAN DEFAULT true, -- Indicates if email was auto-generated
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_credentials_partner_id ON public.credentials(partner_id);
CREATE INDEX IF NOT EXISTS idx_credentials_email ON public.credentials(email);
CREATE INDEX IF NOT EXISTS idx_credentials_organization_id ON public.credentials(organization_id);
CREATE INDEX IF NOT EXISTS idx_credentials_user_id ON public.credentials(user_id);
CREATE INDEX IF NOT EXISTS idx_credentials_is_dummy_email ON public.credentials(is_dummy_email);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_credentials_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_credentials_updated_at
  BEFORE UPDATE ON public.credentials
  FOR EACH ROW
  EXECUTE FUNCTION update_credentials_updated_at();

-- Enable Row Level Security (RLS)
ALTER TABLE public.credentials ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Only admins and super_admins can view credentials
CREATE POLICY "Admins can view all credentials"
  ON public.credentials
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- RLS Policy: Only system (service role) can insert credentials
CREATE POLICY "Service role can insert credentials"
  ON public.credentials
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- RLS Policy: Only system (service role) can update credentials
CREATE POLICY "Service role can update credentials"
  ON public.credentials
  FOR UPDATE
  TO service_role
  USING (true);

-- RLS Policy: Only super_admins can delete credentials
CREATE POLICY "Super admins can delete credentials"
  ON public.credentials
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'super_admin'
    )
  );

-- Add comments for documentation
COMMENT ON TABLE public.credentials IS 'Stores auto-generated login credentials for external sync partners without email addresses';
COMMENT ON COLUMN public.credentials.partner_id IS 'Unique partner ID from external system';
COMMENT ON COLUMN public.credentials.email IS 'Auto-generated or provided email address (format: partner_name@atmosfair.site for dummy emails)';
COMMENT ON COLUMN public.credentials.password IS 'Plaintext password for admin reference - NOT hashed (use carefully)';
COMMENT ON COLUMN public.credentials.is_dummy_email IS 'True if email was auto-generated because CSV had no email';
COMMENT ON COLUMN public.credentials.organization_id IS 'References the organization this credential belongs to';
COMMENT ON COLUMN public.credentials.user_id IS 'References the auth.users record created for this partner';

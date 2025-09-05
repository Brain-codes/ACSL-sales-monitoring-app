-- Create organization_branches table
-- This script creates the branch management table for organizations

-- Create the table
CREATE TABLE IF NOT EXISTS public.organization_branches (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL,
  name TEXT NOT NULL,
  country TEXT NOT NULL DEFAULT 'Nigeria',
  state TEXT NULL,
  lga TEXT NULL,
  created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
  created_by UUID NOT NULL,
  
  CONSTRAINT organization_branches_pkey PRIMARY KEY (id),
  CONSTRAINT organization_branches_organization_id_fkey 
    FOREIGN KEY (organization_id) 
    REFERENCES public.organizations(id) 
    ON DELETE CASCADE,
  CONSTRAINT organization_branches_name_org_unique 
    UNIQUE (organization_id, name)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_organization_branches_org_id ON public.organization_branches(organization_id);
CREATE INDEX IF NOT EXISTS idx_organization_branches_country ON public.organization_branches(country);
CREATE INDEX IF NOT EXISTS idx_organization_branches_state ON public.organization_branches(state);
CREATE INDEX IF NOT EXISTS idx_organization_branches_created_at ON public.organization_branches(created_at);

-- Create or replace the update trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create the trigger for updated_at
DROP TRIGGER IF EXISTS update_organization_branches_updated_at ON public.organization_branches;
CREATE TRIGGER update_organization_branches_updated_at 
    BEFORE UPDATE ON public.organization_branches 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS
ALTER TABLE public.organization_branches ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Super admin full access" ON public.organization_branches;
DROP POLICY IF EXISTS "Organization admin access" ON public.organization_branches;
DROP POLICY IF EXISTS "Agent read access" ON public.organization_branches;

-- Super admin can do everything
CREATE POLICY "Super admin full access" ON public.organization_branches
  FOR ALL 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'super_admin'
    )
  );

-- Organization admins can manage their organization's branches
CREATE POLICY "Organization admin access" ON public.organization_branches
  FOR ALL 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      JOIN public.organizations o ON p.organization_id = o.id
      WHERE p.id = auth.uid() 
      AND p.role = 'admin'
      AND o.id = organization_branches.organization_id
    )
  );

-- Agents can read their organization's branches
CREATE POLICY "Agent read access" ON public.organization_branches
  FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      JOIN public.organizations o ON p.organization_id = o.id
      WHERE p.id = auth.uid() 
      AND p.role = 'agent'
      AND o.id = organization_branches.organization_id
    )
  );

-- Insert a comment about the table
COMMENT ON TABLE public.organization_branches IS 'Stores branch information for organizations. Each organization can have multiple branches in different locations.';

-- Add column comments
COMMENT ON COLUMN public.organization_branches.id IS 'Primary key for the branch';
COMMENT ON COLUMN public.organization_branches.organization_id IS 'Foreign key to organizations table';
COMMENT ON COLUMN public.organization_branches.name IS 'Name of the branch (must be unique within organization)';
COMMENT ON COLUMN public.organization_branches.country IS 'Country where the branch is located (default: Nigeria)';
COMMENT ON COLUMN public.organization_branches.state IS 'State where the branch is located';
COMMENT ON COLUMN public.organization_branches.lga IS 'Local Government Area where the branch is located';
COMMENT ON COLUMN public.organization_branches.created_at IS 'Timestamp when the branch was created';
COMMENT ON COLUMN public.organization_branches.updated_at IS 'Timestamp when the branch was last updated';
COMMENT ON COLUMN public.organization_branches.created_by IS 'User who created the branch';

-- Show completion message
DO $$
BEGIN
  RAISE NOTICE 'Organization branches table created successfully with RLS policies';
END $$;

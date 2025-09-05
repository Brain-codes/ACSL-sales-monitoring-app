-- Simple creation script for organization_branches table
-- Run this in your Supabase SQL editor

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

-- Enable RLS
ALTER TABLE public.organization_branches ENABLE ROW LEVEL SECURITY;

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

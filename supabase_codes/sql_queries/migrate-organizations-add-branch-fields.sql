-- Migration: Add branch fields to organizations table
-- This script migrates from organization_branches table to organizations.branch field
-- Date: October 1, 2025
-- Purpose: Remove separate branch table, make branch a string field in organizations

-- Step 1: Add new columns to organizations table
DO $$
BEGIN
  -- Add branch column (required)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'organizations' AND column_name = 'branch') THEN
    ALTER TABLE public.organizations 
    ADD COLUMN branch TEXT;
    RAISE NOTICE 'Added branch column to organizations table';
  END IF;

  -- Add contact_phone column (required)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'organizations' AND column_name = 'contact_phone') THEN
    ALTER TABLE public.organizations 
    ADD COLUMN contact_phone TEXT;
    RAISE NOTICE 'Added contact_phone column to organizations table';
  END IF;

  -- Add contact_person column (optional)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'organizations' AND column_name = 'contact_person') THEN
    ALTER TABLE public.organizations 
    ADD COLUMN contact_person TEXT;
    RAISE NOTICE 'Added contact_person column to organizations table';
  END IF;

  -- Add alternative_phone column (optional)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'organizations' AND column_name = 'alternative_phone') THEN
    ALTER TABLE public.organizations 
    ADD COLUMN alternative_phone TEXT;
    RAISE NOTICE 'Added alternative_phone column to organizations table';
  END IF;

  -- Ensure state column exists (it should already exist based on current schema)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'organizations' AND column_name = 'state') THEN
    ALTER TABLE public.organizations 
    ADD COLUMN state TEXT;
    RAISE NOTICE 'Added state column to organizations table';
  END IF;
END
$$;

-- Step 2: Migrate existing data from organization_branches to organizations (if table exists)
DO $$
DECLARE
  branch_record RECORD;
  org_count INTEGER := 0;
  migrated_count INTEGER := 0;
BEGIN
  -- Check if organization_branches table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables 
             WHERE table_name = 'organization_branches' AND table_schema = 'public') THEN
    
    RAISE NOTICE 'Found organization_branches table, starting data migration...';
    
    -- Get count of organizations that will be updated
    SELECT COUNT(*) INTO org_count
    FROM public.organizations o
    INNER JOIN public.organization_branches ob ON o.id = ob.organization_id;
    
    RAISE NOTICE 'Found % organizations with branch data to migrate', org_count;
    
    -- Migrate data from organization_branches to organizations
    -- Note: If an organization has multiple branches, we'll take the first one (created_at ASC)
    -- and concatenate others with " | " separator
    FOR branch_record IN
      SELECT 
        o.id as org_id,
        o.name as org_name,
        string_agg(ob.name, ' | ' ORDER BY ob.created_at) as combined_branches,
        string_agg(ob.state, ' | ' ORDER BY ob.created_at) as combined_states
      FROM public.organizations o
      INNER JOIN public.organization_branches ob ON o.id = ob.organization_id
      GROUP BY o.id, o.name
    LOOP
      -- Update the organization with branch data
      UPDATE public.organizations 
      SET 
        branch = branch_record.combined_branches,
        state = COALESCE(state, branch_record.combined_states) -- Only update state if it's currently null
      WHERE id = branch_record.org_id;
      
      migrated_count := migrated_count + 1;
      
      RAISE NOTICE 'Migrated organization "%" with branches: %', 
        branch_record.org_name, branch_record.combined_branches;
    END LOOP;
    
    RAISE NOTICE 'Successfully migrated % organizations with branch data', migrated_count;
    
  ELSE
    RAISE NOTICE 'No organization_branches table found, skipping data migration';
  END IF;
END
$$;

-- Step 3: Set default values for organizations without branch data
DO $$
DECLARE
  updated_count INTEGER := 0;
BEGIN
  -- Set default branch for organizations that don't have one
  UPDATE public.organizations 
  SET 
    branch = 'Main Branch',
    contact_phone = COALESCE(contact_phone, '+234000000000'),
    state = COALESCE(state, 'Lagos')
  WHERE branch IS NULL OR contact_phone IS NULL OR state IS NULL;
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE 'Set default values for % organizations', updated_count;
END
$$;

-- Step 4: Add NOT NULL constraints to required fields
DO $$
BEGIN
  -- Make branch NOT NULL
  IF EXISTS (SELECT 1 FROM information_schema.columns 
             WHERE table_name = 'organizations' AND column_name = 'branch' 
             AND is_nullable = 'YES') THEN
    ALTER TABLE public.organizations 
    ALTER COLUMN branch SET NOT NULL;
    RAISE NOTICE 'Set branch column to NOT NULL';
  END IF;

  -- Make contact_phone NOT NULL
  IF EXISTS (SELECT 1 FROM information_schema.columns 
             WHERE table_name = 'organizations' AND column_name = 'contact_phone' 
             AND is_nullable = 'YES') THEN
    ALTER TABLE public.organizations 
    ALTER COLUMN contact_phone SET NOT NULL;
    RAISE NOTICE 'Set contact_phone column to NOT NULL';
  END IF;

  -- Make state NOT NULL (if it wasn't already)
  IF EXISTS (SELECT 1 FROM information_schema.columns 
             WHERE table_name = 'organizations' AND column_name = 'state' 
             AND is_nullable = 'YES') THEN
    ALTER TABLE public.organizations 
    ALTER COLUMN state SET NOT NULL;
    RAISE NOTICE 'Set state column to NOT NULL';
  END IF;
END
$$;

-- Step 5: Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_organizations_branch ON public.organizations(branch);
CREATE INDEX IF NOT EXISTS idx_organizations_state ON public.organizations(state);
CREATE INDEX IF NOT EXISTS idx_organizations_contact_phone ON public.organizations(contact_phone);

-- Step 6: Add column comments for documentation
COMMENT ON COLUMN public.organizations.branch IS 'Branch name as string (no longer relational to separate table)';
COMMENT ON COLUMN public.organizations.contact_phone IS 'Primary contact phone number (required)';
COMMENT ON COLUMN public.organizations.state IS 'State location (required)';
COMMENT ON COLUMN public.organizations.contact_person IS 'Contact person name (optional)';
COMMENT ON COLUMN public.organizations.alternative_phone IS 'Alternative contact phone number (optional)';

-- Step 7: Show final schema
DO $$
BEGIN
  RAISE NOTICE '=== MIGRATION COMPLETED ===';
  RAISE NOTICE 'Organizations table now includes:';
  RAISE NOTICE '- branch (TEXT NOT NULL) - Branch name as string';
  RAISE NOTICE '- contact_phone (TEXT NOT NULL) - Primary contact phone';
  RAISE NOTICE '- state (TEXT NOT NULL) - State location';
  RAISE NOTICE '- contact_person (TEXT) - Contact person name';
  RAISE NOTICE '- alternative_phone (TEXT) - Alternative phone';
  RAISE NOTICE '';
  RAISE NOTICE 'Next step: Run the cleanup script to drop organization_branches table';
END
$$;

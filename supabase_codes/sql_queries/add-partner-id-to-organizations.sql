-- Add partner_id column to organizations table for CSV import functionality
-- This column will store the global ID from the external system's CSV files

-- First, check if the column already exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'organizations' 
        AND column_name = 'partner_id' 
        AND table_schema = 'public'
    ) THEN
        -- Add the partner_id column
        ALTER TABLE public.organizations 
        ADD COLUMN partner_id text;
        
        RAISE NOTICE 'Added partner_id column to organizations table';
    ELSE
        RAISE NOTICE 'partner_id column already exists in organizations table';
    END IF;
END $$;

-- Create a unique index on partner_id to prevent duplicates
-- This ensures each Partner ID from CSV can only exist once
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_indexes 
        WHERE tablename = 'organizations' 
        AND indexname = 'organizations_partner_id_key'
    ) THEN
        CREATE UNIQUE INDEX organizations_partner_id_key 
        ON public.organizations(partner_id)
        WHERE partner_id IS NOT NULL;
        
        RAISE NOTICE 'Created unique index on partner_id column';
    ELSE
        RAISE NOTICE 'Unique index on partner_id already exists';
    END IF;
END $$;

-- Add comment to document the purpose of the partner_id column
COMMENT ON COLUMN public.organizations.partner_id IS 'Global ID from external system CSV files for synchronization';

-- Update the organizations table to include proper structure based on current API usage
-- This ensures the table matches what the edge functions expect

-- Add missing columns if they don't exist
DO $$
BEGIN
    -- Add partner_name column (rename from name if needed)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'partner_name'
    ) THEN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'organizations' AND column_name = 'name'
        ) THEN
            -- Rename name to partner_name for consistency
            ALTER TABLE public.organizations RENAME COLUMN name TO partner_name;
            RAISE NOTICE 'Renamed name column to partner_name';
        ELSE
            -- Add partner_name column
            ALTER TABLE public.organizations ADD COLUMN partner_name text NOT NULL DEFAULT 'Unknown Partner';
            RAISE NOTICE 'Added partner_name column';
        END IF;
    END IF;

    -- Add branch column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'branch'
    ) THEN
        ALTER TABLE public.organizations ADD COLUMN branch text NOT NULL DEFAULT 'Main Branch';
        RAISE NOTICE 'Added branch column';
    END IF;

    -- Add state column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'state'
    ) THEN
        ALTER TABLE public.organizations ADD COLUMN state text NOT NULL DEFAULT 'Unknown State';
        RAISE NOTICE 'Added state column';
    END IF;

    -- Add contact_person column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'contact_person'
    ) THEN
        ALTER TABLE public.organizations ADD COLUMN contact_person text;
        RAISE NOTICE 'Added contact_person column';
    END IF;

    -- Add contact_phone column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'contact_phone'
    ) THEN
        ALTER TABLE public.organizations ADD COLUMN contact_phone text;
        RAISE NOTICE 'Added contact_phone column';
    END IF;

    -- Add alternative_phone column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'alternative_phone'
    ) THEN
        ALTER TABLE public.organizations ADD COLUMN alternative_phone text;
        RAISE NOTICE 'Added alternative_phone column';
    END IF;

    -- Add email column (rename from partner_email if needed)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'email'
    ) THEN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'organizations' AND column_name = 'partner_email'
        ) THEN
            -- Rename partner_email to email for consistency
            ALTER TABLE public.organizations RENAME COLUMN partner_email TO email;
            -- Remove the unique constraint on the old name if it exists
            DO $inner$ BEGIN
                ALTER TABLE public.organizations DROP CONSTRAINT IF EXISTS organizations_partner_email_key;
            EXCEPTION WHEN OTHERS THEN 
                NULL; -- Ignore errors if constraint doesn't exist
            END $inner$;
            RAISE NOTICE 'Renamed partner_email column to email';
        ELSE
            -- Add email column
            ALTER TABLE public.organizations ADD COLUMN email text;
            RAISE NOTICE 'Added email column';
        END IF;
    END IF;

    -- Add address column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'address'
    ) THEN
        ALTER TABLE public.organizations ADD COLUMN address text;
        RAISE NOTICE 'Added address column';
    END IF;

    -- Add updated_at column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE public.organizations ADD COLUMN updated_at timestamp with time zone DEFAULT now();
        RAISE NOTICE 'Added updated_at column';
    END IF;

    -- Add created_by column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'created_by'
    ) THEN
        ALTER TABLE public.organizations ADD COLUMN created_by uuid REFERENCES auth.users(id);
        RAISE NOTICE 'Added created_by column';
    END IF;

    -- Add updated_by column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'updated_by'
    ) THEN
        ALTER TABLE public.organizations ADD COLUMN updated_by uuid REFERENCES auth.users(id);
        RAISE NOTICE 'Added updated_by column';
    END IF;
END $$;

-- Create or replace the trigger function for updating updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create the trigger for updated_at
DROP TRIGGER IF EXISTS update_organizations_updated_at ON public.organizations;
CREATE TRIGGER update_organizations_updated_at
    BEFORE UPDATE ON public.organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Final completion message and table structure display
DO $$
DECLARE
    rec RECORD;
BEGIN
    RAISE NOTICE 'Organizations table updated successfully for CSV import functionality';
    
    -- Display final table structure
    RAISE NOTICE 'Current organizations table structure:';
    FOR rec IN 
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns 
        WHERE table_name = 'organizations' AND table_schema = 'public'
        ORDER BY ordinal_position
    LOOP
        RAISE NOTICE '  %: % (nullable: %, default: %)', 
            rec.column_name, rec.data_type, rec.is_nullable, COALESCE(rec.column_default, 'none');
    END LOOP;
END $$;

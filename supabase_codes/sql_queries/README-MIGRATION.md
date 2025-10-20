# Organization Branch Structure Migration

This directory contains SQL scripts for migrating from a separate `organization_branches` table to using `branch` as a string field in the `organizations` table.

## Migration Overview

**Before:** Organizations had separate branches in `organization_branches` table with foreign key relationships.

**After:** Organizations have a `branch` field as a simple string, along with other required contact fields.

## Required Fields After Migration

The `organizations` table will have these new required fields:

- `branch` (TEXT NOT NULL) - Branch name as string
- `contact_phone` (TEXT NOT NULL) - Primary contact phone
- `state` (TEXT NOT NULL) - State location

And these optional fields:

- `contact_person` (TEXT) - Contact person name
- `alternative_phone` (TEXT) - Alternative phone number

## Migration Process

### Step 1: Run the Migration Script

```sql
-- Execute this file to add new columns and migrate data
\i supabase_codes/sql_queries/migrate-organizations-add-branch-fields.sql
```

This script will:

1. Add new columns to `organizations` table
2. Migrate existing data from `organization_branches` to `organizations.branch`
3. Set default values for organizations without branch data
4. Add NOT NULL constraints
5. Add performance indexes

### Step 2: Verify Migration

After running the migration, verify:

1. All organizations have `branch`, `contact_phone`, and `state` values
2. Branch data was migrated correctly from the old table
3. Application still works with new structure

### Step 3: Update Application Code

Update your application to:

1. Use `organizations.branch` instead of querying `organization_branches` table
2. Include new required fields in organization creation/update forms
3. Remove any references to the old `manage-branches` edge function

### Step 4: Run Cleanup Script (ONLY AFTER VERIFICATION)

```sql
-- Execute this file to remove the old table structure
\i supabase_codes/sql_queries/cleanup-drop-organization-branches-table.sql
```

This script will:

1. Drop the `organization_branches` table
2. Remove all related constraints, indexes, and policies
3. Clean up unused functions

## Emergency Rollback

If something goes wrong, you can rollback using:

```sql
-- ONLY use this if you need to rollback the migration
\i supabase_codes/sql_queries/rollback-restore-organization-branches.sql
```

⚠️ **Warning:** The rollback script will recreate the old table structure and move data back. Only use this if the migration failed or you need to revert for some reason.

## Files in this Migration

1. **`migrate-organizations-add-branch-fields.sql`** - Main migration script
2. **`cleanup-drop-organization-branches-table.sql`** - Cleanup old table (run after verification)
3. **`rollback-restore-organization-branches.sql`** - Emergency rollback (use only if needed)
4. **`README-MIGRATION.md`** - This documentation file

## Data Migration Details

### Single Branch Organizations

If an organization has one branch in `organization_branches`, it will be migrated directly to `organizations.branch`.

### Multiple Branch Organizations

If an organization has multiple branches, they will be combined into a single string with " | " separator:

- Example: "Lagos Main | Abuja Branch | Port Harcourt"

### Default Values

Organizations without branch data will get default values:

- `branch`: "Main Branch"
- `contact_phone`: "+234000000000"
- `state`: "Lagos"

## Testing

Before running in production:

1. Test the migration on a copy of your database
2. Verify all data is migrated correctly
3. Test your application with the new structure
4. Ensure all API endpoints work properly

## API Changes

The `manage-organizations` API now requires these additional fields:

- `branch` (required)
- `contact_phone` (required)
- `state` (required)
- `contact_person` (optional)
- `alternative_phone` (optional)

Example API request:

```json
{
  "name": "Organization Name",
  "branch": "Main Branch",
  "partner_email": "contact@org.com",
  "contact_phone": "+234123456789",
  "state": "Lagos",
  "contact_person": "John Doe",
  "admin_full_name": "Admin Name",
  "admin_email": "admin@org.com"
}
```

## Support

If you encounter any issues during migration:

1. Check the PostgreSQL logs for detailed error messages
2. Verify your database has sufficient permissions
3. Ensure no other processes are using the tables during migration
4. Keep backups of your data before running any scripts

## Migration Checklist

- [ ] Backup your database
- [ ] Run migration script
- [ ] Verify data migration was successful
- [ ] Update application code to use new structure
- [ ] Test all functionality thoroughly
- [ ] Run cleanup script to remove old table
- [ ] Update API documentation
- [ ] Deploy updated application code

---

**Date:** October 1, 2025  
**Status:** Ready for execution  
**Breaking Changes:** Yes - API structure changes required

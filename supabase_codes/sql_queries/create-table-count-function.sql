-- SQL function to count records in any table (for debugging)
-- This helps bypass RLS for debugging purposes

CREATE OR REPLACE FUNCTION get_table_count(table_name text)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER -- This allows the function to run with elevated privileges
AS $$
DECLARE
    result integer;
BEGIN
    -- Execute dynamic SQL to count records
    EXECUTE format('SELECT count(*) FROM %I', table_name) INTO result;
    RETURN result;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_table_count(text) TO authenticated;

-- Example usage:
-- SELECT get_table_count('sales');

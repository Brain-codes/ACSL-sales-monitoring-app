-- Fixed External App Token Management System
-- This corrects the schema mismatch issues

-- First, let's make sure we have the correct table structure
-- Run this to check if the table exists and has the right structure
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'external_app_tokens') THEN
        RAISE NOTICE 'external_app_tokens table does not exist. Please check your table structure.';
    ELSE
        RAISE NOTICE 'external_app_tokens table exists.';
    END IF;
END $$;

-- Insert sample external app token for testing
-- This should be replaced with proper token generation in production
INSERT INTO external_app_tokens (
    id,
    token,
    secret_key,
    application_name,
    application_description,
    allowed_urls,
    is_active,
    usage_count,
    created_at
) VALUES (
    gen_random_uuid(),
    'test-token-12345', -- This should be a secure random token in production
    'test-secret-67890', -- This should be a secure random secret in production
    'Test External App',
    'Testing application for external sync functionality',
    ARRAY['localhost', 'test.example.com', '*'], -- '*' allows any URL
    true,
    0,
    NOW()
) ON CONFLICT (token) DO NOTHING;

-- Create function to generate secure tokens (for production use)
CREATE OR REPLACE FUNCTION generate_external_app_token(
    app_name TEXT,
    app_description TEXT DEFAULT NULL,
    allowed_urls TEXT[] DEFAULT ARRAY['*']
)
RETURNS TABLE(
    token TEXT,
    secret_key TEXT,
    application_name TEXT
) AS $$
DECLARE
    new_token TEXT;
    new_secret TEXT;
BEGIN
    -- Generate secure random token and secret
    new_token := 'ext_' || encode(gen_random_bytes(32), 'base64');
    new_secret := 'sec_' || encode(gen_random_bytes(32), 'base64');
    
    -- Clean up the tokens (remove special characters that might cause issues)
    new_token := replace(replace(replace(new_token, '/', '_'), '+', '-'), '=', '');
    new_secret := replace(replace(replace(new_secret, '/', '_'), '+', '-'), '=', '');
    
    -- Insert the new token
    INSERT INTO external_app_tokens (
        id,
        token,
        secret_key,
        application_name,
        application_description,
        allowed_urls,
        is_active,
        usage_count,
        created_at
    ) VALUES (
        gen_random_uuid(),
        new_token,
        new_secret,
        app_name,
        app_description,
        allowed_urls,
        true,
        0,
        NOW()
    );
    
    -- Return the generated credentials
    RETURN QUERY SELECT new_token, new_secret, app_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to revoke/deactivate a token (FIXED - removed updated_at)
CREATE OR REPLACE FUNCTION revoke_external_app_token(token_to_revoke TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE external_app_tokens 
    SET is_active = false
    WHERE token = token_to_revoke;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to list all active tokens (for admin use)
CREATE OR REPLACE FUNCTION list_external_app_tokens()
RETURNS TABLE(
    token TEXT,
    application_name TEXT,
    application_description TEXT,
    allowed_urls TEXT[],
    usage_count INTEGER,
    last_used_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        t.token,
        t.application_name,
        t.application_description,
        t.allowed_urls,
        t.usage_count,
        t.last_used_at,
        t.created_at
    FROM external_app_tokens t
    WHERE t.is_active = true
    ORDER BY t.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Test the functions
-- Uncomment these lines to test after running the script:

-- 1. Test token generation
-- SELECT 'Testing token generation:' as test_step;
-- SELECT * FROM generate_external_app_token(
--     'My Test App',
--     'Test application for development',
--     ARRAY['localhost:3000', '*.example.com']
-- );

-- 2. Test listing tokens
-- SELECT 'Testing token listing:' as test_step;
-- SELECT * FROM list_external_app_tokens();

-- 3. Test token revocation (use a token from step 1)
-- SELECT 'Testing token revocation:' as test_step;
-- SELECT revoke_external_app_token('your-generated-token-here');

COMMENT ON FUNCTION generate_external_app_token IS 'Generates a new secure token and secret key for external application access';
COMMENT ON FUNCTION revoke_external_app_token IS 'Deactivates an external application token (FIXED: removed updated_at column reference)';
COMMENT ON FUNCTION list_external_app_tokens IS 'Lists all active external application tokens with usage statistics';

-- Final verification
SELECT 'Setup completed successfully. You can now:' as status,
       '1. Generate tokens using generate_external_app_token()' as step_1,
       '2. List active tokens using list_external_app_tokens()' as step_2,
       '3. Revoke tokens using revoke_external_app_token()' as step_3;

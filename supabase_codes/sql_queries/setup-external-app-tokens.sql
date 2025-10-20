-- Create External App Token Management System
-- This system allows secure API access for external applications

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

-- Create function to revoke/deactivate a token
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

-- Example usage to generate a new token:
-- SELECT * FROM generate_external_app_token(
--     'My External App',
--     'Production application for syncing organization data',
--     ARRAY['production.example.com', 'staging.example.com']
-- );

-- Example usage to list all tokens:
-- SELECT * FROM list_external_app_tokens();

-- Example usage to revoke a token:
-- SELECT revoke_external_app_token('ext_your_token_here');

-- Grant necessary permissions for the external app token functions
-- (These functions use SECURITY DEFINER so they run with elevated privileges)

COMMENT ON FUNCTION generate_external_app_token IS 'Generates a new secure token and secret key for external application access';
COMMENT ON FUNCTION revoke_external_app_token IS 'Deactivates an external application token';
COMMENT ON FUNCTION list_external_app_tokens IS 'Lists all active external application tokens with usage statistics';

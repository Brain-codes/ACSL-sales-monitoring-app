-- Sales History Queries
-- These are the parameterized queries used in the application

-- Query to get sales history for a specific sale
-- Parameters: $1 = sale_id (uuid)
SELECT 
    sh.id,
    sh.sale_id,
    sh.action_type,
    sh.action_description,
    sh.field_changes,
    sh.performed_by,
    sh.performed_at,
    s.transaction_id,
    s.stove_serial_no,
    s.contact_person,
    s.end_user_name,
    s.amount,
    s.status,
    p.full_name as performer_name,
    p.email as performer_email,
    p.role as performer_role
FROM sales_history sh
JOIN sales s ON s.id = sh.sale_id
JOIN profiles p ON p.id = sh.performed_by
WHERE sh.sale_id = $1
ORDER BY sh.performed_at DESC;

-- Query to get all history for a user's organization
-- Parameters: $1 = organization_id (uuid), $2 = limit (int), $3 = offset (int)
SELECT 
    sh.id,
    sh.sale_id,
    sh.action_type,
    sh.action_description,
    sh.field_changes,
    sh.performed_by,
    sh.performed_at,
    s.transaction_id,
    s.stove_serial_no,
    s.contact_person,
    s.end_user_name,
    s.amount,
    s.status,
    p.full_name as performer_name,
    p.email as performer_email,
    p.role as performer_role
FROM sales_history sh
JOIN sales s ON s.id = sh.sale_id
JOIN profiles p ON p.id = sh.performed_by
WHERE s.organization_id = $1
ORDER BY sh.performed_at DESC
LIMIT $2 OFFSET $3;

-- Query to get activity stats for a user or organization
-- Parameters: $1 = organization_id (uuid), $2 = user_id (uuid, optional), $3 = start_date (timestamp, optional), $4 = end_date (timestamp, optional)
SELECT 
    COUNT(*) as total_activities,
    COUNT(CASE WHEN action_type = 'created' THEN 1 END) as created_count,
    COUNT(CASE WHEN action_type = 'updated' THEN 1 END) as updated_count,
    COUNT(CASE WHEN action_type = 'completed' THEN 1 END) as completed_count,
    COUNT(CASE WHEN action_type = 'assigned' THEN 1 END) as assigned_count
FROM sales_history sh
JOIN sales s ON s.id = sh.sale_id
WHERE s.organization_id = $1
    AND ($2::uuid IS NULL OR sh.performed_by = $2)
    AND ($3::timestamp IS NULL OR sh.performed_at >= $3)
    AND ($4::timestamp IS NULL OR sh.performed_at <= $4);

-- Query to search history by description or sale details
-- Parameters: $1 = organization_id (uuid), $2 = search_term (text), $3 = limit (int), $4 = offset (int)
SELECT 
    sh.id,
    sh.sale_id,
    sh.action_type,
    sh.action_description,
    sh.field_changes,
    sh.performed_by,
    sh.performed_at,
    s.transaction_id,
    s.stove_serial_no,
    s.contact_person,
    s.end_user_name,
    s.amount,
    s.status,
    p.full_name as performer_name,
    p.email as performer_email,
    p.role as performer_role
FROM sales_history sh
JOIN sales s ON s.id = sh.sale_id
JOIN profiles p ON p.id = sh.performed_by
WHERE s.organization_id = $1
    AND (
        sh.action_description ILIKE '%' || $2 || '%'
        OR s.transaction_id ILIKE '%' || $2 || '%'
        OR s.contact_person ILIKE '%' || $2 || '%'
        OR s.end_user_name ILIKE '%' || $2 || '%'
        OR p.full_name ILIKE '%' || $2 || '%'
    )
ORDER BY sh.performed_at DESC
LIMIT $3 OFFSET $4;

-- ========================================
-- TEST QUERIES (for running in Supabase SQL Editor)
-- Replace the UUIDs with actual values from your database
-- ========================================

-- Test: Get sales history for a specific sale
-- Replace 'your-sale-id-here' with an actual sale ID
SELECT 
    sh.id,
    sh.sale_id,
    sh.action_type,
    sh.action_description,
    sh.field_changes,
    sh.performed_by,
    sh.performed_at,
    s.transaction_id,
    s.stove_serial_no,
    s.contact_person,
    s.end_user_name,
    s.amount,
    s.status,
    p.full_name as performer_name,
    p.email as performer_email,
    p.role as performer_role
FROM sales_history sh
JOIN sales s ON s.id = sh.sale_id
JOIN profiles p ON p.id = sh.performed_by
WHERE sh.sale_id = 'your-sale-id-here'
ORDER BY sh.performed_at DESC;

-- Test: Get recent history for an organization
-- Replace 'your-organization-id-here' with an actual organization ID
SELECT 
    sh.id,
    sh.sale_id,
    sh.action_type,
    sh.action_description,
    sh.field_changes,
    sh.performed_by,
    sh.performed_at,
    s.transaction_id,
    s.stove_serial_no,
    s.contact_person,
    s.end_user_name,
    s.amount,
    s.status,
    p.full_name as performer_name,
    p.email as performer_email,
    p.role as performer_role
FROM sales_history sh
JOIN sales s ON s.id = sh.sale_id
JOIN profiles p ON p.id = sh.performed_by
WHERE s.organization_id = 'your-organization-id-here'
ORDER BY sh.performed_at DESC
LIMIT 50 OFFSET 0;

-- Test: Get activity stats for an organization
-- Replace 'your-organization-id-here' with an actual organization ID
SELECT 
    COUNT(*) as total_activities,
    COUNT(CASE WHEN action_type = 'created' THEN 1 END) as created_count,
    COUNT(CASE WHEN action_type = 'updated' THEN 1 END) as updated_count,
    COUNT(CASE WHEN action_type = 'completed' THEN 1 END) as completed_count,
    COUNT(CASE WHEN action_type = 'assigned' THEN 1 END) as assigned_count
FROM sales_history sh
JOIN sales s ON s.id = sh.sale_id
WHERE s.organization_id = 'your-organization-id-here';

-- Test: Search history by description
-- Replace 'your-organization-id-here' with an actual organization ID
-- Replace 'search term' with what you want to search for
SELECT 
    sh.id,
    sh.sale_id,
    sh.action_type,
    sh.action_description,
    sh.field_changes,
    sh.performed_by,
    sh.performed_at,
    s.transaction_id,
    s.stove_serial_no,
    s.contact_person,
    s.end_user_name,
    s.amount,
    s.status,
    p.full_name as performer_name,
    p.email as performer_email,
    p.role as performer_role
FROM sales_history sh
JOIN sales s ON s.id = sh.sale_id
JOIN profiles p ON p.id = sh.performed_by
WHERE s.organization_id = 'your-organization-id-here'
    AND (
        sh.action_description ILIKE '%search term%'
        OR s.transaction_id ILIKE '%search term%'
        OR s.contact_person ILIKE '%search term%'
        OR s.end_user_name ILIKE '%search term%'
        OR p.full_name ILIKE '%search term%'
    )
ORDER BY sh.performed_at DESC
LIMIT 20 OFFSET 0;

-- ========================================
-- UTILITY QUERIES FOR TESTING
-- ========================================

-- Get sample organization IDs
SELECT id, name FROM organizations LIMIT 5;

-- Get sample sale IDs  
SELECT id, transaction_id, contact_person FROM sales LIMIT 5;

-- Get sample user IDs
SELECT id, full_name, email FROM profiles LIMIT 5;

-- Check if sales_history table has data
SELECT COUNT(*) as history_count FROM sales_history;

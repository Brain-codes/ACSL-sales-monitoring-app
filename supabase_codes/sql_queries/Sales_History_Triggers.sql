-- Sales History Triggers
-- These triggers automatically create history records when sales are modified

-- Create comprehensive history tracking for sales table
CREATE OR REPLACE FUNCTION create_sales_history()
RETURNS TRIGGER AS $$
DECLARE
    action_type VARCHAR(50);
    action_description TEXT;
    field_changes JSONB := '{}'::jsonb;
    change_details TEXT[];
    user_context JSONB;
    user_id UUID;
BEGIN
    -- Get current user ID (from auth context or from a custom header)
    user_id := auth.uid();
    
    -- If no auth user, try to get from custom context (for edge functions)
    IF user_id IS NULL THEN
        user_id := current_setting('app.current_user_id', true)::UUID;
    END IF;
    
    -- If still no user, use a system user or skip
    IF user_id IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    -- Determine action type and build field changes
    IF TG_OP = 'INSERT' THEN
        action_type := 'created';
        action_description := 'Sale created with transaction ID: ' || NEW.transaction_id;
        
        -- Store initial values
        field_changes := jsonb_build_object(
            'new_values', row_to_json(NEW),
            'initial_creation', true
        );
        
    ELSIF TG_OP = 'UPDATE' THEN
        -- Determine specific update type
        IF OLD.status != NEW.status THEN
            CASE NEW.status
                WHEN 'completed' THEN
                    action_type := 'completed';
                    action_description := 'Sale marked as completed';
                WHEN 'assigned' THEN
                    action_type := 'assigned';
                    action_description := 'Sale assigned to agent';
                WHEN 'cancelled' THEN
                    action_type := 'cancelled';
                    action_description := 'Sale cancelled';
                ELSE
                    action_type := 'updated';
                    action_description := 'Sale status changed from ' || OLD.status || ' to ' || NEW.status;
            END CASE;
        ELSE
            action_type := 'updated';
            action_description := 'Sale details updated';
        END IF;
        
        -- Build detailed field changes
        SELECT jsonb_object_agg(field_name, changes)
        INTO field_changes
        FROM (
            SELECT 
                field_name,
                jsonb_build_object(
                    'old_value', old_value,
                    'new_value', new_value
                ) as changes
            FROM (
                -- Compare all relevant fields
                SELECT 'transaction_id' as field_name, to_jsonb(OLD.transaction_id) as old_value, to_jsonb(NEW.transaction_id) as new_value
                WHERE OLD.transaction_id IS DISTINCT FROM NEW.transaction_id
                UNION ALL
                SELECT 'amount', to_jsonb(OLD.amount), to_jsonb(NEW.amount)
                WHERE OLD.amount IS DISTINCT FROM NEW.amount
                UNION ALL
                SELECT 'status', to_jsonb(OLD.status), to_jsonb(NEW.status)
                WHERE OLD.status IS DISTINCT FROM NEW.status
                UNION ALL
                SELECT 'contact_person', to_jsonb(OLD.contact_person), to_jsonb(NEW.contact_person)
                WHERE OLD.contact_person IS DISTINCT FROM NEW.contact_person
                UNION ALL
                SELECT 'end_user_name', to_jsonb(OLD.end_user_name), to_jsonb(NEW.end_user_name)
                WHERE OLD.end_user_name IS DISTINCT FROM NEW.end_user_name
                UNION ALL
                SELECT 'stove_serial_no', to_jsonb(OLD.stove_serial_no), to_jsonb(NEW.stove_serial_no)
                WHERE OLD.stove_serial_no IS DISTINCT FROM NEW.stove_serial_no
                UNION ALL
                SELECT 'assigned_to', to_jsonb(OLD.assigned_to), to_jsonb(NEW.assigned_to)
                WHERE OLD.assigned_to IS DISTINCT FROM NEW.assigned_to
                UNION ALL
                SELECT 'location', to_jsonb(OLD.location), to_jsonb(NEW.location)
                WHERE OLD.location IS DISTINCT FROM NEW.location
                UNION ALL
                SELECT 'notes', to_jsonb(OLD.notes), to_jsonb(NEW.notes)
                WHERE OLD.notes IS DISTINCT FROM NEW.notes
            ) field_comparisons
            WHERE field_name IS NOT NULL
        ) changes_summary;
        
        -- If no changes detected, don't create history record
        IF field_changes = '{}'::jsonb THEN
            RETURN NEW;
        END IF;
        
    ELSIF TG_OP = 'DELETE' THEN
        action_type := 'deleted';
        action_description := 'Sale deleted: ' || OLD.transaction_id;
        field_changes := jsonb_build_object(
            'deleted_values', row_to_json(OLD)
        );
    END IF;

    -- Get additional user context
    SELECT jsonb_build_object(
        'user_agent', current_setting('request.headers', true)::json->>'user-agent',
        'ip_address', current_setting('request.headers', true)::json->>'x-forwarded-for'
    ) INTO user_context;

    -- Insert history record
    INSERT INTO sales_history (
        sale_id,
        action_type,
        action_description,
        field_changes,
        performed_by,
        performed_at,
        ip_address,
        user_agent
    ) VALUES (
        COALESCE(NEW.id, OLD.id),
        action_type,
        action_description,
        field_changes,
        user_id,
        NOW(),
        (user_context->>'ip_address')::INET,
        user_context->>'user_agent'
    );

    RETURN COALESCE(NEW, OLD);
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't fail the main operation
        RAISE WARNING 'Failed to create sales history: %', SQLERRM;
        RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers for the sales table
DROP TRIGGER IF EXISTS sales_history_trigger ON sales;
CREATE TRIGGER sales_history_trigger
    AFTER INSERT OR UPDATE OR DELETE ON sales
    FOR EACH ROW
    EXECUTE FUNCTION create_sales_history();

-- Function to manually create history records (for edge functions)
CREATE OR REPLACE FUNCTION manual_create_sales_history(
    p_sale_id UUID,
    p_action_type VARCHAR(50),
    p_action_description TEXT,
    p_field_changes JSONB DEFAULT NULL,
    p_performed_by UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    history_id UUID;
    user_id UUID;
BEGIN
    -- Use provided user or current auth user
    user_id := COALESCE(p_performed_by, auth.uid());
    
    -- If still no user, try custom setting
    IF user_id IS NULL THEN
        user_id := current_setting('app.current_user_id', true)::UUID;
    END IF;
    
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'No user context available for history creation';
    END IF;

    -- Insert history record
    INSERT INTO sales_history (
        sale_id,
        action_type,
        action_description,
        field_changes,
        performed_by,
        performed_at
    ) VALUES (
        p_sale_id,
        p_action_type,
        p_action_description,
        COALESCE(p_field_changes, '{}'::jsonb),
        user_id,
        NOW()
    ) RETURNING id INTO history_id;

    RETURN history_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get sales history with pagination
CREATE OR REPLACE FUNCTION get_sales_history(
    p_organization_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0,
    p_action_type VARCHAR(50) DEFAULT NULL,
    p_start_date TIMESTAMP DEFAULT NULL,
    p_end_date TIMESTAMP DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    sale_id UUID,
    action_type VARCHAR(50),
    action_description TEXT,
    field_changes JSONB,
    performed_by UUID,
    performed_at TIMESTAMP WITH TIME ZONE,
    transaction_id VARCHAR(255),
    sale_amount DECIMAL(15,2),
    sale_status VARCHAR(50),
    performer_name TEXT,
    performer_email TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sh.id,
        sh.sale_id,
        sh.action_type,
        sh.action_description,
        sh.field_changes,
        sh.performed_by,
        sh.performed_at,
        s.transaction_id,
        s.amount as sale_amount,
        s.status as sale_status,
        p.full_name as performer_name,
        p.email as performer_email
    FROM sales_history sh
    JOIN sales s ON s.id = sh.sale_id
    JOIN profiles p ON p.id = sh.performed_by
    WHERE s.organization_id = p_organization_id
        AND (p_user_id IS NULL OR sh.performed_by = p_user_id)
        AND (p_action_type IS NULL OR sh.action_type = p_action_type)
        AND (p_start_date IS NULL OR sh.performed_at >= p_start_date)
        AND (p_end_date IS NULL OR sh.performed_at <= p_end_date)
    ORDER BY sh.performed_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

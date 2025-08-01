-- Sales History Table
CREATE TABLE IF NOT EXISTS sales_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    action_type VARCHAR(50) NOT NULL, -- 'created', 'updated', 'assigned', 'completed'
    action_description TEXT NOT NULL,
    field_changes JSONB, -- Store field changes for updates
    performed_by UUID NOT NULL REFERENCES auth.users(id),
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_sales_history_sale_id ON sales_history(sale_id);
CREATE INDEX IF NOT EXISTS idx_sales_history_performed_by ON sales_history(performed_by);
CREATE INDEX IF NOT EXISTS idx_sales_history_action_type ON sales_history(action_type);
CREATE INDEX IF NOT EXISTS idx_sales_history_performed_at ON sales_history(performed_at DESC);

-- Enable RLS
ALTER TABLE sales_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own history" ON sales_history
    FOR SELECT USING (
        performed_by = auth.uid() OR 
        EXISTS (
            SELECT 1 FROM sales s 
            WHERE s.id = sales_history.sale_id 
            AND s.organization_id IN (
                SELECT organization_id FROM profiles WHERE id = auth.uid()
            )
        )
    );

CREATE POLICY "System can insert history" ON sales_history
    FOR INSERT WITH CHECK (true);

-- Enhanced trigger function to automatically create comprehensive history records
CREATE OR REPLACE FUNCTION create_sales_history()
RETURNS TRIGGER AS $$
DECLARE
    action_type VARCHAR(50);
    action_description TEXT;
    field_changes JSONB := '{}'::jsonb;
    change_details TEXT[];
    user_context JSONB;
BEGIN
    -- Get user context (role, name, etc.)
    SELECT jsonb_build_object(
        'role', p.role,
        'name', p.full_name,
        'email', p.email,
        'organization_id', p.organization_id
    ) INTO user_context
    FROM profiles p 
    WHERE p.id = auth.uid();
    
    -- Determine action type
    IF TG_OP = 'INSERT' THEN
        action_type := 'created';
        action_description := format('Sale record created for %s (Serial: %s)', 
            COALESCE(NEW.end_user_name, 'Unknown Customer'), 
            COALESCE(NEW.stove_serial_no, 'N/A'));
        
        -- Include initial values for new record
        field_changes := jsonb_build_object(
            'initial_values', jsonb_build_object(
                'status', NEW.status,
                'amount', NEW.amount,
                'end_user_name', NEW.end_user_name,
                'contact_person', NEW.contact_person,
                'contact_phone', NEW.contact_phone,
                'stove_serial_no', NEW.stove_serial_no,
                'partner_name', NEW.partner_name
            )
        );
        
    ELSIF TG_OP = 'UPDATE' THEN
        action_type := 'updated';
        
        -- Track comprehensive field changes
        IF OLD.status IS DISTINCT FROM NEW.status THEN
            field_changes := field_changes || jsonb_build_object(
                'status', jsonb_build_object(
                    'from', OLD.status, 
                    'to', NEW.status,
                    'timestamp', NOW()
                )
            );
            change_details := array_append(change_details, 
                format('Status: %s → %s', 
                    COALESCE(OLD.status, 'null'), 
                    COALESCE(NEW.status, 'null')));
        END IF;
        
        IF OLD.contact_person IS DISTINCT FROM NEW.contact_person THEN
            field_changes := field_changes || jsonb_build_object(
                'contact_person', jsonb_build_object(
                    'from', OLD.contact_person, 
                    'to', NEW.contact_person,
                    'timestamp', NOW()
                )
            );
            change_details := array_append(change_details, 'Contact person updated');
        END IF;
        
        IF OLD.contact_phone IS DISTINCT FROM NEW.contact_phone THEN
            field_changes := field_changes || jsonb_build_object(
                'contact_phone', jsonb_build_object(
                    'from', OLD.contact_phone, 
                    'to', NEW.contact_phone,
                    'timestamp', NOW()
                )
            );
            change_details := array_append(change_details, 'Contact phone updated');
        END IF;
        
        IF OLD.end_user_name IS DISTINCT FROM NEW.end_user_name THEN
            field_changes := field_changes || jsonb_build_object(
                'end_user_name', jsonb_build_object(
                    'from', OLD.end_user_name, 
                    'to', NEW.end_user_name,
                    'timestamp', NOW()
                )
            );
            change_details := array_append(change_details, 'Customer name updated');
        END IF;
        
        IF OLD.amount IS DISTINCT FROM NEW.amount THEN
            field_changes := field_changes || jsonb_build_object(
                'amount', jsonb_build_object(
                    'from', OLD.amount, 
                    'to', NEW.amount,
                    'timestamp', NOW()
                )
            );
            change_details := array_append(change_details, 
                format('Amount: GHS %s → GHS %s', 
                    COALESCE(OLD.amount::text, '0'), 
                    COALESCE(NEW.amount::text, '0')));
        END IF;
        
        IF OLD.stove_serial_no IS DISTINCT FROM NEW.stove_serial_no THEN
            field_changes := field_changes || jsonb_build_object(
                'stove_serial_no', jsonb_build_object(
                    'from', OLD.stove_serial_no, 
                    'to', NEW.stove_serial_no,
                    'timestamp', NOW()
                )
            );
            change_details := array_append(change_details, 'Stove serial number updated');
        END IF;
        
        IF OLD.partner_name IS DISTINCT FROM NEW.partner_name THEN
            field_changes := field_changes || jsonb_build_object(
                'partner_name', jsonb_build_object(
                    'from', OLD.partner_name, 
                    'to', NEW.partner_name,
                    'timestamp', NOW()
                )
            );
            change_details := array_append(change_details, 'Partner name updated');
        END IF;
        
        IF OLD.landmark IS DISTINCT FROM NEW.landmark THEN
            field_changes := field_changes || jsonb_build_object(
                'landmark', jsonb_build_object(
                    'from', OLD.landmark, 
                    'to', NEW.landmark,
                    'timestamp', NOW()
                )
            );
            change_details := array_append(change_details, 'Landmark updated');
        END IF;
        
        IF OLD.agent_id IS DISTINCT FROM NEW.agent_id THEN
            field_changes := field_changes || jsonb_build_object(
                'agent_id', jsonb_build_object(
                    'from', OLD.agent_id, 
                    'to', NEW.agent_id,
                    'timestamp', NOW()
                )
            );
            change_details := array_append(change_details, 'Agent assignment changed');
            
            -- For agent assignment, create a separate "assigned" action
            IF OLD.agent_id IS NULL AND NEW.agent_id IS NOT NULL THEN
                action_type := 'assigned';
                action_description := format('Sale assigned to agent for %s', 
                    COALESCE(NEW.end_user_name, 'Unknown Customer'));
            ELSIF OLD.agent_id IS NOT NULL AND NEW.agent_id IS NULL THEN
                action_type := 'unassigned';
                action_description := format('Sale unassigned from agent for %s', 
                    COALESCE(NEW.end_user_name, 'Unknown Customer'));
            ELSE
                action_type := 'reassigned';
                action_description := format('Sale reassigned to different agent for %s', 
                    COALESCE(NEW.end_user_name, 'Unknown Customer'));
            END IF;
        END IF;
        
        -- Handle status-specific actions
        IF OLD.status IS DISTINCT FROM NEW.status THEN
            IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
                action_type := 'completed';
                action_description := format('Sale completed for %s (Amount: GHS %s)', 
                    COALESCE(NEW.end_user_name, 'Unknown Customer'),
                    COALESCE(NEW.amount::text, '0'));
            ELSIF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
                action_type := 'cancelled';
                action_description := format('Sale cancelled for %s', 
                    COALESCE(NEW.end_user_name, 'Unknown Customer'));
            ELSIF action_type = 'updated' THEN
                -- Keep as updated if no specific status action
                NULL;
            END IF;
        END IF;
        
        -- Build comprehensive description if still just "updated"
        IF action_type = 'updated' THEN
            IF array_length(change_details, 1) > 0 THEN
                action_description := format('Sale updated for %s: %s', 
                    COALESCE(NEW.end_user_name, 'Unknown Customer'),
                    array_to_string(change_details, ', '));
            ELSE
                action_description := format('Sale record updated for %s (minor changes)', 
                    COALESCE(NEW.end_user_name, 'Unknown Customer'));
            END IF;
        END IF;
        
        -- Add metadata about the update
        field_changes := field_changes || jsonb_build_object(
            'update_metadata', jsonb_build_object(
                'total_fields_changed', array_length(change_details, 1),
                'user_context', user_context,
                'previous_updated_at', OLD.updated_at
            )
        );
        
    ELSIF TG_OP = 'DELETE' THEN
        action_type := 'deleted';
        action_description := format('Sale record deleted for %s (Serial: %s)', 
            COALESCE(OLD.end_user_name, 'Unknown Customer'),
            COALESCE(OLD.stove_serial_no, 'N/A'));
        
        -- Store deleted record data
        field_changes := jsonb_build_object(
            'deleted_record', jsonb_build_object(
                'id', OLD.id,
                'transaction_id', OLD.transaction_id,
                'end_user_name', OLD.end_user_name,
                'contact_person', OLD.contact_person,
                'amount', OLD.amount,
                'status', OLD.status,
                'stove_serial_no', OLD.stove_serial_no,
                'partner_name', OLD.partner_name,
                'deleted_at', NOW()
            )
        );
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
        COALESCE(NEW.id, OLD.id),
        action_type,
        action_description,
        field_changes,
        auth.uid(),
        NOW()
    );
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
DROP TRIGGER IF EXISTS sales_history_trigger ON sales;
CREATE TRIGGER sales_history_trigger
    AFTER INSERT OR UPDATE OR DELETE ON sales
    FOR EACH ROW
    EXECUTE FUNCTION create_sales_history();

-- Function to manually add custom history entries
CREATE OR REPLACE FUNCTION add_custom_sales_history(
    p_sale_id UUID,
    p_action_type VARCHAR(50),
    p_action_description TEXT,
    p_field_changes JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
DECLARE
    history_id UUID;
BEGIN
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
        p_field_changes,
        auth.uid(),
        NOW()
    ) RETURNING id INTO history_id;
    
    RETURN history_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

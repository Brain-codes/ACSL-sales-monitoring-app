-- Migration to Add Auto-Status Calculation to Sales Table
-- Run this script in your Supabase SQL Editor

-- Step 1: Ensure status column has proper default and constraints
ALTER TABLE public.sales 
ALTER COLUMN status SET NOT NULL,
ALTER COLUMN status SET DEFAULT 'incomplete';

-- Step 2: Update existing sales records to have calculated status
UPDATE public.sales 
SET status = CASE 
  -- Check for completed status
  WHEN (
    transaction_id IS NOT NULL AND trim(transaction_id) != '' AND
    stove_serial_no IS NOT NULL AND trim(stove_serial_no) != '' AND
    sales_date IS NOT NULL AND
    contact_person IS NOT NULL AND trim(contact_person) != '' AND
    contact_phone IS NOT NULL AND trim(contact_phone) != '' AND
    end_user_name IS NOT NULL AND trim(end_user_name) != '' AND
    phone IS NOT NULL AND trim(phone) != '' AND
    partner_name IS NOT NULL AND trim(partner_name) != '' AND
    amount IS NOT NULL AND amount > 0 AND
    signature IS NOT NULL AND trim(signature) != '' AND
    stove_image_id IS NOT NULL AND
    agreement_image_id IS NOT NULL
  ) THEN 'completed'
  
  -- Check for pending status
  WHEN (
    transaction_id IS NOT NULL AND trim(transaction_id) != '' AND
    stove_serial_no IS NOT NULL AND trim(stove_serial_no) != '' AND
    sales_date IS NOT NULL AND
    contact_person IS NOT NULL AND trim(contact_person) != '' AND
    contact_phone IS NOT NULL AND trim(contact_phone) != '' AND
    end_user_name IS NOT NULL AND trim(end_user_name) != '' AND
    phone IS NOT NULL AND trim(phone) != '' AND
    partner_name IS NOT NULL AND trim(partner_name) != '' AND
    amount IS NOT NULL AND amount > 0 AND
    (signature IS NOT NULL AND trim(signature) != '' OR 
     stove_image_id IS NOT NULL OR 
     agreement_image_id IS NOT NULL)
  ) THEN 'pending'
  
  -- Default to incomplete
  ELSE 'incomplete'
END
WHERE status IS NULL OR status = '';

-- Step 3: Create the status calculation function
CREATE OR REPLACE FUNCTION calculate_sale_status()
RETURNS TRIGGER AS $$
BEGIN
  -- Define variables for status calculation
  DECLARE
    required_fields_complete BOOLEAN;
    has_signature BOOLEAN;
    has_stove_image BOOLEAN;
    has_agreement_image BOOLEAN;
    calculated_status TEXT;
  BEGIN
    -- Check if all required fields are present and not empty
    required_fields_complete := (
      NEW.transaction_id IS NOT NULL AND trim(NEW.transaction_id) != '' AND
      NEW.stove_serial_no IS NOT NULL AND trim(NEW.stove_serial_no) != '' AND
      NEW.sales_date IS NOT NULL AND
      NEW.contact_person IS NOT NULL AND trim(NEW.contact_person) != '' AND
      NEW.contact_phone IS NOT NULL AND trim(NEW.contact_phone) != '' AND
      NEW.end_user_name IS NOT NULL AND trim(NEW.end_user_name) != '' AND
      NEW.phone IS NOT NULL AND trim(NEW.phone) != '' AND
      NEW.partner_name IS NOT NULL AND trim(NEW.partner_name) != '' AND
      NEW.amount IS NOT NULL AND NEW.amount > 0
    );
    
    -- Check for signature
    has_signature := (NEW.signature IS NOT NULL AND trim(NEW.signature) != '');
    
    -- Check for images
    has_stove_image := (NEW.stove_image_id IS NOT NULL);
    has_agreement_image := (NEW.agreement_image_id IS NOT NULL);
    
    -- Calculate status based on completeness (don't override 'assigned' status)
    IF NEW.status != 'assigned' THEN
      IF required_fields_complete AND has_signature AND has_stove_image AND has_agreement_image THEN
        calculated_status := 'completed';
      ELSIF required_fields_complete AND (has_signature OR has_stove_image OR has_agreement_image) THEN
        calculated_status := 'pending';
      ELSE
        calculated_status := 'incomplete';
      END IF;
      
      -- Set the calculated status
      NEW.status := calculated_status;
    END IF;
    
    RETURN NEW;
  END;
END;
$$ LANGUAGE plpgsql;

-- Step 4: Create triggers for automatic status calculation
-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS sales_status_calculation_insert ON public.sales;
DROP TRIGGER IF EXISTS sales_status_calculation_update ON public.sales;

-- Create trigger for INSERT operations
CREATE TRIGGER sales_status_calculation_insert
  BEFORE INSERT ON public.sales
  FOR EACH ROW
  EXECUTE FUNCTION calculate_sale_status();

-- Create trigger for UPDATE operations  
CREATE TRIGGER sales_status_calculation_update
  BEFORE UPDATE ON public.sales
  FOR EACH ROW
  EXECUTE FUNCTION calculate_sale_status();

-- Step 5: Create index on status column for better query performance
CREATE INDEX IF NOT EXISTS idx_sales_status ON public.sales(status);
CREATE INDEX IF NOT EXISTS idx_sales_organization_status ON public.sales(organization_id, status);

-- Verification: Check status distribution
SELECT status, COUNT(*) as count 
FROM public.sales 
GROUP BY status 
ORDER BY count DESC;

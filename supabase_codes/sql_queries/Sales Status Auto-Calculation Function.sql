-- Function to automatically calculate and update sale status
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
    
    -- Calculate status based on completeness
    IF required_fields_complete AND has_signature AND has_stove_image AND has_agreement_image THEN
      calculated_status := 'completed';
    ELSIF required_fields_complete AND (has_signature OR has_stove_image OR has_agreement_image) THEN
      calculated_status := 'pending';
    ELSE
      calculated_status := 'incomplete';
    END IF;
    
    -- Set the calculated status
    NEW.status := calculated_status;
    
    RETURN NEW;
  END;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for INSERT operations
DROP TRIGGER IF EXISTS sales_status_calculation_insert ON public.sales;
CREATE TRIGGER sales_status_calculation_insert
  BEFORE INSERT ON public.sales
  FOR EACH ROW
  EXECUTE FUNCTION calculate_sale_status();

-- Create trigger for UPDATE operations
DROP TRIGGER IF EXISTS sales_status_calculation_update ON public.sales;
CREATE TRIGGER sales_status_calculation_update
  BEFORE UPDATE ON public.sales
  FOR EACH ROW
  EXECUTE FUNCTION calculate_sale_status();

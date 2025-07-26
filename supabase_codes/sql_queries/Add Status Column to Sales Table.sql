-- Add status column to sales table with proper constraints
-- This will track the completion status of each sale

-- 1. Add status column with enum constraint
ALTER TABLE public.sales 
ADD COLUMN status TEXT DEFAULT 'incomplete' 
CHECK (status IN ('incomplete', 'completed', 'pending', 'assigned'));

-- 2. Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_sales_status ON public.sales(status);

-- 3. Create a function to automatically determine status based on data completeness
CREATE OR REPLACE FUNCTION public.calculate_sale_status(sale_record public.sales)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  -- Check if all required fields are filled
  IF sale_record.transaction_id IS NOT NULL 
     AND sale_record.stove_serial_no IS NOT NULL 
     AND sale_record.end_user_name IS NOT NULL 
     AND sale_record.phone IS NOT NULL 
     AND sale_record.amount IS NOT NULL 
     AND sale_record.address_id IS NOT NULL 
     AND sale_record.stove_image_id IS NOT NULL 
     AND sale_record.agreement_image_id IS NOT NULL 
     AND sale_record.signature IS NOT NULL THEN
    RETURN 'completed';
  ELSE
    RETURN 'incomplete';
  END IF;
END;
$$;

-- 4. Create trigger to auto-update status when sales record changes
CREATE OR REPLACE FUNCTION public.update_sale_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Automatically calculate and update status
  NEW.status = public.calculate_sale_status(NEW);
  RETURN NEW;
END;
$$;

-- 5. Create the trigger
DROP TRIGGER IF EXISTS trigger_update_sale_status ON public.sales;
CREATE TRIGGER trigger_update_sale_status
  BEFORE INSERT OR UPDATE ON public.sales
  FOR EACH ROW
  EXECUTE FUNCTION public.update_sale_status();

-- 6. Update existing records to have proper status
UPDATE public.sales 
SET status = public.calculate_sale_status(sales.*);

-- 7. Add comment for documentation
COMMENT ON COLUMN public.sales.status IS 'Auto-calculated status: incomplete, completed, pending, assigned';

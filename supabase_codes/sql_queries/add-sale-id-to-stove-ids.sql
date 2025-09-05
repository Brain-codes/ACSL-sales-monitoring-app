-- Add sale_id column to stove_ids table and set up foreign key
ALTER TABLE stove_ids
ADD COLUMN sale_id UUID REFERENCES sales(id);

-- (Optional) Enforce that only 'sold' stoves have a sale_id
ALTER TABLE stove_ids
ADD CONSTRAINT stove_ids_sale_id_check
CHECK ((status = 'sold' AND sale_id IS NOT NULL) OR (status != 'sold' AND sale_id IS NULL));

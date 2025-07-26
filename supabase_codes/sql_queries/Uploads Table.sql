CREATE POLICY "Allow select on addresses if linked to sales"
ON public.addresses
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM sales
    WHERE sales.address_id = addresses.id
    AND sales.organization_id IN (
      SELECT organization_id FROM profiles WHERE id = auth.uid()
    )
  )
);


CREATE POLICY "Allow insert of addresses for user's org"
ON public.addresses
FOR INSERT
TO authenticated
WITH CHECK (
  TRUE  -- Allow inserting address data; ensure link in sales separately
);


CREATE POLICY "Allow update of addresses linked to user's sales"
ON public.addresses
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM sales
    WHERE sales.address_id = addresses.id
    AND sales.organization_id IN (
      SELECT organization_id FROM profiles WHERE id = auth.uid()
    )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM sales
    WHERE sales.address_id = addresses.id
    AND sales.organization_id IN (
      SELECT organization_id FROM profiles WHERE id = auth.uid()
    )
  )
);


CREATE POLICY "Allow user to select own uploads"
ON public.uploads
FOR SELECT
TO authenticated
USING (
  created_by = auth.uid()
);



CREATE POLICY "Allow user to insert uploads"
ON public.uploads
FOR INSERT
TO authenticated
WITH CHECK (
  created_by = auth.uid()
);


CREATE POLICY "Allow user to insert uploads"
ON public.uploads
FOR INSERT
TO authenticated
WITH CHECK (
  created_by = auth.uid()
);


ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.uploads ENABLE ROW LEVEL SECURITY;

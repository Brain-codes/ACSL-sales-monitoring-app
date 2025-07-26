-- 1. Address Table
CREATE TABLE addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_address TEXT,
  street TEXT,
  city TEXT,
  state TEXT,
  country TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_at TIMESTAMP DEFAULT now()
);

-- 2. Images Table
CREATE TABLE sales_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT CHECK (type IN ('stove', 'agreement')),
  public_id TEXT,
  url TEXT,
  created_at TIMESTAMP DEFAULT now()
);

-- 3. Sales Table
CREATE TABLE sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id TEXT,
  stove_serial_no TEXT,
  sales_date DATE,
  contact_person TEXT,
  contact_phone TEXT,
  end_user_name TEXT,
  aka TEXT,
  state_backup TEXT,
  lga_backup TEXT,
  phone TEXT,
  other_phone TEXT,
  partner_name TEXT,
  amount NUMERIC,
  signature TEXT,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  address_id UUID REFERENCES addresses(id),
  stove_image_id UUID REFERENCES sales_images(id),
  agreement_image_id UUID REFERENCES sales_images(id),
  created_at TIMESTAMP DEFAULT now()
);

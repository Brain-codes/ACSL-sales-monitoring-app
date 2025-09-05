-- Sample data for organizations table
-- Run this AFTER running the update_organizations_table.sql

-- Insert sample organizations (only required fields: name and partner_email)
INSERT INTO public.organizations (name, partner_email) VALUES
('Stove Solutions Nigeria', 'contact@stovesolutions.ng'),
('Clean Energy Partners', 'info@cleanenergypartners.com'),
('Green Tech Distributors', 'sales@greentechdist.ng'),
('Eco Stove Company', 'admin@ecostove.com.ng'),
('Sustainable Cooking Solutions', 'hello@sustainablecooking.ng'),
('African Clean Energy', 'contact@africancleanenergy.org'),
('Rural Energy Access', 'info@ruralenergy.ng'),
('Smart Stove Technologies', 'support@smartstove.tech'),
('Community Energy Solutions', 'team@communityenergy.ng'),
('Modern Cooking Systems', 'sales@moderncooking.com');

-- Insert organizations with optional fields filled
INSERT INTO public.organizations (
    name, 
    partner_email, 
    contact_phone, 
    city, 
    state, 
    country, 
    description, 
    status
) VALUES
('Lagos Energy Hub', 'operations@lagosenerghub.ng', '+234123456789', 'Lagos', 'Lagos', 'Nigeria', 'Leading energy solutions provider in Lagos State', 'active'),
('Abuja Clean Tech', 'info@abujacleantech.ng', '+234987654321', 'Abuja', 'FCT', 'Nigeria', 'Clean technology distributor for the capital region', 'active'),
('Kano Stove Network', 'contact@kanostove.ng', '+234555666777', 'Kano', 'Kano', 'Nigeria', 'Northern Nigeria stove distribution network', 'active'),
('Port Harcourt Energy', 'sales@phenergy.ng', '+234444555666', 'Port Harcourt', 'Rivers', 'Nigeria', 'Energy solutions for the South-South region', 'active'),
('Ibadan Green Solutions', 'hello@ibadangreen.ng', '+234333444555', 'Ibadan', 'Oyo', 'Nigeria', 'Sustainable energy solutions for Oyo State', 'active');

-- Insert some inactive/test organizations
INSERT INTO public.organizations (name, partner_email, status, description) VALUES
('Test Organization Alpha', 'test1@example.com', 'inactive', 'Test organization for development purposes'),
('Beta Testing Company', 'test2@example.com', 'suspended', 'Another test organization'),
('Demo Stove Partners', 'demo@example.com', 'active', 'Demo organization for presentations');

-- Verify the data was inserted
-- SELECT COUNT(*) as total_organizations FROM public.organizations;
-- SELECT status, COUNT(*) as count FROM public.organizations GROUP BY status;

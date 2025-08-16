-- Create test user for integration tests
-- This migration creates a test user that can be used for running integration tests

-- First, we need to create a function that can create users (this requires service role)
CREATE OR REPLACE FUNCTION create_test_user(
  user_email TEXT,
  user_password TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_id UUID;
BEGIN
  -- Check if user already exists
  SELECT id INTO user_id
  FROM auth.users
  WHERE email = user_email;
  
  IF user_id IS NOT NULL THEN
    RETURN 'User already exists: ' || user_id::TEXT;
  END IF;
  
  -- Create the user in auth.users
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    user_email,
    crypt(user_password, gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    '',
    '',
    '',
    ''
  )
  RETURNING id INTO user_id;
  
  -- Create identity record
  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    user_id,
    format('{"sub":"%s","email":"%s"}', user_id::text, user_email)::jsonb,
    'email',
    user_id::text,
    NOW(),
    NOW(),
    NOW()
  );
  
  RETURN 'User created successfully: ' || user_id::TEXT;
END;
$$;

-- Grant execute permission to service role
GRANT EXECUTE ON FUNCTION create_test_user(TEXT, TEXT) TO service_role;

-- Create the test user
SELECT create_test_user('test@example.com', 'testpassword123');

-- Clean up the function (optional, but good practice)
DROP FUNCTION IF EXISTS create_test_user(TEXT, TEXT);
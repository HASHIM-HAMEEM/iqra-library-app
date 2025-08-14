-- SQL Script to Add New Admin User to Supabase
-- Run this in the Supabase SQL Editor

-- This script creates a new admin user in the Supabase auth system
-- The user will have full access to all tables through existing RLS policies

-- Replace these values with your desired admin credentials:
-- EMAIL: Change 'new-admin@iqralibrary.com' to your desired admin email
-- PASSWORD: Change 'SecureAdminPassword123!' to your desired password
-- USER_ID: You can generate a new UUID or use the one provided

DO $$
DECLARE
    new_user_id UUID := gen_random_uuid(); -- Generate a random UUID for the new user
    admin_email TEXT := 'mohsinfarooqi9906@gmail.com'; -- Admin email
    admin_password TEXT := 'Mohsin@iqra#313'; -- Admin password
    encrypted_password TEXT;
BEGIN
    -- Check if user already exists
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = admin_email) THEN
        RAISE NOTICE 'User with email % already exists', admin_email;
        RETURN;
    END IF;

    -- Create encrypted password (Supabase uses bcrypt)
    -- Note: This is a simplified approach. In production, you should use proper password hashing
    encrypted_password := crypt(admin_password, gen_salt('bf'));

    -- Insert new user into auth.users table
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
        '00000000-0000-0000-0000-000000000000', -- Default instance_id
        new_user_id,
        'authenticated',
        'authenticated',
        admin_email,
        encrypted_password,
        NOW(), -- Email confirmed immediately
        NOW(),
        NOW(),
        '', -- Empty confirmation token since email is pre-confirmed
        '',
        '',
        ''
    );

    -- Insert corresponding identity record
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
        new_user_id,
        jsonb_build_object(
            'sub', new_user_id::text,
            'email', admin_email,
            'email_verified', true
        ),
        'email',
        new_user_id::text,
        NOW(),
        NOW(),
        NOW()
    );

    -- Create initial app settings for the new admin user
    INSERT INTO public.app_settings (user_id, key, value, description) VALUES
        (new_user_id, 'session_timeout_minutes', '30', 'Session timeout in minutes'),
        (new_user_id, 'theme_mode', 'system', 'Application theme mode'),
        (new_user_id, 'enable_biometric_auth', 'true', 'Enable biometric authentication'),
        (new_user_id, 'enable_auto_backup', 'true', 'Enable automatic backups'),
        (new_user_id, 'max_failed_attempts', '5', 'Maximum failed authentication attempts');

    -- Create initial sync metadata for the new admin user
    INSERT INTO public.sync_metadata (user_id, last_sync) VALUES
        (new_user_id::text, NOW());

    RAISE NOTICE 'Successfully created admin user:';
    RAISE NOTICE 'Email: %', admin_email;
    RAISE NOTICE 'User ID: %', new_user_id;
    RAISE NOTICE 'Password: %', admin_password;
    RAISE NOTICE '';
    RAISE NOTICE 'IMPORTANT: Please change the password after first login!';
    RAISE NOTICE 'The user has full access to all application features through existing RLS policies.';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to create admin user: %', SQLERRM;
END $$;

-- Verify the user was created successfully
SELECT 
    id,
    email,
    email_confirmed_at,
    created_at,
    role
FROM auth.users 
WHERE email = 'mohsinfarooqi9906@gmail.com'; -- Admin email

-- Optional: Check app settings for the new user
SELECT 
    user_id,
    key,
    value,
    description
FROM public.app_settings 
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'mohsinfarooqi9906@gmail.com'); -- Admin email

/*
INSTRUCTIONS:
1. Email: mohsinfarooqi9906@gmail.com
2. Password: Mohsin@iqra#313
3. Run this script in the Supabase SQL Editor
4. The new admin user will have full access to all application features
5. The user can log in using the email and password you specified
6. After first login, consider changing the password through the application

NOTE: This application uses Supabase authentication combined with local device security.
All authenticated users have admin privileges through the existing RLS policies.
The application's security model relies on:
- Supabase authentication for user verification
- Local device passcode/biometric authentication for additional security
- Row Level Security (RLS) policies that grant full access to authenticated users
*/
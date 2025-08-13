# Admin User Setup and Permissions

## Overview
This document outlines the admin user configuration for the Iqra Library App with Supabase backend integration.

## Admin User Details
- **Email**: `scnz141@gmail.com`
- **Password**: `Wehere@25`
- **User ID**: `3c010325-fc1a-4cf5-8e52-100bee5524b2`
- **Status**: ✅ Active and verified

## Permissions Summary
The admin user has **full permissions** across all application features:

### ✅ Student Management
- **Create** new students
- **Read** all student records
- **Update** existing student information
- **Delete** student records (soft delete)
- **Search** and filter students
- **Export** student data

### ✅ Subscription Management
- **Create** new subscriptions
- **Read** all subscription records
- **Update** subscription details
- **Delete** subscriptions
- **Track** subscription status and revenue

### ✅ Activity Logs
- **View** all system activity logs
- **Create** audit trail entries
- **Track** user actions and system events

### ✅ System Administration
- **Access** all application features
- **Manage** app settings and configuration
- **Perform** data synchronization
- **Monitor** system health

## Database Security (RLS Policies)
The application uses Row Level Security (RLS) policies in Supabase:

### Authenticated Users
- **Full CRUD access** to all tables when authenticated
- **Session-based** permission validation
- **Automatic logout** on session expiry

### Anonymous Users
- **Read-only access** to public data
- **No write permissions** (create, update, delete blocked)
- **Authentication required** for any modifications

## Technical Implementation

### Authentication Flow
1. User enters credentials in the app
2. Supabase validates email/password
3. JWT session token generated
4. App stores session securely
5. All API calls include authentication headers
6. RLS policies enforce permissions at database level

### Security Features
- **JWT-based authentication** with automatic refresh
- **Row Level Security** enforced at database level
- **Session timeout** with configurable duration
- **Secure credential storage** using platform keychain
- **Biometric authentication** support (optional)

## Verification Tests

### ✅ Admin User Creation
```bash
node scripts/create_admin_user.js
```
- Creates admin user if not exists
- Verifies email/password combination
- Returns user ID and creation timestamp

### ✅ Login Verification
```bash
node scripts/verify_admin_login.js
```
- Tests authentication flow
- Validates session creation
- Confirms database access

### ✅ Permissions Testing
```bash
node scripts/test_admin_permissions.js
```
- Tests CRUD operations on students table
- Verifies RLS policies work correctly
- Confirms full admin access

## Running the Application

### With Environment Variables
```bash
# Make script executable
chmod +x run_app.sh

# Run with Supabase configuration
./run_app.sh
```

### Manual Flutter Run
```bash
flutter run --dart-define-from-file=.env
```

### Environment Configuration
The `.env` file contains:
```env
SUPABASE_URL=https://rqghiwjhizmlvdagicnw.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
TEST_EMAIL=scnz141@gmail.com
TEST_PASSWORD=Wehere@25
```

## Admin User Responsibilities

As an admin user, you have access to:

1. **Student Database Management**
   - Add new library members
   - Update member information
   - Manage subscription status
   - Track payment history

2. **System Monitoring**
   - View activity logs
   - Monitor system performance
   - Track user engagement
   - Generate reports

3. **Data Security**
   - Ensure data privacy compliance
   - Manage user access
   - Backup and restore data
   - Monitor security events

## Support and Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify email/password combination
   - Check internet connectivity
   - Ensure Supabase service is running

2. **Permission Denied Errors**
   - Confirm user is properly authenticated
   - Check session hasn't expired
   - Verify RLS policies are correctly applied

3. **Database Connection Issues**
   - Validate Supabase URL and API key
   - Check network connectivity
   - Verify environment variables are loaded

### Getting Help
- Check application logs for detailed error messages
- Run verification scripts to diagnose issues
- Review Supabase dashboard for service status
- Contact technical support if issues persist

## Security Best Practices

1. **Password Security**
   - Use strong, unique passwords
   - Enable two-factor authentication when available
   - Regularly update credentials

2. **Session Management**
   - Log out when finished
   - Don't share login credentials
   - Monitor for suspicious activity

3. **Data Protection**
   - Follow data privacy regulations
   - Limit access to necessary personnel
   - Regular security audits

---

**Last Updated**: August 12, 2025  
**Status**: ✅ Admin user active and fully functional  
**Next Review**: Monthly security audit recommended
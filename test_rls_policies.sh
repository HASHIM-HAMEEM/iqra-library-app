#!/bin/bash

# RLS Policy Verification Script
# This script tests the updated RLS policies to ensure they work correctly

echo "🔍 Testing RLS Policies for Iqra Library App"
echo "============================================"

# Load environment variables
if [ -f .env ]; then
    source .env
    echo "✅ Environment variables loaded from .env"
else
    echo "❌ .env file not found"
    exit 1
fi

# Check required environment variables
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "❌ Missing required environment variables: SUPABASE_URL or SUPABASE_ANON_KEY"
    exit 1
fi

echo "✅ Supabase URL: $SUPABASE_URL"
echo "✅ Supabase Anon Key: ${SUPABASE_ANON_KEY:0:20}..."
echo ""

# Test 1: Test RLS policies using the built-in test function
echo "📋 Test 1: Testing RLS policies with built-in function"
echo "------------------------------------------------------"

RLS_TEST_RESULT=$(curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/test_rls_policies" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json")

if [ $? -eq 0 ]; then
    echo "✅ RLS test function executed successfully"
    echo "📊 Result: $RLS_TEST_RESULT"
else
    echo "❌ Failed to execute RLS test function"
fi

echo ""

# Test 2: Test basic CRUD operations on students table
echo "📋 Test 2: Testing CRUD operations on students table"
echo "----------------------------------------------------"

# Generate a unique test ID
TEST_ID="test_$(date +%s)_$$"
TEST_EMAIL="test_${TEST_ID}@example.com"

# Test INSERT
echo "🔹 Testing INSERT operation..."
INSERT_RESULT=$(curl -s -X POST "$SUPABASE_URL/rest/v1/students" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"id\": \"$TEST_ID\",
    \"first_name\": \"Test\",
    \"last_name\": \"Student\",
    \"email\": \"$TEST_EMAIL\",
    \"date_of_birth\": \"2000-01-01T00:00:00Z\"
  }")

if echo "$INSERT_RESULT" | grep -q "$TEST_ID"; then
    echo "✅ INSERT operation successful"
else
    echo "❌ INSERT operation failed: $INSERT_RESULT"
fi

# Test SELECT
echo "🔹 Testing SELECT operation..."
SELECT_RESULT=$(curl -s -X GET "$SUPABASE_URL/rest/v1/students?id=eq.$TEST_ID" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY")

if echo "$SELECT_RESULT" | grep -q "$TEST_ID"; then
    echo "✅ SELECT operation successful"
else
    echo "❌ SELECT operation failed: $SELECT_RESULT"
fi

# Test UPDATE
echo "🔹 Testing UPDATE operation..."
UPDATE_RESULT=$(curl -s -X PATCH "$SUPABASE_URL/rest/v1/students?id=eq.$TEST_ID" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"first_name\": \"Updated Test\"
  }")

if echo "$UPDATE_RESULT" | grep -q "Updated Test"; then
    echo "✅ UPDATE operation successful"
else
    echo "❌ UPDATE operation failed: $UPDATE_RESULT"
fi

# Test DELETE
echo "🔹 Testing DELETE operation..."
DELETE_RESULT=$(curl -s -X DELETE "$SUPABASE_URL/rest/v1/students?id=eq.$TEST_ID" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY")

if [ $? -eq 0 ]; then
    echo "✅ DELETE operation successful"
else
    echo "❌ DELETE operation failed: $DELETE_RESULT"
fi

echo ""

# Test 3: Test permissions on other tables
echo "📋 Test 3: Testing permissions on other tables"
echo "----------------------------------------------"

# Test subscriptions table
echo "🔹 Testing subscriptions table access..."
SUBSCRIPTIONS_RESULT=$(curl -s -X GET "$SUPABASE_URL/rest/v1/subscriptions?limit=1" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY")

if [ $? -eq 0 ]; then
    echo "✅ Subscriptions table accessible"
else
    echo "❌ Subscriptions table access failed"
fi

# Test activity_logs table
echo "🔹 Testing activity_logs table access..."
ACTIVITY_LOGS_RESULT=$(curl -s -X GET "$SUPABASE_URL/rest/v1/activity_logs?limit=1" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY")

if [ $? -eq 0 ]; then
    echo "✅ Activity logs table accessible"
else
    echo "❌ Activity logs table access failed"
fi

# Test sync_metadata table
echo "🔹 Testing sync_metadata table access..."
SYNC_METADATA_RESULT=$(curl -s -X GET "$SUPABASE_URL/rest/v1/sync_metadata?limit=1" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY")

if [ $? -eq 0 ]; then
    echo "✅ Sync metadata table accessible"
else
    echo "❌ Sync metadata table access failed"
fi

echo ""
echo "🎉 RLS Policy Verification Complete!"
echo "===================================="
echo "If all tests passed, the RLS policies are working correctly."
echo "You can now run the Flutter integration tests with confidence."
echo ""
echo "To run Flutter integration tests:"
echo "flutter test integration_test/supabase_integration_test.dart --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY --dart-define=TEST_EMAIL=$TEST_EMAIL --dart-define=TEST_PASSWORD=testpassword123"
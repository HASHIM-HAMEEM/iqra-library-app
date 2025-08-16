#!/bin/bash

# Flutter Test Runner Script
# This script runs Flutter integration and unit tests with proper environment variables

set -e  # Exit on any error

echo "🧪 Starting Flutter Test Suite..."
echo "======================================"

# Supabase Configuration (must be provided via environment)
: "${SUPABASE_URL:?SUPABASE_URL is required}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required}"
: "${TEST_EMAIL:?TEST_EMAIL is required}"
: "${TEST_PASSWORD:?TEST_PASSWORD is required}"

echo "📋 Test Configuration:"
echo "  - Supabase URL: ${SUPABASE_URL:0:30}..."
echo "  - Test Email: ${TEST_EMAIL}"
echo ""
# Function to run tests with error handling
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo "🔍 Running $test_name..."
    echo "Command: $test_command"
    echo "----------------------------------------"
    
    if eval "$test_command"; then
        echo "✅ $test_name PASSED"
    else
        echo "❌ $test_name FAILED (Exit Code: $?)"
        echo "See output above for details"
    fi
    echo ""
}

# 1. Run Integration Tests
INTEGRATION_TEST_CMD="flutter test test/integration/supabase_integration_test.dart --dart-define=SUPABASE_URL=\"$SUPABASE_URL\" --dart-define=SUPABASE_ANON_KEY=\"$SUPABASE_ANON_KEY\" --dart-define=TEST_EMAIL=\"$TEST_EMAIL\" --dart-define=TEST_PASSWORD=\"$TEST_PASSWORD\""

run_test "Supabase Integration Tests" "$INTEGRATION_TEST_CMD"

# 2. Run Unit Tests
UNIT_TEST_CMD="flutter test test/widget_test.dart"
run_test "Widget Unit Tests" "$UNIT_TEST_CMD"

# 3. Run All Tests (if individual tests pass)
echo "🔄 Running All Tests..."
ALL_TESTS_CMD="flutter test --dart-define=SUPABASE_URL=\"$SUPABASE_URL\" --dart-define=SUPABASE_ANON_KEY=\"$SUPABASE_ANON_KEY\" --dart-define=TEST_EMAIL=\"$TEST_EMAIL\" --dart-define=TEST_PASSWORD=\"$TEST_PASSWORD\""
run_test "All Flutter Tests" "$ALL_TESTS_CMD"

echo "🏁 Test Suite Complete!"
echo "======================================"
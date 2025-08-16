#!/bin/bash

# Flutter App Runner Script
# This script ensures the app runs with proper environment configuration

echo "🚀 Starting Iqra Library App with Supabase configuration..."

# Optionally load .env for local development (not for production builds)
if [ -f ".env" ]; then
    echo "📋 Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs -0 2>/dev/null || true)
fi

# Check if flutter is available
if ! command -v flutter &> /dev/null; then
    echo "❌ Error: Flutter is not installed or not in PATH"
    exit 1
fi

# Validate required environment variables
: "${SUPABASE_URL:?SUPABASE_URL is required}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required}"

echo "✅ Supabase URL: ${SUPABASE_URL:0:30}..."
# Do not print keys in logs

# Check for device/emulator
echo "📱 Checking for available devices..."
flutter devices --machine > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ Error: No Flutter devices available"
    echo "Please start an emulator or connect a device"
    exit 1
fi

# Clean and get dependencies
echo "🧹 Cleaning and getting dependencies..."
flutter clean
flutter pub get

# Run the app with environment variables
echo "🚀 Running app with Supabase configuration..."
echo ""
echo "📱 The app will now start with:"
echo "   - Supabase database connection"
echo "   - Authentication enabled"
echo "   - Test admin user: admin@iqralibrary.com / admin123"
echo ""

flutter run \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
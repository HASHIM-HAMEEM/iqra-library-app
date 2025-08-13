#!/bin/bash

# Flutter App Runner Script
# This script ensures the app runs with proper environment configuration

echo "🚀 Starting Iqra Library App with Supabase configuration..."

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "❌ Error: .env file not found!"
    echo "Please copy .env.example to .env and configure your Supabase credentials:"
    echo "cp .env.example .env"
    exit 1
fi

# Check if flutter is available
if ! command -v flutter &> /dev/null; then
    echo "❌ Error: Flutter is not installed or not in PATH"
    exit 1
fi

# Extract environment variables from .env file
if [ -f ".env" ]; then
    echo "📋 Loading environment variables from .env file..."
    
    # Read SUPABASE_URL and SUPABASE_ANON_KEY from .env
    SUPABASE_URL=$(grep '^SUPABASE_URL=' .env | cut -d '=' -f2- | tr -d '"' | tr -d "'")
    SUPABASE_ANON_KEY=$(grep '^SUPABASE_ANON_KEY=' .env | cut -d '=' -f2- | tr -d '"' | tr -d "'")
    
    if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
        echo "❌ Error: SUPABASE_URL or SUPABASE_ANON_KEY not found in .env file"
        echo "Please ensure your .env file contains:"
        echo "SUPABASE_URL=your_supabase_url"
        echo "SUPABASE_ANON_KEY=your_supabase_anon_key"
        exit 1
    fi
    
    echo "✅ Supabase URL: ${SUPABASE_URL:0:30}..."
    echo "✅ Supabase Key: ${SUPABASE_ANON_KEY:0:30}..."
fi

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
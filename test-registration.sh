#!/bin/bash

# User Registration Test Script for Invoice Platform

echo "🧪 Testing User Registration API..."

# Test data
EMAIL="test@example.com"
PASSWORD="password123"
FIRST_NAME="John"
LAST_NAME="Doe"
COMPANY="Test Company Inc."
PHONE="+1234567890"

API_BASE_URL="http://localhost:3000"
AUTH_SERVICE_URL="http://localhost:3001"

echo "📝 Test user data:"
echo "  Email: $EMAIL"
echo "  Name: $FIRST_NAME $LAST_NAME"
echo "  Company: $COMPANY"
echo ""

# Test 1: Register new user
echo "🔧 Test 1: Register new user..."
registration_response=$(curl -s -X POST \
  "$AUTH_SERVICE_URL/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "'"$EMAIL"'",
    "password": "'"$PASSWORD"'",
    "firstName": "'"$FIRST_NAME"'",
    "lastName": "'"$LAST_NAME"'",
    "company": "'"$COMPANY"'",
    "phone": "'"$PHONE"'"
  }')

echo "Response: $registration_response"
echo ""

# Extract token from response
token=$(echo "$registration_response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -n "$token" ]; then
    echo "✅ Registration successful! Token received."
    echo "Token: ${token:0:50}..."
    
    # Test 2: Test login with the same credentials
    echo ""
    echo "🔧 Test 2: Login with registered user..."
    login_response=$(curl -s -X POST \
      "$AUTH_SERVICE_URL/login" \
      -H "Content-Type: application/json" \
      -d '{
        "email": "'"$EMAIL"'",
        "password": "'"$PASSWORD"'"
      }')
    
    echo "Login Response: $login_response"
    
    # Test 3: Access protected endpoint
    echo ""
    echo "🔧 Test 3: Access user profile..."
    profile_response=$(curl -s -X GET \
      "$AUTH_SERVICE_URL/me" \
      -H "Authorization: Bearer $token")
    
    echo "Profile Response: $profile_response"
    
else
    echo "❌ Registration failed!"
fi

echo ""
echo "🌐 Access Swagger UI at: $API_BASE_URL/api-docs"
echo "📖 API Documentation: $API_BASE_URL/api-docs"

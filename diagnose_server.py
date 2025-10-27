#!/usr/bin/env python3
"""
OrbX Server Diagnostics
Tests basic connectivity and identifies configuration issues
"""

import requests
import json
from urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

SERVER_IP = "172.191.139.108"
SERVER_PORT = 8443
JWT_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJ1c2VybmFtZSI6ImluZm9Ab3JidnBuLmNvbSIsImVtYWlsIjoiaW5mb0BvcmJ2cG4uY29tIiwic3Vic2NyaXB0aW9uX3RpZXIiOiIxIFllYXIiLCJ0eXBlIjoiYWNjZXNzIiwiaWF0IjoxNzYxNTg5ODA5LCJleHAiOjE3NjI0ODk4MDl9.9y0uNph5NaCRs2bOwA0skSzgwl3DpFod277tO-PfgGQ"

print("🔍 OrbX Server Diagnostics")
print("=" * 60)
print(f"Server: {SERVER_IP}:{SERVER_PORT}\n")

# Test 1: Basic HTTPS connectivity
print("Test 1: Basic HTTPS Connectivity")
print("-" * 60)
try:
    response = requests.get(
        f"https://{SERVER_IP}:{SERVER_PORT}",
        timeout=10,
        verify=False
    )
    print(f"✓ Server responds: HTTP {response.status_code}")
    print(f"  Headers: {dict(response.headers)}")
    if response.text:
        print(f"  Body: {response.text[:200]}")
except Exception as e:
    print(f"✗ Connection failed: {e}")

# Test 2: Health endpoint (if exists)
print("\n\nTest 2: Health Endpoint")
print("-" * 60)
try:
    response = requests.get(
        f"https://{SERVER_IP}:{SERVER_PORT}/health",
        timeout=10,
        verify=False
    )
    print(f"✓ Health endpoint: HTTP {response.status_code}")
    print(f"  Response: {response.text}")
except Exception as e:
    print(f"✗ Health check failed: {e}")

# Test 3: Teams endpoint without auth
print("\n\nTest 3: Teams Endpoint (No Auth)")
print("-" * 60)
try:
    response = requests.get(
        f"https://{SERVER_IP}:{SERVER_PORT}/teams/messages",
        timeout=10,
        verify=False
    )
    print(f"HTTP {response.status_code}")
    print(f"Headers: {dict(response.headers)}")
    if response.text:
        print(f"Body: {response.text[:500]}")
except Exception as e:
    print(f"✗ Failed: {e}")

# Test 4: Teams endpoint with JWT token
print("\n\nTest 4: Teams Endpoint (With JWT)")
print("-" * 60)
try:
    response = requests.get(
        f"https://{SERVER_IP}:{SERVER_PORT}/teams/messages",
        headers={
            "Authorization": f"Bearer {JWT_TOKEN}",
            "User-Agent": "Mozilla/5.0 Teams/1.5.00.32283",
            "Content-Type": "application/json"
        },
        timeout=10,
        verify=False
    )
    print(f"HTTP {response.status_code}")
    print(f"Response headers: {dict(response.headers)}")
    if response.text:
        print(f"Response body: {response.text[:500]}")
except Exception as e:
    print(f"✗ Failed: {e}")

# Test 5: POST request (mimicking actual VPN data)
print("\n\nTest 5: POST Request (With Data)")
print("-" * 60)
try:
    response = requests.post(
        f"https://{SERVER_IP}:{SERVER_PORT}/teams/messages",
        headers={
            "Authorization": f"Bearer {JWT_TOKEN}",
            "User-Agent": "Mozilla/5.0 Teams/1.5.00.32283",
            "Content-Type": "application/octet-stream"
        },
        data=b"TEST_DATA_PAYLOAD",
        timeout=10,
        verify=False
    )
    print(f"HTTP {response.status_code}")
    print(f"Response: {response.text[:500]}")
except Exception as e:
    print(f"✗ Failed: {e}")

# Test 6: Check what the server expects
print("\n\nTest 6: OPTIONS Request (Check CORS/Methods)")
print("-" * 60)
try:
    response = requests.options(
        f"https://{SERVER_IP}:{SERVER_PORT}/teams/messages",
        timeout=10,
        verify=False
    )
    print(f"HTTP {response.status_code}")
    print(f"Allowed methods: {response.headers.get('Allow', 'Not specified')}")
    print(f"Headers: {dict(response.headers)}")
except Exception as e:
    print(f"✗ Failed: {e}")

print("\n" + "=" * 60)
print("🎯 Diagnosis Complete")
print("\nCommon Issues:")
print("  - HTTP 400: Server rejects request format/headers")
print("  - HTTP 401: Authentication failed (JWT issue)")
print("  - HTTP 404: Endpoint doesn't exist")
print("  - HTTP 500: Server internal error")
print("\nNext steps:")
print("  1. Check server logs: ssh azureuser@172.191.139.108")
print("  2. Then run: docker logs orbx-server -f")
print("  3. Look for error messages about JWT validation")
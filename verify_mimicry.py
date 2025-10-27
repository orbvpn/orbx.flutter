#!/usr/bin/env python3
"""
OrbX Protocol Mimicry Test - Proper Format
Tests protocols with correct headers and payloads
"""

import requests
import json
import base64
import time
from urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

SERVER_IP = "172.191.139.108"
SERVER_PORT = 8443
JWT_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJ1c2VybmFtZSI6ImluZm9Ab3JidnBuLmNvbSIsImVtYWlsIjoiaW5mb0BvcmJ2cG4uY29tIiwic3Vic2NyaXB0aW9uX3RpZXIiOiIxIFllYXIiLCJ0eXBlIjoiYWNjZXNzIiwiaWF0IjoxNzYxNTg5ODA5LCJleHAiOjE3NjI0ODk4MDl9.9y0uNph5NaCRs2bOwA0skSzgwl3DpFod277tO-PfgGQ"

print("🔬 OrbX Protocol Mimicry Test - Proper Format")
print("=" * 60)
print(f"Server: {SERVER_IP}:{SERVER_PORT}\n")

def test_teams_protocol():
    """Test Microsoft Teams protocol with proper headers and payload"""
    print("\n━━━ Testing Microsoft Teams Protocol ━━━")
    
    # Teams-like payload
    payload = {
        "type": "message",
        "content": base64.b64encode(b"TEST_VPN_DATA").decode(),
        "timestamp": int(time.time()),
        "clientId": "teams-client-12345"
    }
    
    # Teams-specific headers
    headers = {
        "Authorization": f"Bearer {JWT_TOKEN}",
        "User-Agent": "Mozilla/5.0 Teams/1.5.00.32283",
        "Content-Type": "application/json",
        "X-Ms-Client-Version": "27/1.0.0.2024",  # ← CRITICAL!
        "X-Ms-Session-Id": f"session-{int(time.time())}"
    }
    
    try:
        response = requests.post(
            f"https://{SERVER_IP}:{SERVER_PORT}/teams/messages",
            headers=headers,
            json=payload,
            timeout=10,
            verify=False
        )
        
        print(f"Status: HTTP {response.status_code}")
        if response.status_code == 200:
            print("✅ PASS - Teams mimicry working!")
            print(f"Response: {response.text[:200]}")
        else:
            print(f"❌ FAIL - {response.text}")
            
        return response.status_code == 200
    except Exception as e:
        print(f"❌ ERROR: {e}")
        return False

def test_doh_protocol():
    """Test DNS over HTTPS protocol"""
    print("\n━━━ Testing DNS over HTTPS Protocol ━━━")
    
    # DoH query (base64url encoded)
    dns_query = base64.b64encode(b"TEST_DNS_QUERY").decode()
    
    headers = {
        "Authorization": f"Bearer {JWT_TOKEN}",
        "User-Agent": "Mozilla/5.0",
        "Accept": "application/dns-message"
    }
    
    try:
        # Test GET method
        response = requests.get(
            f"https://{SERVER_IP}:{SERVER_PORT}/dns-query",
            params={"dns": dns_query},
            headers=headers,
            timeout=10,
            verify=False
        )
        
        print(f"Status (GET): HTTP {response.status_code}")
        
        # Test POST method
        headers["Content-Type"] = "application/dns-message"
        response_post = requests.post(
            f"https://{SERVER_IP}:{SERVER_PORT}/dns-query",
            headers=headers,
            data=b"TEST_DNS_QUERY",
            timeout=10,
            verify=False
        )
        
        print(f"Status (POST): HTTP {response_post.status_code}")
        
        if response.status_code == 200 or response_post.status_code == 200:
            print("✅ PASS - DoH mimicry working!")
            return True
        else:
            print(f"❌ FAIL - GET: {response.text}, POST: {response_post.text}")
            return False
            
    except Exception as e:
        print(f"❌ ERROR: {e}")
        return False

def test_google_protocol():
    """Test Google Workspace protocol"""
    print("\n━━━ Testing Google Workspace Protocol ━━━")
    
    # Google-like payload
    payload = {
        "kind": "workspace#drive",
        "data": base64.b64encode(b"TEST_DRIVE_DATA").decode(),
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "requestId": f"req_{int(time.time())}"
    }
    
    headers = {
        "Authorization": f"Bearer {JWT_TOKEN}",
        "User-Agent": "Mozilla/5.0 Chrome/120.0.0.0",
        "Content-Type": "application/json",
        "X-Goog-Api-Client": "gl-go/1.20.0 gdcl/0.110.0",
        "X-Goog-Request-Id": f"req-{int(time.time())}"
    }
    
    try:
        response = requests.post(
            f"https://{SERVER_IP}:{SERVER_PORT}/google/drive/files",
            headers=headers,
            json=payload,
            timeout=10,
            verify=False
        )
        
        print(f"Status: HTTP {response.status_code}")
        if response.status_code == 200:
            print("✅ PASS - Google mimicry working!")
            print(f"Response: {response.text[:200]}")
        else:
            print(f"❌ FAIL - {response.text}")
            
        return response.status_code == 200
    except Exception as e:
        print(f"❌ ERROR: {e}")
        return False

def test_shaparak_protocol():
    """Test Shaparak Banking protocol (Iran)"""
    print("\n━━━ Testing Shaparak Banking Protocol ━━━")
    
    # Shaparak-like SOAP payload
    soap_payload = """<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Body>
        <ProcessTransaction>
            <Amount>50000</Amount>
            <MerchantID>123456</MerchantID>
            <Data>{}</Data>
        </ProcessTransaction>
    </soap:Body>
</soap:Envelope>""".format(base64.b64encode(b"TEST_TRANSACTION_DATA").decode())
    
    headers = {
        "Authorization": f"Bearer {JWT_TOKEN}",
        "User-Agent": "ShaparakClient/2.0",
        "Content-Type": "text/xml; charset=utf-8",
        "SOAPAction": "ProcessTransaction"
    }
    
    try:
        response = requests.post(
            f"https://{SERVER_IP}:{SERVER_PORT}/shaparak/transaction",
            headers=headers,
            data=soap_payload,
            timeout=10,
            verify=False
        )
        
        print(f"Status: HTTP {response.status_code}")
        if response.status_code == 200:
            print("✅ PASS - Shaparak mimicry working!")
            print(f"Response: {response.text[:200]}")
        else:
            print(f"❌ FAIL - {response.text}")
            
        return response.status_code == 200
    except Exception as e:
        print(f"❌ ERROR: {e}")
        return False

# Run all tests
results = {
    "Teams": test_teams_protocol(),
    "DoH": test_doh_protocol(),
    "Google": test_google_protocol(),
    "Shaparak": test_shaparak_protocol()
}

# Summary
print("\n" + "=" * 60)
print("📊 Test Summary")
print("=" * 60)

passed = sum(1 for v in results.values() if v)
total = len(results)

for protocol, passed_test in results.items():
    status = "✅ PASS" if passed_test else "❌ FAIL"
    print(f"  {protocol:15s} {status}")

print(f"\nSuccess Rate: {passed}/{total} ({passed/total*100:.1f}%)")

if passed == total:
    print("\n🎉 Perfect! All protocols working with proper mimicry!")
elif passed > 0:
    print("\n✓ Some protocols working. This is normal - test with your phone app!")
else:
    print("\n⚠️  No protocols passing. Check server logs.")

print("\n💡 Note: The test scripts are simplified.")
print("   Your Flutter app sends even better formatted requests!")
print("   Test with your actual phone for best results.")
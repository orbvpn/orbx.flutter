#!/usr/bin/env python3
"""
OrbX Protocol Mimicry Verification
Tests protocol handlers with proper TLS configuration
"""

import requests
import json
import base64
import urllib3
from typing import Dict, Tuple

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Server configuration
SERVER_IP = "172.191.139.108"
SERVER_PORT = "8443"
BASE_URL = f"https://{SERVER_IP}:{SERVER_PORT}"

# Your JWT token (get from login)
JWT_TOKEN = ""  # Replace with actual token


class ProtocolTester:
    def __init__(self, server_url: str, jwt_token: str):
        self.server_url = server_url
        self.jwt_token = jwt_token
        
        # Create session with proper TLS configuration
        self.session = requests.Session()
        self.session.verify = False
        
        # Configure retry strategy
        adapter = requests.adapters.HTTPAdapter(
            max_retries=0,  # No retries for testing
            pool_connections=10,
            pool_maxsize=10
        )
        self.session.mount('https://', adapter)
        self.session.mount('http://', adapter)

    def test_teams(self) -> Tuple[int, str]:
        """Test Microsoft Teams protocol"""
        print("━━━ Testing Microsoft Teams Protocol ━━━")
        
        url = f"{self.server_url}/teams/messages"
        
        # Create proper Teams-like payload
        payload = {
            "type": "message",
            "content": base64.b64encode(b"TEST_PACKET_DATA").decode(),
            "timestamp": 1730000000,
            "clientId": "orbx-test-client"
        }
        
        headers = {
            "Authorization": f"Bearer {self.jwt_token}",
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 Teams/1.5.00.32283",
            "X-Ms-Client-Version": "1.5.00.32283"
        }
        
        try:
            response = self.session.post(
                url,
                json=payload,
                headers=headers,
                timeout=10
            )
            
            print(f"Status: HTTP {response.status_code}")
            
            if response.status_code == 200:
                print("✅ PASS - Protocol working")
                return response.status_code, "Success"
            else:
                print(f"❌ FAIL - HTTP {response.status_code}")
                print(f"Response: {response.text[:200]}")
                return response.status_code, f"HTTP {response.status_code}"
                
        except requests.exceptions.SSLError as e:
            print(f"❌ FAIL - SSL Error: {str(e)[:100]}")
            return 0, "SSL Error"
        except requests.exceptions.ConnectionError as e:
            print(f"❌ FAIL - Connection Error: {str(e)[:100]}")
            return 0, "Connection Error"
        except Exception as e:
            print(f"❌ FAIL - {type(e).__name__}: {str(e)[:100]}")
            return 0, str(e)

    def test_google(self) -> Tuple[int, str]:
        """Test Google Workspace protocol"""
        print("━━━ Testing Google Workspace Protocol ━━━")
        
        url = f"{self.server_url}/google/drive/files"
        
        payload = {
            "kind": "drive#file",
            "data": base64.b64encode(b"TEST_PACKET_DATA").decode(),
            "timestamp": "2025-10-27T22:00:00Z",
            "requestId": "req_1730000000"
        }
        
        headers = {
            "Authorization": f"Bearer {self.jwt_token}",
            "Content-Type": "application/json",
            "User-Agent": "com.google.Drive/5.13.23",
            "X-Goog-Api-Client": "gl-dart/2.19"
        }
        
        try:
            response = self.session.post(
                url,
                json=payload,
                headers=headers,
                timeout=10
            )
            
            print(f"Status: HTTP {response.status_code}")
            
            if response.status_code == 200:
                print("✅ PASS - Protocol working")
                return response.status_code, "Success"
            else:
                print(f"❌ FAIL - HTTP {response.status_code}")
                return response.status_code, f"HTTP {response.status_code}"
                
        except Exception as e:
            print(f"❌ FAIL - {type(e).__name__}: {str(e)[:100]}")
            return 0, str(e)

    def test_shaparak(self) -> Tuple[int, str]:
        """Test Shaparak Banking protocol"""
        print("━━━ Testing Shaparak Banking Protocol ━━━")
        
        url = f"{self.server_url}/shaparak/transaction"
        
        payload = {
            "transactionType": "payment",
            "amount": "50000",
            "merchantId": "123456",
            "data": base64.b64encode(b"TEST_PACKET_DATA").decode(),
            "timestamp": 1730000000
        }
        
        headers = {
            "Authorization": f"Bearer {self.jwt_token}",
            "Content-Type": "application/json",
            "User-Agent": "Shaparak/Android/2.0"
        }
        
        try:
            response = self.session.post(
                url,
                json=payload,
                headers=headers,
                timeout=10
            )
            
            print(f"Status: HTTP {response.status_code}")
            
            if response.status_code == 200:
                print("✅ PASS - Protocol working")
                return response.status_code, "Success"
            else:
                print(f"❌ FAIL - HTTP {response.status_code}")
                return response.status_code, f"HTTP {response.status_code}"
                
        except Exception as e:
            print(f"❌ FAIL - {type(e).__name__}: {str(e)[:100]}")
            return 0, str(e)

    def test_doh(self) -> Tuple[int, str]:
        """Test DNS over HTTPS protocol"""
        print("━━━ Testing DNS over HTTPS Protocol ━━━")
        
        url = f"{self.server_url}/dns-query"
        
        # DoH expects raw DNS message in body
        test_dns_query = base64.b64encode(b"TEST_DNS_QUERY").decode()
        
        headers = {
            "Authorization": f"Bearer {self.jwt_token}",
            "Content-Type": "application/dns-message",
            "User-Agent": "Mozilla/5.0"
        }
        
        try:
            # Test POST
            response = self.session.post(
                url,
                data=base64.b64decode(test_dns_query),
                headers=headers,
                timeout=10
            )
            
            print(f"Status (POST): HTTP {response.status_code}")
            
            if response.status_code == 200:
                print("✅ PASS - Protocol working")
                return response.status_code, "Success"
            else:
                print(f"❌ FAIL - HTTP {response.status_code}")
                return response.status_code, f"HTTP {response.status_code}"
                
        except Exception as e:
            print(f"❌ FAIL - {type(e).__name__}: {str(e)[:100]}")
            return 0, str(e)


def main():
    print("🔬 OrbX Protocol Mimicry Test - Proper Format")
    print("=" * 60)
    print(f"Server: {SERVER_IP}:{SERVER_PORT}")
    print()
    
    if JWT_TOKEN == "YOUR_JWT_TOKEN_HERE":
        print("⚠️  ERROR: Please set your JWT token in the script!")
        print("   Get token from: Login to OrbX app → Copy from logs")
        return
    
    tester = ProtocolTester(BASE_URL, JWT_TOKEN)
    
    results = {}
    
    # Test each protocol
    results['Teams'] = tester.test_teams()
    print()
    
    results['Google'] = tester.test_google()
    print()
    
    results['Shaparak'] = tester.test_shaparak()
    print()
    
    results['DoH'] = tester.test_doh()
    print()
    
    # Summary
    print("=" * 60)
    print("📊 Test Summary")
    print("=" * 60)
    
    passed = 0
    total = len(results)
    
    for protocol, (status, msg) in results.items():
        if status == 200:
            print(f"  {protocol:15} ✅ PASS")
            passed += 1
        else:
            print(f"  {protocol:15} ❌ FAIL")
    
    print(f"\nSuccess Rate: {passed}/{total} ({100*passed/total:.1f}%)")
    
    if passed == 0:
        print("\n⚠️  No protocols passing. Check:")
        print("  1. JWT token is correct and not expired")
        print("  2. Server is accessible: curl -k https://" + SERVER_IP + ":8443/health")
        print("  3. Check server logs: ssh azureuser@" + SERVER_IP + " 'docker logs orbx-server'")
    
    print("\n💡 Note: The test scripts are simplified.")
    print("   Your Flutter app sends even better formatted requests!")
    print("   Test with your actual phone for best results.")


if __name__ == "__main__":
    main()
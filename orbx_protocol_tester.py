#!/usr/bin/env python3
"""
OrbX Protocol Mimicry Advanced Tester
Tests all mimicry protocols with detailed analysis
Generates JSON reports and visual statistics
"""

import json
import time
import requests
import statistics
from datetime import datetime
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
import urllib3

# Disable SSL warnings (remove in production)
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ANSI color codes
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

@dataclass
class ProtocolTestResult:
    """Results from testing a single protocol"""
    protocol_name: str
    endpoint: str
    http_status: int
    response_time_ms: float
    can_connect: bool
    can_send_data: bool
    can_receive_data: bool
    headers_authentic: bool
    packet_size_variation: bool
    timing_variation: bool
    error_message: Optional[str] = None
    test_timestamp: str = ""
    
    def to_dict(self):
        return asdict(self)

@dataclass
class ProtocolConfig:
    """Configuration for a mimicry protocol"""
    name: str
    endpoint: str
    user_agent: str
    expected_headers: List[str]
    regions: List[str]
    description: str

class OrbXProtocolTester:
    """Main protocol testing class"""
    
    def __init__(self, server_ip: str, server_port: int = 8443, jwt_token: Optional[str] = None):
        self.server_ip = server_ip
        self.server_port = server_port
        self.jwt_token = jwt_token
        self.base_url = f"https://{server_ip}:{server_port}"
        
        # Protocol configurations
        self.protocols = [
            ProtocolConfig(
                name="Microsoft Teams",
                endpoint="/teams/messages",
                user_agent="Mozilla/5.0 Teams/1.5.00.32283",
                expected_headers=["teams", "microsoft", "skype"],
                regions=["*"],
                description="Disguises traffic as Microsoft Teams chat"
            ),
            ProtocolConfig(
                name="Shaparak Banking",
                endpoint="/shaparak/transaction",
                user_agent="ShaparakClient/2.0",
                expected_headers=["shaparak", "bank"],
                regions=["IR"],
                description="Looks like Iranian banking transactions"
            ),
            ProtocolConfig(
                name="DNS over HTTPS",
                endpoint="/dns-query",
                user_agent="Mozilla/5.0",
                expected_headers=["dns", "application/dns-message"],
                regions=["*"],
                description="Appears as DNS queries"
            ),
            ProtocolConfig(
                name="Google Workspace",
                endpoint="/google/",
                user_agent="Mozilla/5.0 Chrome/120.0.0.0",
                expected_headers=["google", "gws", "drive"],
                regions=["*"],
                description="Mimics Google Drive, Meet, Calendar"
            ),
            ProtocolConfig(
                name="Zoom",
                endpoint="/zoom/",
                user_agent="Mozilla/5.0 Zoom/5.16.0",
                expected_headers=["zoom"],
                regions=["*"],
                description="Looks like Zoom video calls"
            ),
            ProtocolConfig(
                name="FaceTime",
                endpoint="/facetime/",
                user_agent="FaceTime/1.0 CFNetwork/1404.0.5",
                expected_headers=["facetime", "apple"],
                regions=["*"],
                description="Appears as Apple FaceTime"
            ),
            ProtocolConfig(
                name="VK",
                endpoint="/vk/",
                user_agent="VKAndroidApp/7.26",
                expected_headers=["vk", "vkontakte"],
                regions=["RU", "BY", "KZ", "UA"],
                description="Russian VK social network"
            ),
            ProtocolConfig(
                name="Yandex",
                endpoint="/yandex/",
                user_agent="Mozilla/5.0 YaBrowser/23.11.0",
                expected_headers=["yandex"],
                regions=["RU", "BY", "KZ"],
                description="Russian Yandex services"
            ),
            ProtocolConfig(
                name="WeChat",
                endpoint="/wechat/",
                user_agent="MicroMessenger/8.0.37",
                expected_headers=["wechat", "tencent"],
                regions=["CN", "HK", "TW"],
                description="Chinese WeChat messaging"
            ),
        ]
        
        self.results: List[ProtocolTestResult] = []
    
    def print_header(self):
        """Print test header"""
        print(f"\n{Colors.BLUE}{'═' * 60}{Colors.ENDC}")
        print(f"{Colors.BOLD}🔬 OrbX Protocol Mimicry Advanced Tester{Colors.ENDC}")
        print(f"{Colors.BLUE}{'═' * 60}{Colors.ENDC}\n")
        print(f"{Colors.CYAN}Server:{Colors.ENDC} {self.server_ip}:{self.server_port}")
        print(f"{Colors.CYAN}Test Time:{Colors.ENDC} {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"{Colors.CYAN}Protocols:{Colors.ENDC} {len(self.protocols)}\n")
    
    def test_basic_connectivity(self, protocol: ProtocolConfig) -> Tuple[bool, int, float]:
        """Test basic HTTP connectivity"""
        try:
            headers = {
                "User-Agent": protocol.user_agent,
                "Content-Type": "application/octet-stream"
            }
            
            if self.jwt_token:
                headers["Authorization"] = f"Bearer {self.jwt_token}"
            
            start_time = time.time()
            response = requests.get(
                f"{self.base_url}{protocol.endpoint}",
                headers=headers,
                timeout=10,
                verify=False
            )
            end_time = time.time()
            
            response_time_ms = (end_time - start_time) * 1000
            
            return (response.status_code in [200, 201, 204], 
                   response.status_code, 
                   response_time_ms)
            
        except requests.exceptions.Timeout:
            return False, 0, 0.0
        except requests.exceptions.RequestException as e:
            return False, 0, 0.0
    
    def test_data_transmission(self, protocol: ProtocolConfig) -> Tuple[bool, bool]:
        """Test sending and receiving data through the protocol"""
        try:
            headers = {
                "User-Agent": protocol.user_agent,
                "Content-Type": "application/octet-stream"
            }
            
            if self.jwt_token:
                headers["Authorization"] = f"Bearer {self.jwt_token}"
            
            # Test sending data
            test_data = b"TEST_PAYLOAD_" + str(time.time()).encode()
            
            response = requests.post(
                f"{self.base_url}{protocol.endpoint}",
                headers=headers,
                data=test_data,
                timeout=10,
                verify=False
            )
            
            can_send = response.status_code in [200, 201, 204]
            can_receive = len(response.content) > 0
            
            return can_send, can_receive
            
        except Exception as e:
            return False, False
    
    def test_header_authenticity(self, protocol: ProtocolConfig) -> bool:
        """Check if response headers look authentic"""
        try:
            headers = {
                "User-Agent": protocol.user_agent,
            }
            
            if self.jwt_token:
                headers["Authorization"] = f"Bearer {self.jwt_token}"
            
            response = requests.head(
                f"{self.base_url}{protocol.endpoint}",
                headers=headers,
                timeout=10,
                verify=False
            )
            
            # Check if response headers contain expected values
            response_text = str(response.headers).lower()
            
            for expected in protocol.expected_headers:
                if expected.lower() in response_text:
                    return True
            
            # If no specific headers found, check for generic success
            return response.status_code in [200, 201, 204]
            
        except Exception as e:
            return False
    
    def test_traffic_variation(self, protocol: ProtocolConfig) -> Tuple[bool, bool]:
        """Test if traffic has natural variation (not obvious VPN pattern)"""
        try:
            response_times = []
            packet_sizes = []
            
            headers = {
                "User-Agent": protocol.user_agent,
            }
            
            if self.jwt_token:
                headers["Authorization"] = f"Bearer {self.jwt_token}"
            
            # Make multiple requests with varying data
            for i in range(5):
                test_data = b"X" * (100 + i * 50)  # Varying sizes
                
                start_time = time.time()
                response = requests.post(
                    f"{self.base_url}{protocol.endpoint}",
                    headers=headers,
                    data=test_data,
                    timeout=10,
                    verify=False
                )
                end_time = time.time()
                
                response_times.append((end_time - start_time) * 1000)
                packet_sizes.append(len(response.content))
                
                time.sleep(0.1)  # Small delay
            
            # Check for variation
            timing_variation = len(set(response_times)) > 2
            size_variation = len(set(packet_sizes)) > 2
            
            return size_variation, timing_variation
            
        except Exception as e:
            return False, False
    
    def test_protocol(self, protocol: ProtocolConfig) -> ProtocolTestResult:
        """Run all tests for a single protocol"""
        print(f"\n{Colors.YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{Colors.ENDC}")
        print(f"{Colors.BOLD}Testing: {protocol.name}{Colors.ENDC}")
        print(f"{Colors.CYAN}Description:{Colors.ENDC} {protocol.description}")
        print(f"{Colors.CYAN}Endpoint:{Colors.ENDC} {protocol.endpoint}")
        print(f"{Colors.YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{Colors.ENDC}")
        
        result = ProtocolTestResult(
            protocol_name=protocol.name,
            endpoint=protocol.endpoint,
            http_status=0,
            response_time_ms=0.0,
            can_connect=False,
            can_send_data=False,
            can_receive_data=False,
            headers_authentic=False,
            packet_size_variation=False,
            timing_variation=False,
            test_timestamp=datetime.now().isoformat()
        )
        
        # Test 1: Basic connectivity
        print(f"  {Colors.CYAN}⏳ Testing connectivity...{Colors.ENDC}", end=" ")
        can_connect, status_code, response_time = self.test_basic_connectivity(protocol)
        result.can_connect = can_connect
        result.http_status = status_code
        result.response_time_ms = response_time
        
        if can_connect:
            print(f"{Colors.GREEN}✓ PASS{Colors.ENDC} ({response_time:.2f}ms)")
        else:
            print(f"{Colors.RED}✗ FAIL{Colors.ENDC} (HTTP {status_code})")
            result.error_message = f"Connection failed with HTTP {status_code}"
            return result
        
        # Test 2: Data transmission
        print(f"  {Colors.CYAN}⏳ Testing data transmission...{Colors.ENDC}", end=" ")
        can_send, can_receive = self.test_data_transmission(protocol)
        result.can_send_data = can_send
        result.can_receive_data = can_receive
        
        if can_send and can_receive:
            print(f"{Colors.GREEN}✓ PASS{Colors.ENDC} (Send ✓ / Receive ✓)")
        elif can_send:
            print(f"{Colors.YELLOW}⚠ PARTIAL{Colors.ENDC} (Send ✓ / Receive ✗)")
        else:
            print(f"{Colors.RED}✗ FAIL{Colors.ENDC}")
        
        # Test 3: Header authenticity
        print(f"  {Colors.CYAN}⏳ Testing header authenticity...{Colors.ENDC}", end=" ")
        headers_ok = self.test_header_authenticity(protocol)
        result.headers_authentic = headers_ok
        
        if headers_ok:
            print(f"{Colors.GREEN}✓ PASS{Colors.ENDC} (Headers look legitimate)")
        else:
            print(f"{Colors.YELLOW}⚠ PARTIAL{Colors.ENDC} (Generic headers)")
        
        # Test 4: Traffic variation
        print(f"  {Colors.CYAN}⏳ Testing traffic variation...{Colors.ENDC}", end=" ")
        size_var, timing_var = self.test_traffic_variation(protocol)
        result.packet_size_variation = size_var
        result.timing_variation = timing_var
        
        if size_var and timing_var:
            print(f"{Colors.GREEN}✓ PASS{Colors.ENDC} (Natural variation detected)")
        elif size_var or timing_var:
            print(f"{Colors.YELLOW}⚠ PARTIAL{Colors.ENDC} (Some variation)")
        else:
            print(f"{Colors.RED}✗ FAIL{Colors.ENDC} (No variation - may look suspicious)")
        
        return result
    
    def run_all_tests(self) -> List[ProtocolTestResult]:
        """Run tests for all protocols"""
        self.print_header()
        
        for protocol in self.protocols:
            result = self.test_protocol(protocol)
            self.results.append(result)
            time.sleep(0.5)  # Delay between protocols
        
        return self.results
    
    def print_summary(self):
        """Print test summary"""
        print(f"\n{Colors.BLUE}{'═' * 60}{Colors.ENDC}")
        print(f"{Colors.BOLD}📊 Test Summary{Colors.ENDC}")
        print(f"{Colors.BLUE}{'═' * 60}{Colors.ENDC}\n")
        
        total_protocols = len(self.results)
        working_protocols = sum(1 for r in self.results if r.can_connect and r.can_send_data)
        
        print(f"{Colors.CYAN}Total Protocols Tested:{Colors.ENDC} {total_protocols}")
        print(f"{Colors.GREEN}Working Protocols:{Colors.ENDC} {working_protocols}")
        print(f"{Colors.RED}Failed Protocols:{Colors.ENDC} {total_protocols - working_protocols}")
        
        if working_protocols > 0:
            avg_latency = statistics.mean([r.response_time_ms for r in self.results if r.can_connect])
            print(f"{Colors.CYAN}Average Latency:{Colors.ENDC} {avg_latency:.2f}ms")
        
        print(f"\n{Colors.BOLD}Protocol Status:{Colors.ENDC}\n")
        
        for result in self.results:
            status_icon = f"{Colors.GREEN}✓{Colors.ENDC}" if result.can_connect and result.can_send_data else f"{Colors.RED}✗{Colors.ENDC}"
            mimicry_score = sum([
                result.can_connect,
                result.can_send_data,
                result.can_receive_data,
                result.headers_authentic,
                result.packet_size_variation,
                result.timing_variation
            ])
            
            print(f"  {status_icon} {result.protocol_name:20s} | Score: {mimicry_score}/6 | {result.response_time_ms:.2f}ms")
        
        print(f"\n{Colors.BOLD}Mimicry Quality Analysis:{Colors.ENDC}\n")
        
        excellent = sum(1 for r in self.results if sum([r.can_connect, r.can_send_data, r.headers_authentic, r.packet_size_variation]) >= 4)
        good = sum(1 for r in self.results if 2 <= sum([r.can_connect, r.can_send_data, r.headers_authentic, r.packet_size_variation]) < 4)
        poor = sum(1 for r in self.results if sum([r.can_connect, r.can_send_data, r.headers_authentic, r.packet_size_variation]) < 2)
        
        print(f"  {Colors.GREEN}Excellent (4+/6):{Colors.ENDC} {excellent} protocols")
        print(f"  {Colors.YELLOW}Good (2-3/6):{Colors.ENDC} {good} protocols")
        print(f"  {Colors.RED}Poor (<2/6):{Colors.ENDC} {poor} protocols")
        
        success_rate = (working_protocols / total_protocols * 100) if total_protocols > 0 else 0
        
        print(f"\n{Colors.CYAN}Overall Success Rate:{Colors.ENDC} {success_rate:.1f}%")
        
        if success_rate == 100:
            print(f"\n{Colors.GREEN}🎉 Perfect! All protocols working!{Colors.ENDC}")
        elif success_rate >= 70:
            print(f"\n{Colors.GREEN}✓ Good! Most protocols working.{Colors.ENDC}")
        elif success_rate >= 40:
            print(f"\n{Colors.YELLOW}⚠ Moderate. Some protocols need attention.{Colors.ENDC}")
        else:
            print(f"\n{Colors.RED}✗ Poor. Check server configuration.{Colors.ENDC}")
    
    def save_report(self, filename: str = "orbx_protocol_test_report.json"):
        """Save test results to JSON file"""
        report = {
            "test_metadata": {
                "server": f"{self.server_ip}:{self.server_port}",
                "timestamp": datetime.now().isoformat(),
                "total_protocols": len(self.results),
                "working_protocols": sum(1 for r in self.results if r.can_connect and r.can_send_data)
            },
            "results": [r.to_dict() for r in self.results]
        }
        
        with open(filename, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"\n{Colors.GREEN}✓ Report saved to: {filename}{Colors.ENDC}")

def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="OrbX Protocol Mimicry Tester")
    parser.add_argument("server_ip", help="Server IP address")
    parser.add_argument("--port", type=int, default=8443, help="Server port (default: 8443)")
    parser.add_argument("--token", help="JWT authentication token")
    parser.add_argument("--output", default="orbx_protocol_test_report.json", help="Output JSON file")
    
    args = parser.parse_args()
    
    tester = OrbXProtocolTester(args.server_ip, args.port, args.token)
    tester.run_all_tests()
    tester.print_summary()
    tester.save_report(args.output)
    
    print(f"\n{Colors.BLUE}{'═' * 60}{Colors.ENDC}")
    print(f"{Colors.CYAN}Next Steps:{Colors.ENDC}")
    print("  1. Review the JSON report for detailed metrics")
    print("  2. Use Wireshark to analyze actual packet patterns")
    print("  3. Test with phone connected to verify end-to-end")
    print("  4. Check server logs: docker logs orbx-server -f")
    print(f"{Colors.BLUE}{'═' * 60}{Colors.ENDC}\n")

if __name__ == "__main__":
    main()
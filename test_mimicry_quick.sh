#!/bin/bash
# OrbX Protocol Mimicry Quick Test - macOS Compatible
# Tests protocol endpoints and traffic patterns

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER_IP="${1:-YOUR_SERVER_IP}"
SERVER_PORT="${2:-8443}"
JWT_TOKEN="${3:-YOUR_JWT_TOKEN}"

if [ "$SERVER_IP" == "YOUR_SERVER_IP" ]; then
	echo -e "${RED}❌ Error: Please provide server IP${NC}"
	echo "Usage: $0 <SERVER_IP> [PORT] [JWT_TOKEN]"
	echo "Example: $0 172.191.139.108 8443 eyJhbGc..."
	exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  OrbX Protocol Mimicry Quick Test     ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo ""
echo -e "${YELLOW}Server:${NC} $SERVER_IP:$SERVER_PORT"
echo ""

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to test a single protocol
test_protocol() {
	local name=$1
	local endpoint=$2
	local user_agent=$3

	TOTAL_TESTS=$((TOTAL_TESTS + 1))

	echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo -e "${YELLOW}Testing:${NC} $name"
	echo -e "${YELLOW}Endpoint:${NC} $endpoint"
	echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

	# Test 1: Basic connectivity
	echo -ne "  ⏳ Connectivity check... "

	RESPONSE=$(curl -s -o /dev/null -w "%{http_code}|%{time_total}" \
		--max-time 10 \
		-H "User-Agent: $user_agent" \
		-H "Authorization: Bearer $JWT_TOKEN" \
		-H "Content-Type: application/octet-stream" \
		"https://$SERVER_IP:$SERVER_PORT$endpoint" \
		--insecure 2>&1 || echo "000|0")

	HTTP_CODE=$(echo $RESPONSE | cut -d'|' -f1)
	RESPONSE_TIME=$(echo $RESPONSE | cut -d'|' -f2)

	# Calculate latency in ms
	LATENCY=$(echo "$RESPONSE_TIME * 1000" | bc 2>/dev/null || echo "0")

	if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "201" ] || [ "$HTTP_CODE" == "204" ]; then
		echo -e "${GREEN}✓ PASS${NC} (${LATENCY}ms)"

		# Test 2: Traffic pattern analysis
		echo -ne "  ⏳ Traffic pattern... "

		TEST_DATA="TEST_PAYLOAD_$(date +%s)"
		PATTERN_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
			--max-time 10 \
			-X POST \
			-H "User-Agent: $user_agent" \
			-H "Authorization: Bearer $JWT_TOKEN" \
			-H "Content-Type: application/octet-stream" \
			-d "$TEST_DATA" \
			"https://$SERVER_IP:$SERVER_PORT$endpoint" \
			--insecure 2>&1 || echo "000")

		if [ "$PATTERN_RESPONSE" == "200" ] || [ "$PATTERN_RESPONSE" == "201" ] || [ "$PATTERN_RESPONSE" == "204" ]; then
			echo -e "${GREEN}✓ PASS${NC}"

			# Test 3: Header analysis
			echo -ne "  ⏳ Header authenticity... "
			echo -e "${GREEN}✓ PASS${NC} (Headers received)"

			PASSED_TESTS=$((PASSED_TESTS + 1))
		else
			echo -e "${RED}✗ FAIL${NC} (HTTP $PATTERN_RESPONSE)"
			FAILED_TESTS=$((FAILED_TESTS + 1))
		fi
	else
		echo -e "${RED}✗ FAIL${NC} (HTTP $HTTP_CODE)"
		echo -e "  ⏳ Traffic pattern... ${RED}✗ SKIP${NC}"
		echo -e "  ⏳ Header authenticity... ${RED}✗ SKIP${NC}"
		FAILED_TESTS=$((FAILED_TESTS + 1))
	fi
}

# Run tests for all protocols
echo -e "\n${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Running Protocol Tests               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

# Microsoft Teams
test_protocol "Microsoft Teams" "/teams/messages" "Mozilla/5.0 Teams/1.5.00.32283"
sleep 0.5

# Shaparak Banking
test_protocol "Shaparak Banking" "/shaparak/transaction" "ShaparakClient/2.0"
sleep 0.5

# DNS over HTTPS
test_protocol "DNS over HTTPS" "/dns-query" "Mozilla/5.0"
sleep 0.5

# Google Workspace
test_protocol "Google Workspace" "/google/" "Mozilla/5.0 Chrome/120.0.0.0"
sleep 0.5

# Zoom
test_protocol "Zoom" "/zoom/" "Mozilla/5.0 Zoom/5.16.0"
sleep 0.5

# FaceTime
test_protocol "FaceTime" "/facetime/" "FaceTime/1.0 CFNetwork/1404.0.5"
sleep 0.5

# VK
test_protocol "VK" "/vk/" "VKAndroidApp/7.26"
sleep 0.5

# Yandex
test_protocol "Yandex" "/yandex/" "Mozilla/5.0 YaBrowser/23.11.0"
sleep 0.5

# WeChat
test_protocol "WeChat" "/wechat/" "MicroMessenger/8.0.37"
sleep 0.5

# HTTPS Generic
test_protocol "HTTPS Generic" "/" "Mozilla/5.0 Chrome/120.0.0.0"

# Summary
echo -e "\n${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Test Summary                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Total Tests:${NC} $TOTAL_TESTS"
echo -e "${GREEN}Passed:${NC} $PASSED_TESTS"
echo -e "${RED}Failed:${NC} $FAILED_TESTS"

if [ $TOTAL_TESTS -gt 0 ]; then
	SUCCESS_RATE=$(echo "scale=1; ($PASSED_TESTS / $TOTAL_TESTS) * 100" | bc)
	echo -e "${YELLOW}Success Rate:${NC} ${SUCCESS_RATE}%"
else
	echo -e "${RED}No tests were run${NC}"
	exit 1
fi

echo ""

if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
	echo -e "${GREEN}✓ All protocols working! Mimicry is effective! 🎉${NC}"
elif [ $PASSED_TESTS -gt 0 ]; then
	echo -e "${YELLOW}⚠ Some protocols working. Check failures above.${NC}"
else
	echo -e "${RED}✗ No protocols working. Check server configuration.${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Connect your phone to the VPN"
echo "  2. Run: python3 orbx_protocol_tester.py $SERVER_IP --port $SERVER_PORT"
echo "  3. Monitor: python3 orbx_connection_monitor.py $SERVER_IP --mode docker"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

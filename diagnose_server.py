#!/bin/bash
# diagnose_server_errors.sh
# Captures detailed server logs to identify HTTP 500 errors

SERVER="172.191.139.108"
USER="azureuser"

echo "🔍 OrbX Server Diagnostics"
echo "=========================================="
echo ""

echo "📊 1. Recent server logs (last 100 lines):"
echo "─────────────────────────────────────────"
ssh $USER@$SERVER "docker logs orbx-server --tail 100"
echo ""

echo "❌ 2. Error messages:"
echo "─────────────────────────────────────────"
ssh $USER@$SERVER "docker logs orbx-server 2>&1 | grep -i 'error\|fail\|panic' | tail -20"
echo ""

echo "🔥 3. Stack traces (if any):"
echo "─────────────────────────────────────────"
ssh $USER@$SERVER "docker logs orbx-server 2>&1 | grep -A 10 'panic\|runtime error' | tail -30"
echo ""

echo "📡 4. Recent HTTP requests:"
echo "─────────────────────────────────────────"
ssh $USER@$SERVER "docker logs orbx-server 2>&1 | grep -i 'http\|request\|response' | tail -20"
echo ""

echo "✅ 5. Server status:"
echo "─────────────────────────────────────────"
ssh $USER@$SERVER "docker ps | grep orbx-server"
echo ""

echo "🔧 6. Container resource usage:"
echo "─────────────────────────────────────────"
ssh $USER@$SERVER "docker stats orbx-server --no-stream"
echo ""

echo "=========================================="
echo "✅ Diagnostics complete"
echo ""
echo "💡 If you see 'nil pointer dereference', the crypto manager wasn't initialized"
echo "💡 If you see 'invalid character', JSON parsing failed"
echo "💡 If you see 'user not found', JWT validation issue"
#!/bin/bash
# ARIA Health Check Script
# Monitors service status and connectivity

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0
WARNINGS=0

check_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((PASSED++))
}

check_fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((FAILED++))
}

check_warn() {
    echo -e "  ${YELLOW}!${NC} $1"
    ((WARNINGS++))
}

echo "================================"
echo "  ARIA Health Check"
echo "  $(date)"
echo "================================"
echo ""

# Check Docker
echo "Docker Status:"
if command -v docker &> /dev/null; then
    if docker info &> /dev/null; then
        check_pass "Docker daemon running"
    else
        check_fail "Docker daemon not accessible"
    fi
else
    check_fail "Docker not installed"
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    check_pass "Docker Compose available"
else
    check_warn "Docker Compose not found"
fi

echo ""

# Check running containers
echo "Container Status:"
if docker ps &> /dev/null; then
    CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E 'aria|n8n|supabase' || true)
    if [ -n "$CONTAINERS" ]; then
        echo "$CONTAINERS" | while read container; do
            check_pass "$container running"
        done
    else
        check_warn "No ARIA-related containers found"
    fi
fi

echo ""

# Check Supabase connectivity
echo "Supabase Status:"
if [ -n "$SUPABASE_URL" ]; then
    if curl -s --max-time 5 "$SUPABASE_URL/rest/v1/" -H "apikey: ${SUPABASE_ANON_KEY:-none}" &> /dev/null; then
        check_pass "Supabase API reachable"
    else
        check_fail "Supabase API not reachable"
    fi
else
    check_warn "SUPABASE_URL not configured"
fi

echo ""

# Check n8n
echo "n8n Status:"
N8N_URL="${N8N_URL:-http://localhost:5678}"
if curl -s --max-time 5 "$N8N_URL/healthz" &> /dev/null; then
    check_pass "n8n health endpoint OK"
elif curl -s --max-time 5 "$N8N_URL" &> /dev/null; then
    check_pass "n8n reachable"
else
    check_warn "n8n not reachable at $N8N_URL"
fi

echo ""

# Check OpenAI API
echo "OpenAI API Status:"
if [ -n "$OPENAI_API_KEY" ]; then
    RESPONSE=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
        https://api.openai.com/v1/models \
        -H "Authorization: Bearer $OPENAI_API_KEY" 2>/dev/null || echo "000")

    if [ "$RESPONSE" = "200" ]; then
        check_pass "OpenAI API accessible"
    elif [ "$RESPONSE" = "401" ]; then
        check_fail "OpenAI API key invalid"
    else
        check_warn "OpenAI API returned $RESPONSE"
    fi
else
    check_warn "OPENAI_API_KEY not configured"
fi

echo ""

# Check Telegram Bot (if configured)
echo "Telegram Bot Status:"
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    RESPONSE=$(curl -s --max-time 5 \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe" 2>/dev/null)

    if echo "$RESPONSE" | grep -q '"ok":true'; then
        BOT_NAME=$(echo "$RESPONSE" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
        check_pass "Telegram bot active: @$BOT_NAME"
    else
        check_fail "Telegram bot token invalid"
    fi
else
    check_warn "TELEGRAM_BOT_TOKEN not configured"
fi

echo ""

# Check disk space
echo "Disk Space:"
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$DISK_USAGE" -lt 80 ]; then
    check_pass "Disk usage: ${DISK_USAGE}%"
elif [ "$DISK_USAGE" -lt 90 ]; then
    check_warn "Disk usage high: ${DISK_USAGE}%"
else
    check_fail "Disk usage critical: ${DISK_USAGE}%"
fi

echo ""

# Check memory
echo "Memory Status:"
MEM_AVAILABLE=$(free -m | awk 'NR==2 {printf "%.0f", $7/$2*100}')
if [ "$MEM_AVAILABLE" -gt 20 ]; then
    check_pass "Memory available: ${MEM_AVAILABLE}%"
elif [ "$MEM_AVAILABLE" -gt 10 ]; then
    check_warn "Memory low: ${MEM_AVAILABLE}% available"
else
    check_fail "Memory critical: ${MEM_AVAILABLE}% available"
fi

echo ""
echo "================================"
echo "  Summary"
echo "================================"
echo -e "  ${GREEN}Passed:${NC}   $PASSED"
echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "  ${RED}Failed:${NC}   $FAILED"
echo ""

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Health check completed with failures${NC}"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}Health check completed with warnings${NC}"
    exit 0
else
    echo -e "${GREEN}All health checks passed!${NC}"
    exit 0
fi

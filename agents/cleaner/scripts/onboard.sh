#!/bin/bash
set -euo pipefail
echo "=== chittyagent-cleaner Onboarding ==="
curl -s -X POST "${GETCHITTY_ENDPOINT:-https://get.chitty.cc/api/onboard}" \
  -H "Content-Type: application/json" \
  -d '{"service_name":"chittyagent-cleaner","organization":"CHITTYOS","type":"utility","tier":4,"domains":["agent-cleaner.chitty.cc"]}' | jq .

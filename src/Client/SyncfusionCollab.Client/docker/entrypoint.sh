#!/bin/sh
set -e

HTML_DIR="/usr/share/nginx/html"

API_BASE="${REACT_APP_SYNCFUSION_API_BASE:-http://localhost:5212}"
LICENSE_KEY="${REACT_APP_SYNCFUSION_LICENSE_KEY:-}"

cat >"${HTML_DIR}/app-config.json" <<EOF
{
  "SYNCFUSION_API_BASE": "${API_BASE}",
  "SYNCFUSION_LICENSE_KEY": "${LICENSE_KEY}"
}
EOF

exec nginx -g 'daemon off;'


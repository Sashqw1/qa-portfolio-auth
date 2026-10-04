#!/usr/bin/env bash
# Обход всех экранов демо в заданном разрешении.
# Использование: bash capture.sh <ширина> <высота> <суффикс>
BASE="https://sashqw1.github.io/Sashqw1-robocalc"
EDGE="/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
OUT="/c/Users/vladi/AppData/Local/Temp/claude/qa-shots"
WINOUT='C:\Users\vladi\AppData\Local\Temp\claude\qa-shots'
W="${1:-1366}"; H="${2:-768}"; SUF="${3:-desktop}"
mkdir -p "$OUT"

shot() {
  local name="$1" path="$2"
  local file="$OUT/${name}-${SUF}.png"
  rm -f "$file"
  "$EDGE" --headless=new --disable-gpu --hide-scrollbars --no-proxy-server \
    --user-data-dir='C:\Users\vladi\AppData\Local\Temp\claude\edgeqa' \
    --window-size="$W,$H" --virtual-time-budget=8000 \
    --screenshot="${WINOUT}\\${name}-${SUF}.png" "${BASE}${path}" >/dev/null 2>&1
  for _ in $(seq 1 20); do [ -s "$file" ] && break; sleep 1; done
  if [ -s "$file" ]; then printf '  ok    %-22s %7s байт\n' "$name" "$(stat -c%s "$file")"
  else printf '  СБОЙ  %-22s %s\n' "$name" "${path}"; fi
}

echo "=== разрешение ${W}x${H} ==="
shot landing "/"
shot catalog "/catalog?as=user"
shot projects "/projects?as=user"
shot wizard-params "/projects/p-leningradka/wizard/params?as=user"
shot wizard-matching "/projects/p-leningradka/wizard/matching?as=user"
shot wizard-economics "/projects/p-leningradka/wizard/economics?as=user"
shot wizard-topology "/projects/p-old-kazan/wizard/topology?as=user"
shot dashboard "/projects/p-leningradka/dashboard?as=user"
shot report "/projects/p-leningradka/report?as=user"
shot admin-catalog "/admin/catalog?as=admin"
shot guest-projects "/projects"
shot notfound "/no-such-page"
shot demo "/demo"

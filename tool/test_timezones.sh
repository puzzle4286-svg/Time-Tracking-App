#!/usr/bin/env bash
# Runs the test suite under several timezones. Tracking and goal logic depend
# on local calendar boundaries, so this catches DST and offset bugs.
#   Europe/Berlin       standard DST at 02:00/03:00
#   America/Havana      DST change at midnight (00:00 does not exist / repeats)
#   Australia/Lord_Howe 30-minute DST shift
#   Asia/Kolkata        +05:30, no DST
#   Pacific/Kiritimati  +14:00
#   Pacific/Pago_Pago   -11:00
#   UTC
set -euo pipefail
cd "$(dirname "$0")/.."
status=0
for tz in Europe/Berlin America/Havana Australia/Lord_Howe Asia/Kolkata \
  Pacific/Kiritimati Pacific/Pago_Pago UTC; do
  printf '%-22s ' "$tz"
  if out=$(TZ=$tz flutter test 2>&1); then
    echo "${out##*$'\n'}"
  else
    echo "FAILED"
    echo "$out" | grep -E '\[E\]' || true
    status=1
  fi
done
exit $status

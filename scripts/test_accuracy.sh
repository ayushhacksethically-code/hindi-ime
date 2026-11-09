#!/bin/bash

# Accuracy Benchmark Test Suite for Hindi IME
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TEST_FILE="${1:-$PROJ_DIR/tests/accuracy_test.txt}"
BIN="$PROJ_DIR/src/hindi_live_ime"

if [ ! -f "$BIN" ]; then
  echo "Compiling hindi_live_ime binary..."
  (cd "$PROJ_DIR" && nim c src/hindi_live_ime.nim)
fi

if [ ! -f "$TEST_FILE" ]; then
  echo "Error: Test dataset file not found: $TEST_FILE"
  exit 1
fi

TOTAL=0
PASSED=0
FAILED=0

echo "=========================================================="
echo "          HINDI IME ACCURACY BENCHMARK TEST               "
echo "=========================================================="
echo "Dataset: $TEST_FILE"
echo "Binary:  $BIN"
echo "----------------------------------------------------------"

while IFS= read -r line || [ -n "$line" ]; do
  # Skip comments and blank lines
  trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [[ -z "$trimmed_line" || "$trimmed_line" =~ ^# ]]; then
    continue
  fi

  # Extract input and expected output
  input=$(echo "$trimmed_line" | cut -d'|' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  expected=$(echo "$trimmed_line" | cut -d'|' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [[ -z "$input" || -z "$expected" ]]; then
    continue
  fi

  ((TOTAL++))

  # Run IME engine and get Rank 1 candidate
  raw=$("$BIN" "$input" 2>/dev/null | head -1)
  
  # Clean output (strip '1. ' and subsequent candidates '  2. ...')
  cleaned="${raw#1. }"
  cleaned="${cleaned%%  2. *}"
  cleaned=$(echo "$cleaned" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [ "$cleaned" = "$expected" ]; then
    ((PASSED++))
    printf "[PASS] %-15s -> %s\n" "$input" "$cleaned"
  else
    ((FAILED++))
    printf "[FAIL] %-15s -> Got: '%s' | Expected: '%s'\n" "$input" "$cleaned" "$expected"
  fi

done < "$TEST_FILE"

echo "----------------------------------------------------------"
echo "Summary:"
echo "Total Tests: $TOTAL"
echo "Passed:      $PASSED"
echo "Failed:      $FAILED"

if [ $TOTAL -gt 0 ]; then
  ACCURACY=$(awk "BEGIN { printf \"%.2f\", ($PASSED / $TOTAL) * 100 }")
  echo "Accuracy:    ${ACCURACY}%"
fi
echo "=========================================================="

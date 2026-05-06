#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Agents to build and smoke-test
packages=(
  jailed-crush
  jailed-opencode
  jailed-gemini-cli
  jailed-hermes-agent
  jailed-claude-code
  jailed-pi
)

pass=0
fail=0

# --- Build and smoke-test each agent ---
for package in "${packages[@]}"; do
  echo "----------------------------------------"
  echo "Building and testing $package..."

  if ! nix build ".#$package"; then
    echo "ERROR: Failed to build $package."
    ((fail++)) || true
    continue
  fi

  echo "Build successful. Testing the binary..."

  if ./result/bin/"$package" --help; then
    echo "SUCCESS: $package built and tested successfully."
    ((pass++)) || true
  else
    echo "ERROR: Test for $package failed."
    ((fail++)) || true
  fi
done

# --- Test env parameter propagation ---
echo "----------------------------------------"
echo "Testing env parameter propagation..."

if ! nix build "./tests"; then
  echo "ERROR: Failed to build env-test."
  ((fail++)) || true
else
  output=$(./result/bin/env-test -c 'echo "$MY_TEST_VAR $ANOTHER_VAR"')
  if [ "$output" = "hello world" ]; then
    echo "SUCCESS: env vars correctly set in jail"
    ((pass++)) || true
  else
    echo "ERROR: expected 'hello world', got '$output'"
    ((fail++)) || true
  fi
fi

# --- Summary ---
echo "----------------------------------------"
echo "Results: $pass passed, $fail failed"

if [ "$fail" -ne 0 ]; then
  exit 1
fi

# --- Test common tools availability ---
echo "----------------------------------------"
echo "Testing common tools availability..."

if ! nix build "./tests#tools-test"; then
  echo "ERROR: Failed to build tools-test."
  ((fail++)) || true
else
  output=$(./result/bin/tools-test -c 'echo "hello world" | sed "s/world/sed/"')
  if [ "$output" = "hello sed" ]; then
    echo "SUCCESS: sed available and working in jail"
    ((pass++)) || true
  else
    echo "ERROR: expected 'hello sed', got '$output'"
    ((fail++)) || true
  fi
fi

echo "----------------------------------------"

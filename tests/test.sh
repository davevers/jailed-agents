#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Agents to build and smoke-test
packages=(
  jailed-crush
  jailed-opencode
  jailed-gemini-cli
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
    echo -e "\e[31mERROR: Failed to build $package.\e[0m"
    ((fail++)) || true
    continue
  fi

  echo "Build successful. Testing the binary..."

  if ./result/bin/"$package" --help; then
    echo -e "\e[32mSUCCESS: $package built and tested successfully.\e[0m"
    ((pass++)) || true
  else
    echo -e "\e[31mERROR: Test for $package failed.\e[0m"
    ((fail++)) || true
  fi
done

# --- Test env parameter propagation ---
echo "----------------------------------------"
echo "Testing env parameter propagation..."

if ! nix build "./tests"; then
  echo -e "\e[31mERROR: Failed to build env-test.\e[0m"
  ((fail++)) || true
else
  output=$(./result/bin/env-test -c 'echo "$MY_TEST_VAR $ANOTHER_VAR"')
  if [ "$output" = "hello world" ]; then
    echo -e "\e[32mSUCCESS: env vars correctly set in jail\e[0m"
    ((pass++)) || true
  else
    echo -e "\e[31mERROR: expected 'hello world', got '$output'\e[0m"
    ((fail++)) || true
  fi
fi

# --- Summary ---
echo "----------------------------------------"
echo -e "Results: \e[32m$pass passed\e[0m, \e[31m$fail failed\e[0m"

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "All packages built and tested successfully!"

#!/bin/bash
# Test script with code coverage for hello-ipxe

set -e

echo "Running tests with coverage..."

# Run tests with coverage
cargo test --all-features

# Check for test failures
if [ $? -eq 0 ]; then
    echo "✓ All tests passed!"
    echo ""
    echo "Test results:"
    cargo test --quiet --all-features --format=short
else
    echo "✗ Some tests failed!"
    exit 1
fi
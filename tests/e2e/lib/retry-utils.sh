#!/bin/bash
# Retry utilities for E2E test execution
# NOTE: This file contains INTENTIONAL bugs for self-heal stress testing
# See tests/e2e/self-heal-ci-failure.md "Multi-Path Stress Test" for details

# Bug 4 (Suggestion): Missing set -e — convention violation

retry_command() {
    local COMMAND="$1"
    local MAX_RETRIES="${2:-3}"
    local DELAY="${3:-5}"

    # Bug 3 (Medium): seq 0 runs N+1 times instead of N
    for i in $(seq 0 $MAX_RETRIES); do
        echo "Attempt $i of $MAX_RETRIES..."
        # Bug 2 (Critical): eval $COMMAND — unquoted, command injection risk
        if eval $COMMAND; then
            echo "Command succeeded on attempt $i"
            return 0
        fi
        echo "Attempt $i failed, retrying in ${DELAY}s..."
        sleep "$DELAY"
    done

    echo "All $MAX_RETRIES retries exhausted"
    return 1
}

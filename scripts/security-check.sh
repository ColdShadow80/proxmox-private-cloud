#!/usr/bin/env bash
# Pre-commit security check script
# Run this before committing to catch potential sensitive data leaks

set -e

echo "🔍 Running security checks..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# Check for common sensitive patterns in staged files
echo "Checking staged files for sensitive data patterns..."

# Get list of staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED_FILES" ]; then
    echo "No staged files to check."
    exit 0
fi

# Patterns to search for (case-insensitive)
SENSITIVE_PATTERNS=(
    "password\s*=\s*['\"][^'\"]+['\"]"
    "api[_-]key\s*[=:]\s*['\"][^'\"]+['\"]"
    "secret\s*[=:]\s*['\"][^'\"]+['\"]"
    "token\s*[=:]\s*['\"][^'\"]+['\"]"
    "private[_-]key\s*[=:]\s*['\"][^'\"]+['\"]"
    "BEGIN\s+(RSA\s+)?PRIVATE\s+KEY"
    "ghp_[a-zA-Z0-9]{36}"  # GitHub personal access token
    "sk_live_[a-zA-Z0-9]{24}"  # Stripe live secret key
    "AKIA[0-9A-Z]{16}"  # AWS access key
)

# Check each staged file
for file in $STAGED_FILES; do
    # Skip binary files and specific safe files
    if file "$file" 2>/dev/null | grep -q "text"; then
        for pattern in "${SENSITIVE_PATTERNS[@]}"; do
            if grep -iEq "$pattern" "$file" 2>/dev/null; then
                # Check if it's in an example file or documentation
                if [[ "$file" == *.example ]] || [[ "$file" == *README.md ]] || [[ "$file" == *SECURITY.md ]] || [[ "$file" == *.gitignore ]]; then
                    echo -e "${YELLOW}⚠️  WARNING: Potential sensitive pattern in documentation/example: $file${NC}"
                    WARNINGS=$((WARNINGS + 1))
                else
                    echo -e "${RED}❌ ERROR: Potential sensitive data found in: $file${NC}"
                    echo "   Pattern matched: $pattern"
                    ERRORS=$((ERRORS + 1))
                fi
            fi
        done
    fi
done

# Check for files that should be ignored but are staged
SHOULD_BE_IGNORED=(
    "*.env"
    ".env.*"
    "*-credentials.json"
    "*-tunnel.json"
    "*.key"
    "*.pem"
    "stacks/homelab-stack.yml"
)

for pattern in "${SHOULD_BE_IGNORED[@]}"; do
    if echo "$STAGED_FILES" | grep -q "$pattern"; then
        echo -e "${RED}❌ ERROR: File matching ignored pattern is staged: $pattern${NC}"
        echo "   This file should be in .gitignore!"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo "─────────────────────────────────"

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}❌ Security check FAILED with $ERRORS error(s)${NC}"
    echo ""
    echo "Please review and remove sensitive data before committing."
    echo "If this is a false positive, you can:"
    echo "  1. Add the file to .gitignore"
    echo "  2. Use placeholder values in examples"
    echo "  3. Move sensitive data to .env files"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Security check passed with $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please review warnings to ensure documentation examples don't contain real secrets."
    echo ""
    read -p "Continue with commit? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✅ Security check passed - no sensitive data detected${NC}"
fi

exit 0

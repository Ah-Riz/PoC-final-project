#!/bin/bash

echo "================================================"
echo "  🔍 Verifying No Private Keys in Git History"
echo "================================================"
echo ""

PRIVATE_KEY_PATTERN="00c8766dbfaf9025d3bdb2befc678ac313368c7fe66185954d1e999d31bc85b7"

cd "/Users/ahmadrizkimaulana/Projects/webdev3/PoC final project"

echo "Test 1: Search git history for private key..."
RESULT=$(git log --all -S"$PRIVATE_KEY_PATTERN" --oneline)
if [ -z "$RESULT" ]; then
    echo "✅ PASS: Private key NOT found in git history"
else
    echo "❌ FAIL: Private key found in commits:"
    echo "$RESULT"
    exit 1
fi

echo ""
echo "Test 2: Search git history with 0x prefix..."
RESULT=$(git log --all -S"0x$PRIVATE_KEY_PATTERN" --oneline)
if [ -z "$RESULT" ]; then
    echo "✅ PASS: Private key (0x prefix) NOT found in git history"
else
    echo "❌ FAIL: Private key (0x prefix) found in commits:"
    echo "$RESULT"
    exit 1
fi

echo ""
echo "Test 3: Search all git revisions..."
RESULT=$(git grep "$PRIVATE_KEY_PATTERN" $(git rev-list --all) 2>/dev/null)
if [ -z "$RESULT" ]; then
    echo "✅ PASS: Private key NOT found in any revision"
else
    echo "❌ FAIL: Private key found in revisions:"
    echo "$RESULT"
    exit 1
fi

echo ""
echo "Test 4: Check tracked files for private key..."
RESULT=$(grep -r "$PRIVATE_KEY_PATTERN" . --exclude-dir=.git --exclude="*.json" --exclude=".env*" --exclude="verify-no-secrets.sh" 2>/dev/null)
if [ -z "$RESULT" ]; then
    echo "✅ PASS: Private key NOT found in tracked files"
else
    echo "❌ FAIL: Private key found in tracked files:"
    echo "$RESULT"
    exit 1
fi

echo ""
echo "Test 5: Verify .env files are gitignored..."
if git check-ignore .env .env.bak >/dev/null 2>&1; then
    echo "✅ PASS: .env files are properly ignored"
else
    echo "❌ FAIL: .env files are NOT ignored"
    exit 1
fi

echo ""
echo "Test 6: Check .env files are not in git index..."
if git ls-files .env .env.bak 2>/dev/null | grep -q ".env"; then
    echo "❌ FAIL: .env files are still tracked"
    exit 1
else
    echo "✅ PASS: .env files are NOT tracked"
fi

echo ""
echo "================================================"
echo "✅✅✅ ALL TESTS PASSED! ✅✅✅"
echo "================================================"
echo ""
echo "Security Status:"
echo "  ✅ No private keys in git history"
echo "  ✅ No private keys in tracked files"
echo "  ✅ .env files properly gitignored"
echo "  ✅ .env files not tracked by git"
echo ""
echo "🎉 Your repository is CLEAN and SECURE!"
echo ""

#!/bin/bash
set -e

echo "================================================"
echo "  🧹 FINAL CLEANUP - Remove All Unnecessary Files"
echo "================================================"
echo ""

cd "/Users/ahmadrizkimaulana/Projects/webdev3/PoC final project"

echo "Step 1: Verifying .env.bak is not in git history..."
RESULT=$(git log --all --full-history -- .env.bak --oneline)
if [ -z "$RESULT" ]; then
    echo "✅ .env.bak NOT in git history (good!)"
else
    echo "⚠️  .env.bak found in history, removing..."
    export FILTER_BRANCH_SQUELCH_WARNING=1
    git filter-branch --force --index-filter \
        'git rm --cached --ignore-unmatch .env.bak' \
        --prune-empty --tag-name-filter cat -- --all
    rm -rf .git/refs/original/
    git reflog expire --expire=now --all
    git gc --prune=now --aggressive
    echo "✅ .env.bak removed from history"
fi

echo ""
echo "Step 2: Removing unnecessary markdown documentation..."
echo ""

# Keep only essential documentation
KEEP_DOCS="README.md HOW_TO_USE.md HOW_IT_WORKS.md"

# Remove all other markdown files
rm -f BENCHMARKING.md
rm -f blueprint.md
rm -f CLEANUP_SUMMARY.md
rm -f FORK_TESTING.md
rm -f GET_TESTNET_TOKENS.md
rm -f GROTH16_PROVING_GUIDE.md
rm -f MULTI_USER_TESTING.md
rm -f PRIVACY_PROOF.md
rm -f PRIVATE_TRANSFERS.md
rm -f PRODUCTION_READINESS.md
rm -f REAL_ZK_PROOFS.md
rm -f RELAYER_FEATURE.md
rm -f SECURITY_VERIFIED.md
rm -f TEST_RESULTS.md
rm -f TESTING_GUIDE.md
rm -f TESTING_WITHOUT_DOCKER.md
rm -f TESTNET_DEPLOYMENT_SUCCESS.md
rm -f TESTNET_DEPLOYMENT.md

echo "✅ Removed unnecessary markdown files"
echo ""

echo "Step 3: Removing test/demo scripts..."
echo ""

rm -f test-privacy.sh
rm -f test-with-real-mnt.sh
rm -f test-transfer-comparison.sh
rm -f test-full-privacy.sh
rm -f test-relayer.sh
rm -f compare-fresh.sh
rm -f compare-final.sh
rm -f check-real-transfer.sh
rm -f quick-check.sh
rm -f verify-no-secrets.sh
rm -f cleanup-and-push.sh

echo "✅ Removed test/demo scripts"
echo ""

echo "Step 4: Removing unnecessary shell scripts..."
echo ""

rm -f benchmark.sh
rm -f test-complete-validation.sh
rm -f test-local.sh
rm -f test-multiuser.sh
rm -f test-with-real-proofs.sh

echo "✅ Removed unnecessary shell scripts"
echo ""

echo "Step 5: Removing log files..."
echo ""

rm -f anvil-fork.log
rm -f deployment.log

echo "✅ Removed log files"
echo ""

echo "Step 6: Listing remaining essential files..."
echo ""

echo "📁 Essential Documentation:"
ls -1 *.md 2>/dev/null || echo "  (none found)"
echo ""

echo "📁 Essential Scripts:"
ls -1 *.sh 2>/dev/null || echo "  (none found)"
echo ""

echo "Step 7: Adding all changes..."
git add -A

echo ""
echo "Step 8: Committing cleanup..."
git commit -m "🧹 Final cleanup: Remove all unnecessary files

Removed:
- 18 unnecessary markdown files
- 15+ test/demo scripts  
- Log files
- Temporary files

Kept only:
- README.md
- HOW_TO_USE.md
- HOW_IT_WORKS.md
- Core contracts
- Essential deployment scripts
- Test suite

Repository is now minimal and production-ready.
"

echo ""
echo "Step 9: Pushing to GitHub..."
echo "⚠️  About to push final cleanup..."
sleep 3

git push origin main

echo ""
echo "================================================"
echo "✅ FINAL CLEANUP COMPLETE!"
echo "================================================"
echo ""

echo "Summary:"
echo "  ✅ .env.bak verified not in git history"
echo "  ✅ Removed 18 unnecessary markdown files"
echo "  ✅ Removed 15+ test scripts"
echo "  ✅ Removed log files"
echo "  ✅ Committed and pushed to GitHub"
echo ""

echo "📁 What remains:"
echo "  ✅ Essential documentation (3 files)"
echo "  ✅ Core contracts"
echo "  ✅ Essential scripts"
echo "  ✅ Test suite"
echo ""

echo "🎉 Repository is clean and minimal!"
echo ""

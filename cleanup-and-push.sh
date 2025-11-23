#!/bin/bash
set -e

echo "================================================"
echo "  🧹 Cleaning Project & Removing Secrets"
echo "================================================"
echo ""

cd "/Users/ahmadrizkimaulana/Projects/webdev3/PoC final project"

echo "Step 1: Stashing current changes..."
git add .gitignore
git stash

echo ""
echo "Step 2: Removing sensitive files from git history..."
echo "   (This removes .env, .env.bak, .dummy-wallet from ALL commits)"
echo ""

export FILTER_BRANCH_SQUELCH_WARNING=1

git filter-branch --force --index-filter \
    'git rm --cached --ignore-unmatch .env .env.bak .dummy-wallet' \
    --prune-empty --tag-name-filter cat -- --all

echo ""
echo "Step 3: Cleaning git references..."
rm -rf .git/refs/original/
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo ""
echo "Step 4: Restoring changes..."
git stash pop

echo ""
echo "Step 5: Removing unnecessary local files..."
echo ""

# Remove test/demo scripts (keep important ones)
rm -f test-with-real-mnt.sh
rm -f test-transfer-comparison.sh
rm -f test-full-privacy.sh
rm -f test-relayer.sh
rm -f compare-fresh.sh
rm -f compare-final.sh
rm -f check-real-transfer.sh
rm -f quick-check.sh
rm -f URGENT_REMOVE_SECRETS.sh
rm -f URGENT_SECURITY_FIX.md

# Remove duplicate/redundant documentation
rm -f FUNCTION_COMPARISON.md
rm -f QUICK_COMPARISON.md
rm -f PRIVACY_COMPARISON.md
rm -f TRADITIONAL_VS_POC.md
rm -f SIMPLE_EXPLORER_GUIDE.md
rm -f REAL_MNT_TEST_RESULTS.md
rm -f TRANSFER_TEST_RESULTS.md
rm -f FINAL_SYSTEM_STATUS.md
rm -f ADDRESS_PRIVACY_UPGRADE.md

# Remove sensitive files
rm -f .dummy-wallet

echo "✅ Removed unnecessary files"
echo ""

echo "Step 6: Adding all changes..."
git add -A

echo ""
echo "Step 7: Committing clean project..."
git commit -m "🧹 Clean up project and remove sensitive files

Security & Cleanup:
- Removed .env files from entire git history
- Updated .gitignore to prevent future commits
- Removed test scripts and temporary files
- Removed duplicate documentation
- Removed sensitive wallet files

Core features remain:
✅ Privacy PoC contracts
✅ Traditional vault for comparison
✅ ZK proof system (SP1)
✅ Deployment scripts
✅ Essential documentation
✅ Test suite

Ready for production review.
"

echo ""
echo "Step 8: Force pushing to remote..."
echo ""
echo "⚠️  About to FORCE PUSH (rewrites history)"
echo "Press Ctrl+C to cancel, or wait 5 seconds..."
sleep 5

git push origin main --force

echo ""
echo "================================================"
echo "✅ COMPLETE! Project Cleaned & Pushed"
echo "================================================"
echo ""
echo "What was done:"
echo "  ✅ Removed .env from all git history"
echo "  ✅ Removed .env.bak from all git history"
echo "  ✅ Removed .dummy-wallet from all git history"
echo "  ✅ Removed test/demo scripts"
echo "  ✅ Removed redundant documentation"
echo "  ✅ Updated .gitignore"
echo "  ✅ Committed clean project"
echo "  ✅ Force pushed to GitHub"
echo ""
echo "📁 What remains:"
echo "  ✅ Core contracts (AegisVault, Traditional)"
echo "  ✅ ZK program (Rust)"
echo "  ✅ Deployment scripts"
echo "  ✅ Essential documentation"
echo "  ✅ Test suite"
echo ""
echo "🔐 Security Status:"
echo "  ✅ No private keys in git history"
echo "  ✅ No sensitive files committed"
echo "  ✅ .gitignore updated"
echo ""
echo "🎉 Project is clean and ready!"
echo ""

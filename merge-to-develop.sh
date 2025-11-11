#!/bin/bash
# Script to merge the Interactive POS Screens feature to develop branch
# Run this after PR #4 has been merged to main

set -e

echo "🔄 Merging Interactive POS Screens feature to develop branch..."
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: Not in a git repository"
    exit 1
fi

# Fetch latest changes
echo "📥 Fetching latest changes from remote..."
git fetch origin

# Checkout develop branch
echo "🔀 Switching to develop branch..."
git checkout develop

# Pull latest changes
echo "⬇️  Pulling latest changes..."
git pull origin develop

# Merge the feature branch
echo "🔗 Merging feature/interactive-pos-screens-security into develop..."
git merge origin/feature/interactive-pos-screens-security -m "Merge interactive POS screens feature to develop for testing"

# Check if merge was successful
if [ $? -eq 0 ]; then
    echo "✅ Merge successful!"
    echo ""
    echo "📤 Pushing changes to remote..."
    git push origin develop
    
    echo ""
    echo "✨ Done! The Interactive POS Screens feature is now on the develop branch."
    echo ""
    echo "Next steps:"
    echo "1. Test the feature on the develop branch"
    echo "2. Verify all functionality works as expected"
    echo "3. When ready, the feature can be merged to main again (after any fixes)"
else
    echo "❌ Merge failed. Please resolve conflicts manually."
    echo ""
    echo "To resolve conflicts:"
    echo "1. Fix the conflicts in the files listed above"
    echo "2. Run: git add <resolved-files>"
    echo "3. Run: git commit"
    echo "4. Run: git push origin develop"
    exit 1
fi

#!/bin/bash
# Sync HiFiBerry with latest changes from GitHub

set -e

REPO_DIR="/data/tidal-connect-docker"
GITHUB_REPO="https://github.com/Leoname/hifiberry_tidal_clean.git"

echo "========================================"
echo "Syncing HiFiBerry with GitHub"
echo "========================================"

# Check if directory exists
if [ ! -d "$REPO_DIR" ]; then
    echo "Repository directory not found. Cloning..."
    mkdir -p "$(dirname "$REPO_DIR")"
    git clone "$GITHUB_REPO" "$REPO_DIR"
    cd "$REPO_DIR"
else
    cd "$REPO_DIR"
    
    # Check if git repo
    if [ ! -d ".git" ]; then
        echo "Not a git repository. Initializing..."
        git init
        git remote add clean "$GITHUB_REPO" 2>/dev/null || true
        git fetch clean
        git checkout -b master clean/master || git checkout master
    else
        # Update remote if needed
        if ! git remote get-url clean >/dev/null 2>&1; then
            echo "Adding clean remote..."
            git remote add clean "$GITHUB_REPO"
        else
            CURRENT_URL=$(git remote get-url clean)
            if [ "$CURRENT_URL" != "$GITHUB_REPO" ]; then
                echo "Updating clean remote URL..."
                git remote set-url clean "$GITHUB_REPO"
            fi
        fi
        
        # Fetch latest
        echo "Fetching latest changes..."
        git fetch clean
        
        # Check current branch
        CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "master")
        
        # Stash any local changes
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            echo "Warning: You have uncommitted changes. Stashing..."
            git stash
            STASHED=1
        fi
        
        # Pull latest
        echo "Pulling latest changes..."
        git pull clean master || git reset --hard clean/master
        
        # Restore stashed changes if any
        if [ "$STASHED" = "1" ]; then
            echo "Restoring stashed changes..."
            git stash pop 2>/dev/null || true
        fi
    fi
fi

# Make scripts executable
echo "Making scripts executable..."
chmod +x *.sh 2>/dev/null || true
chmod +x speaker-controller-service 2>/dev/null || true

echo ""
echo "========================================"
echo "Sync Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Review any changes: git log --oneline -5"
echo "2. If systemd service changed, update it:"
echo "   ./install-tidal-gio.sh"
echo "3. Or just restart if only scripts changed:"
echo "   ./reset-tidal-gio.sh"
echo ""


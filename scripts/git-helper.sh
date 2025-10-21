#!/bin/bash
# Git Helper for System Admin Portfolio

echo "🔄 Git Helper for System Admin Portfolio"

case $1 in
    "status")
        git status
        ;;
    "commit")
        if [ -z "$2" ]; then
            echo "Usage: $0 commit \"commit message\""
            exit 1
        fi
        git add .
        git commit -m "$2"
        ;;
    "push")
        git push origin main
        ;;
    "log")
        git log --oneline -10
        ;;
    "setup")
        echo "Setting up git configuration..."
        git config user.name "Your Name"
        git config user.email "your.email@example.com"
        git remote add origin https://github.com/username/system-admin-portfolio.git
        ;;
    *)
        echo "Usage: $0 {status|commit|push|log|setup}"
        echo "Examples:"
        echo "  $0 status"
        echo "  $0 commit \"Add new feature\""
        echo "  $0 push"
        echo "  $0 log"
        ;;
esac

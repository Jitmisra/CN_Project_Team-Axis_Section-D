#!/usr/bin/env bash
# Stop Backend B
pkill -f "python3.*backend_b.py" 2>/dev/null && echo "Backend B stopped." || echo "Backend B not running."

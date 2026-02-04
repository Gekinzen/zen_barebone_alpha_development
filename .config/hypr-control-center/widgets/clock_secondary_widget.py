#!/usr/bin/env python3
"""
Secondary Clock Widget - Dual Timezone Support
Just imports and runs the main clock widget with --secondary flag
"""
import sys
sys.argv.append("--secondary")

# Import and run from main clock
from clock_widget import main
main()
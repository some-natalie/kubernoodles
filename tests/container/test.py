#!/usr/bin/env python3

import os

print("It looks like container Actions work exactly as expected.")
print("Have a nice day!")
os.subprocess("echo '- ✅ container action succeeded' >> $GITHUB_STEP_SUMMARY")

#!/usr/bin/env python3

import sys
import string

template_file = sys.argv[1]
git_repo = sys.argv[2]
ros_version = sys.argv[3]

print(string.Template(open(template_file).read()).substitute(git_repo=git_repo, ros_version=ros_version))


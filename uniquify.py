#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import fileinput

seen_lines = set()
for line in fileinput.input():
  line = line.strip()
  if line not in seen_lines:
    seen_lines.add(line)
    print line

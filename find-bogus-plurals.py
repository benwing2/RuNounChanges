#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import fileinput
import re

for line in fileinput.input():
  if re.search(r"plural أَ.ْ.َات", line):
    print(line)

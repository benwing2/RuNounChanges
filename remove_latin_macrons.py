#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import blib
from blib import msg
import sys
import lalib

parser = blib.create_argparser("Remove Latin macrons from input", no_beginning_line=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for index, line in blib.iter_items(sys.stdin, start, end):
  line = line.strip()
  msg(lalib.remove_macrons(line))

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser("Delete subcats of [[Category:Swedish compound words]]")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, cat_page in blib.cat_subcats("Swedish compound words", start, end):
  cat_page.delete("Remove empty category after orphaning of {{sv-compound}}")

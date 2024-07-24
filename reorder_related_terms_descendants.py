#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  secbody, sectail = blib.force_two_newlines_in_secbody(text, "")
  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  while True:
    # Look for a participle and move it up.
    for k in range(2, len(subsections), 2):
      m = re.search(r"^(===+)Descendants\1$", subsections[k - 1])
      if m:
        desc_indent = len(m.group(1))
        if k < len(subsections) - 2 and re.search(
            "^%sRelated terms%s$" % ("="*desc_indent, "="*desc_indent), subsections[k + 1]):
          desc_text = subsections[k - 1:k + 1]
          subsections[k - 1:k + 1] = subsections[k + 1:k + 3]
          subsections[k + 1:k + 3] = desc_text
          notes.append("reorder ==Descendants== and ==Related terms== so ==Descendants== goes below")
          break

    else: # no break
      break

    continue

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  text = secbody.rstrip("\n") + sectail

  return text, notes

parser = blib.create_argparser("Reorder ==Descendants== after ==Related terms==",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

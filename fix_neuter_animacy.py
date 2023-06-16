#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, fix_indeclinable):
  pagetitle = str(page.title())
  subpagetitle = re.sub(".*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping")
    return

  notes = []
  text = str(page.text)
  parsed = blib.parse(page)

  def frob_gender_param(t, param):
    val = getparam(t, param)
    if val == "n":
      t.add(param, "n-in")
    elif val == "n-p":
      t.add(param, "n-in-p")

  for t in parsed.filter_templates():
    if str(t.name) in ["ru-noun", "ru-proper noun"]:
      origt = str(t)
      frob_gender_param(t, "2")
      i = 2
      while True:
        if getparam(t, "g" + str(i)):
          frob_gender_param(t, "g" + str(i))
          i += 1
        else:
          break
      if origt != str(t):
        param3 = getparam(t, "3")
        if param3 != "-":
          if fix_indeclinable:
            if param3:
              pagemsg("WARNING: Can't make indeclinable, has genitive singular given: %s" % origt)
              return
            else:
              t.add("3", "-")
              notes.append("make indeclinable")
              pagemsg("Making indeclinable: %s" % str(t))
          else:
            pagemsg("WARNING: Would add inanimacy to neuter, but isn't marked as indeclinable: %s" % origt)
            return
        pagemsg("Replacing %s with %s" % (origt, str(t)))

  if notes:
    comment = "Add inanimacy to neuters (%s)" % "; ".join(notes)
  else:
    comment = "Add inanimacy to neuters"

  return str(parsed), comment

parser = blib.create_argparser("Make neuter nouns be inanimate",
  include_pagefile=True)
parser.add_argument("--fix-indeclinable", action="store_true",
    help="Make non-indeclinables be indeclinable")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def do_process_page(page, index, parsed):
  return process_page(index, page, args.fix_indeclinable)

blib.do_pagefile_cats_refs(args, start, end, do_process_page, edit=True,
  default_refs=["Template:ru-noun", "Template:ru-proper noun"])

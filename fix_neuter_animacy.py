#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose, fix_indeclinable):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub(".*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping")
    return

  notes = []
  text = unicode(page.text)
  parsed = blib.parse(page)

  def frob_gender_param(t, param):
    val = getparam(t, param)
    if val == "n":
      t.add(param, "n-in")
    elif val == "n-p":
      t.add(param, "n-in-p")

  for t in parsed.filter_templates():
    if unicode(t.name) in ["ru-noun", "ru-proper noun"]:
      origt = unicode(t)
      frob_gender_param(t, "2")
      i = 2
      while True:
        if getparam(t, "g" + str(i)):
          frob_gender_param(t, "g" + str(i))
          i += 1
        else:
          break
      if origt != unicode(t):
        param3 = getparam(t, "3")
        if param3 != "-":
          if fix_indeclinable:
            if param3:
              pagemsg("WARNING: Can't make indeclinable, has genitive singular given: %s" % origt)
              return
            else:
              t.add("3", "-")
              notes.append("make indeclinable")
              pagemsg("Making indeclinable: %s" % unicode(t))
          else:
            pagemsg("WARNING: Would add inanimacy to neuter, but isn't marked as indeclinable: %s" % origt)
            return
        pagemsg("Replacing %s with %s" % (origt, unicode(t)))

  new_text = unicode(parsed)

  if new_text != text:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, new_text))
    if notes:
      comment = "Add inanimacy to neuters (%s)" % "; ".join(notes)
    else:
      comment = "Add inanimacy to neuters"
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = new_text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser("Make neuter nouns be inanimate")
parser.add_argument("--fix-indeclinable", action="store_true",
    help="Make non-indeclinables be indeclinable")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for i, page in blib.references("Template:ru-noun", start, end):
  process_page(i, page, args.save, args.verbose, args.fix_indeclinable)
for i, page in blib.references("Template:ru-proper noun", start, end):
  process_page(i, page, args.save, args.verbose, args.fix_indeclinable)

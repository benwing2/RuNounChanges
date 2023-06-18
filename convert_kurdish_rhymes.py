#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errandmsg, site, tname

def process_page_for_rename(page, index):
  pagename = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  global args

  totitle = pagename.replace(":Kurdish", ":Northern Kurdish")
  comment = "Rename Rhymes:Kurdish/... -> Rhymes:Northern Kurdish/..."
  if args.save:
    try:
      page.move(totitle, reason=comment, movetalk=True, noredirect=True)
      errandpagemsg("Renamed to %s" % totitle)
    except pywikibot.PageRelatedError as error:
      errandpagemsg("Error moving to %s: %s" % (totitle, error))
      return
  else:
    errandpagemsg("Would move '%s' to '%s': comment=%s" % (pagename, totitle, comment))


def process_page_for_fix(page, index, parsed):
  pagename = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  text = str(page.text)

  newtext = re.sub(r"\[\[(.*?)\]\]", r"{{l|kmr|\1}}", text)
  if newtext != text:
    notes.append("convert raw links to {{l|kmr|...}}")
    text = newtext

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in ["l", "rhymes nav"] and getparam(t, "1") == "ku":
      t.add("1", "kmr")
      notes.append("convert {{%s|ku}} to {{%s|kmr}}" % (tn, tn))
    elif getparam(t, "1") == "ku":
      pagemsg("WARNING: Kurdish-language template of unrecognized name: %s" % str(t))
    if origt != str(t):
      pagemsg("Replaced %s with %s" % (origt, str(t)))
  text = str(parsed)

  return text, notes

parser = blib.create_argparser("Move 'Kurdish' rhymes page to Northern Kurdish", include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page_for_rename, default_cats=["Kurdish rhymes"])
blib.do_pagefile_cats_refs(args, start, end, process_page_for_fix, default_cats=["Kurdish rhymes"], edit=True)

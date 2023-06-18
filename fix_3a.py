#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def process_page(index, page, direc, delete_bad, verbose):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("WARNING: Script no longer applies and would need fixing up")
  return

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  pagemsg("Processing")

  text = str(page.text)
  parsed = blib.parse(page)
  notes = []
  direc = direc.replace("3oa", "3°a")
  for t in parsed.filter_templates():
    origt = str(t)
    if str(t.name) in ["ru-conj"]:
      conjtype = getparam(t, "1")
      if not conjtype.startswith("3olda"):
        continue
      if conjtype.startswith("3olda") and conjtype != "3olda":
        pagemsg("WARNING: Found 3a-old with variant, can't process: %s" % str(t))
        continue
      tempcall = re.sub(r"\{\{ru-conj", "{{ru-generate-verb-forms", str(t))
      result = expand_text(tempcall)
      if not result:
        pagemsg("WARNING: Error generating forms, skipping")
        continue
      oldargs = blib.split_generate_args(result)
      rmparam(t, "6")
      rmparam(t, "5")
      rmparam(t, "4")
      t.add("1", direc)
      tempcall = re.sub(r"\{\{ru-conj", "{{ru-generate-verb-forms", str(t))
      result = expand_text(tempcall)
      if not result:
        pagemsg("WARNING: Error generating forms, skipping")
        continue
      if delete_bad:
        newargs = blib.split_generate_args(result)
        for form in ["past_m", "past_f", "past_n", "past_pl", "past_m_short",
            "past_f_short", "past_n_short", "past_pl_short"]:
          oldforms = re.split(",", oldargs[form]) if form in oldargs else []
          newforms = re.split(",", newargs[form]) if form in newargs else []
          for oldform in oldforms:
            if oldform not in newforms:
              formpagename = rulib.remove_accents(oldform)
              formpage = pywikibot.Page(site, formpagename)
              if not formpage.exists():
                pagemsg("WARNING: Form page %s doesn't exist, skipping" % formpagename)
              elif formpagename == pagetitle:
                pagemsg("WARNING: Attempt to delete dictionary form, skipping")
              else:
                text = str(formpage.text)
                if "Etymology 1" in text:
                  pagemsg("WARNING: Found 'Etymology 1', skipping form %s" % formpagename)
                elif "----" in text:
                  pagemsg("WARNING: Multiple languages apparently in form, skippin form %s" % formpagename)
                else:
                  numinfls = len(re.findall(r"\{\{inflection of\|", text))
                  if numinfls < 1:
                    pagemsg("WARNING: Something wrong, no 'inflection of' templates on page for form %s" % formpagename)
                  elif numinfls > 1:
                    pagemsg("WARNING: Multiple 'inflection of' templates on page for form %s, skipping" % formpagename)
                  else:
                    comment = "Delete erroneously created long form of %s" % pagetitle
                    pagemsg("Existing text for form %s: [[%s]]" % (
                      formpagename, text))
                    if save:
                      formpage.delete(comment)
                    else:
                      pagemsg("Would delete page %s with comment=%s" %
                          (formpagename, comment))

      notes.append("fix 3olda -> %s" % direc)
    newt = str(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return str(parsed), notes

parser = blib.create_argparser("Fix up class 3a")
parser.add_argument('--direcfile', help="File containing pages to fix and directives.")
parser.add_argument('--delete-bad', action="store_true", help="Delete bad forms.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, line in blib.iter_items_from_file(args.direcfile, start, end):
  page, direc = re.split(" ", line)
  def do_process_page(page, index, parsed):
    return process_page(index, page, direc, args.delete_bad, args.verbose)
  blib.do_edit(pywikibot.Page(site, page), i, do_process_page, save=args.save,
    verbose=args.verbose, diff=args.diff)

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse, copy

import blib
from blib import getparam, rmparam, tname, msg, errmsg, site

def process_page(page, index, parsed):
  global args
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []
  for t in parsed.filter_templates():
    origt = str(t)
    if tname(t) in ["ru-conj", "ru-conj-old"]:
      if [x for x in t.params if str(x.value) == "or"]:
        errpagemsg("WARNING: Skipping multi-arg conjugation: %s" % str(t))
        continue
      param2 = getparam(t, "2")
      if "*" in param2:
        continue
      param3 = getparam(t, "3")
      param4 = getparam(t, "4")
      if not param4:
        continue
      if getparam(t, "5"):
        t.add("4", "")
      else:
        rmparam(t, "4")
      if re.search(u"^(во|взо|изо|обо|ото|подо|разо|со)", param4):
        param2 = re.sub("^([0-9]+)", r"\1*", param2)
        t.add("2", param2)
        notes.append("Replaced manual pres/futr stem with * variant")
      else:
        notes.append("Removed unnecessary manual pres/futr stem")
      if tname(t) == "ru-conj":
        new_tempcall = re.sub(r"^\{\{ru-conj", "{{ru-generate-verb-forms", str(t))
      else:
        new_tempcall = re.sub(r"^\{\{ru-conj-old", "{{ru-generate-verb-forms|old=1", str(t))
      result = expand_text(new_tempcall)
      if not result:
        errpagemsg("WARNING: Error expanding new template %s" % new_tempcall)
        return None, ""
      new_forms = blib.split_generate_args(result)
      if tname(t) == "ru-conj":
        orig_tempcall = re.sub(r"^\{\{ru-conj", "{{ru-generate-verb-forms", origt)
      else:
        orig_tempcall = re.sub(r"^\{\{ru-conj-old", "{{ru-generate-verb-forms|old=1", origt)
      result = expand_text(orig_tempcall)
      if not result:
        errpagemsg("WARNING: Error expanding original template %s" % orig_tempcall)
        return None, ""
      orig_forms = blib.split_generate_args(result)

      # Compare each form and accumulate a list of mismatches.

      all_keys = set(orig_forms.keys()) | set(new_forms.keys())
      def sort_numbers_first(key):
        if re.search("^[0-9]+$", key):
          return "%05d" % int(key)
        return key
      all_keys = sorted(list(all_keys), key=sort_numbers_first)
      mismatches = []
      for key in all_keys:
        origval = orig_forms.get(key, "<<missing>>")
        newval = new_forms.get(key, "<<missing>>")
        if origval != newval:
          mismatches.append("%s: old=%s new=%s" % (key, origval, newval))

      # If mismatches, output them and don't change anything.

      if mismatches:
        errpagemsg("WARNING: Mismatch comparing old %s to new %s: %s" % (
          orig_tempcall, new_tempcall, " || ".join(mismatches)))
        return None, ""

    newt = str(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return parsed, notes

parser = blib.create_argparser(u"Add * to 9b and 11b verbs as needed")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in ["Russian class 9b verbs", "Russian class 11b verbs"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)

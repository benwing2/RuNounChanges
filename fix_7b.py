#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def process_page(index, page, direc):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("WARNING: Script no longer applies and would need fixing up")
  return

  pagemsg("Processing")

  text = str(page.text)
  parsed = blib.parse(page)
  notes = []
  origdirec = direc
  for t in parsed.filter_templates():
    origt = str(t)
    direc = origdirec
    if str(t.name) in ["ru-conj-7b"]:
      rmparam(t, "past_m")
      rmparam(t, "past_f")
      rmparam(t, "past_n")
      rmparam(t, "past_pl")
      rmparam(t, "notes")
      rmparam(t, "past_adv_part")
      rmparam(t, "past_adv_part2")
      rmparam(t, "past_adv_part_short")
      #ppps = blib.fetch_param_chain(t, "past_pasv_part", "past_pasv_part")
      #blib.remove_param_chain(t, "past_pasv_part", "past_pasv_part")
      presstem = getparam(t, "3")
      rmparam(t, "5")
      rmparam(t, "4")
      rmparam(t, "3")
      npp = "npp" in direc
      direc = direc.replace("npp", "")
      yo = u"ё" in direc
      direc = direc.replace(u"ё", "")
      direc = re.sub("7b/?", "", direc)
      if re.search(u"е́?[^аэыоуяеиёю]*$", presstem):
        if not yo:
          pagemsg(u"Something wrong, е-stem present and no ё directive")
        if npp:
          presstem = rulib.make_ending_stressed_ru(presstem)
        else:
          presstem = re.sub(u"е́?([^аэыоуяеиёю]*)$", r"ё\1", presstem)
      else:
        presstem = rulib.make_ending_stressed_ru(presstem)
      pap = getparam(t, "past_actv_part")
      pred_pap = presstem + u"ший"
      if direc not in ["b", "b(9)"] and re.search(u"[дт]$", presstem):
        pred_pap = re.sub(u"[дт]$", "", presstem) + u"вший"
      if pap:
        if pap == pred_pap:
          pagemsg("Removing past_actv_part=%s because same as predicted" % pap)
          rmparam(t, "past_actv_part")
        else:
          pagemsg("Not removing unpredictable past_actv_part=%s (predicted %s)" %
              (pap, pred_pap))
      for param in t.params:
        if not re.search("^([0-9]+$|past_pasv_part)", str(param.name)):
          pagemsg("Found additional named param %s" % str(param))
      t.add("3", presstem)
      if direc:
        t.add("4", "")
        t.add("5", direc)
      blib.sort_params(t)
      #blib.set_param_chain(t, ppps, "past_pasv_part", "past_pasv_part")
      notes.append("set class-7b verb to directive %s%s" %
          (direc, npp and u" (no ё in present stem)" or ""))
    newt = str(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return str(parsed), notes

parser = blib.create_argparser(u"Fix up class-7b arguments")
parser.add_argument('--direcfile', help="File containing pages to fix and directives.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, line in blib.iter_items_from_file(args.direcfile, start, end):
  if " " not in line:
    msg("Line %s: Skipping because no space: %s" % (i, line))
  elif "7b" not in line:
    msg("Line %s: Skipping because 7b not in line: %s" % (i, line))
  else:
    page, direc = re.split(" ", line)
    def do_process_page(page, index, parsed):
      return process_page(index, page, direc)
    blib.do_edit(pywikibot.Page(site, page), i, do_process_page, save=args.save,
      verbose=args.verbose, diff=args.diff)

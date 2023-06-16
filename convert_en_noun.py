#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def pluralize(noun):
  if re.search("([sxz]|[cs]h)$", noun):
    return noun + "es"
  if re.search("[^aeiou]y$", noun):
    return noun[:-1] + "ies"
  return noun + "s"

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if "en-noun" not in text:
    return

  parsed = blib.parse_text(text)

  num_would_save_even_with_s_or_es = 0
  num_would_save_even_with_s = 0
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "en-noun":
      origt = str(t)
      if getparam(t, "new"):
        pagemsg("Template has new=%s, not touching: %s" % (getparam(t, "new"), str(t)))
        continue
      saw_plural = False
      orig_plurals = []
      plurals = []
      default_plural = pluralize(pagetitle)
      no_default_plural = getparam(t, "1") in ["?", "!", "-"]
      has_plqual = False
      for i in range(1, 30):
        if getparam(t, "pl%squal" % i) or getparam(t, "plqual"):
          has_plqual = True
        plparam = getparam(t, str(i))
        if i == 1 and plparam in ["?", "!", "-", "~"]:
          # not a plural
          continue
        if not plparam:
          continue
        saw_plural = True
        orig_plurals.append(plparam)
        if plparam in ["s", "es"]:
          plural = pagetitle + plparam
        else:
          plural = plparam
        if default_plural == plural:
          t.add(str(i), "+")
          plurals.append("+")
        else:
          plurals.append(plparam)
      assert (not not saw_plural) == (not not plurals)
      if not saw_plural and not no_default_plural:
        par1 = getparam(t, "1")
        if par1 == "~":
          newparam = "2"
        else:
          newparam = "1"
        plparam = "s"
        plural = pagetitle + "s"
        if plural == default_plural:
          plparam = "+"
        else:
          pagemsg("WARNING: Saw {{en-noun}} without explicit plural and new default plural %s different from old default plural %s: %s" %
            (default_plural, plural, str(t)))
        t.add(newparam, plparam)
        plurals.append(plparam)
      if not no_default_plural and plurals == ["+"]:
        if has_plqual:
          pagemsg("WARNING: Plurals are only '+' but plqual= present, not removing: %s" % str(t))
        else:
          if getparam(t, "1") == "~":
            firstparam = 2
          else:
            firstparam = 1
          for i in range(firstparam, 30):
            rmparam(t, str(i))
          plurals = []
      if args.prefer_s:
        for i in range(1, 30):
          if default_plural == pagetitle + "s" and getparam(t, str(i)) == "+":
            t.add(str(i), "s")
      if str(t) != origt:
        #t.add("new", "1")
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("convert {{en-noun}} to new form with smarter default plural algorithm")
        plurals_with_s = []
        plurals_with_s_and_es = []
        for plural in plurals:
          if plural == "+":
            if default_plural == pagetitle + "s":
              plurals_with_s.append("s")
              plurals_with_s_and_es.append("s")
            elif default_plural == pagetitle + "es":
              plurals_with_s.append("+")
              plurals_with_s_and_es.append("es")
            else:
              plurals_with_s.append("+")
              plurals_with_s_and_es.append("+")
          else:
            plurals_with_s.append(plural)
            plurals_with_s_and_es.append(plural)
        if plurals_with_s_and_es == orig_plurals:
          pagemsg("No changes if '+' is replaced with 's' or 'es' as appropriate: orig=%s, new=%s" % (origt, str(t)))
        else:
          num_would_save_even_with_s_or_es += 1
        if plurals_with_s == orig_plurals:
          pagemsg("No changes if '+' is replaced with 's' as appropriate: orig=%s, new=%s" % (origt, str(t)))
        else:
          num_would_save_even_with_s += 1

  if notes:
    pagemsg("Would save if '+' is always kept")
  else:
    pagemsg("Would not save")
  if num_would_save_even_with_s > 0:
    pagemsg("Would save even if '+' is replaced with 's' as appropriate")
  if num_would_save_even_with_s_or_es > 0:
    pagemsg("Would save even if '+' is replaced with 's' or 'es' as appropriate")
  return str(parsed), notes

parser = blib.create_argparser("Convert {{en-noun}} plurals to new format",
  include_pagefile=True, include_stdin=True)
parser.add_argument('--prefer-s', help="Prefer 's' over '+'", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:en-noun"])

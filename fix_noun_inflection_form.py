#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Fix up noun forms when possible, canonicalizing existing 'inflection of'.
# In particular, we convert 'prep' to 'pre', shorten full forms to
# abbreviations, put lang=ru first, remove blank form codes, and rearrange
# form codes like s|gen to be gen|s.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping page")
    return

  text = str(page.text)
  notes = []

  foundrussian = False
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in range(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections, skipping page")
        return
      foundrussian = True

      # Remove blank form codes and canonicalize position of lang=, tr=
      parsed = blib.parse_text(sections[j])
      for t in parsed.filter_templates():
        if str(t.name) == "inflection of" and getparam(t, "lang") == "ru":
          origt = str(t)
          # Fetch the numbered params starting with 3, skipping blank ones
          numbered_params = []
          for i in range(3,20):
            val = getparam(t, str(i))
            if val:
              numbered_params.append(val)
          # Fetch param 1 and param 2, and non-numbered params except lang=
          # and nocat=.
          param1 = getparam(t, "1")
          param2 = getparam(t, "2")
          tr = getparam(t, "tr")
          nocat = getparam(t, "nocat")
          non_numbered_params = []
          for param in t.params:
            pname = str(param.name)
            if not re.search(r"^[0-9]+$", pname) and pname not in ["lang", "nocat", "tr"]:
              non_numbered_params.append((pname, param.value))
          # Erase all params.
          del t.params[:]
          # Put back lang, param 1, tr, param 2, then the replacements for the
          # higher numbered params, then the non-numbered params.
          t.add("lang", "ru")
          t.add("1", param1)
          if tr:
            t.add("tr", tr)
          t.add("2", param2)
          for i, param in enumerate(numbered_params):
            t.add(str(i+3), param)
          for name, value in non_numbered_params:
            t.add(name, value)
          newt = str(t)
          if origt != newt:
            pagemsg("Replaced %s with %s" % (origt, newt))
            notes.append("removed any blank form codes and maybe rearranged lang=, tr=")
            if nocat:
              notes.append("removed nocat=")
      sections[j] = str(parsed)

      # Convert 'prep' to 'pre', etc.
      parsed = blib.parse_text(sections[j])
      for t in parsed.filter_templates():
        if str(t.name) == "inflection of" and getparam(t, "lang") == "ru":
          for frm, to in [
              ("nominative", "nom"), ("accusative", "acc"),
              ("genitive", "gen"), ("dative", "dat"),
              ("instrumental", "ins"),
              ("prep", "pre"), ("prepositional", "pre"),
              ("vocative", "voc"), ("locative", "loc"), ("partitive", "par"),
              ("singular", "s"), ("(singular)", "s"),
              ("plural", "p"), ("(plural)", "p"),
              ("inanimate", "in"), ("animate", "an"),
              ]:
            origt = str(t)
            for i in range(3,20):
              val = getparam(t, str(i))
              if val == frm:
                t.add(str(i), to)
            newt = str(t)
            if origt != newt:
              pagemsg("Replaced %s with %s" % (origt, newt))
              notes.append("converted '%s' form code to '%s'" % (frm, to))
      sections[j] = str(parsed)

      # Rearrange order of s|gen, p|nom etc. to gen|s, nom|p etc.
      parsed = blib.parse_text(sections[j])
      for t in parsed.filter_templates():
        if str(t.name) == "inflection of" and getparam(t, "lang") == "ru":
          if (getparam(t, "3") in ["s", "p"] and
              getparam(t, "4") in ["nom", "gen", "dat", "acc", "ins", "pre", "voc", "loc", "par"] and
              not getparam(t, "5")):
            origt = str(t)
            number = getparam(t, "3")
            case = getparam(t, "4")
            t.add("3", case)
            t.add("4", number)
            newt = str(t)
            if origt != newt:
              pagemsg("Replaced %s with %s" % (origt, newt))
              notes.append("converted '%s|%s' to '%s|%s'" %
                  (number, case, case, number))
      sections[j] = str(parsed)

  return "".join(sections), notes

parser = blib.create_argparser("Canonicalize 'inflection of' for noun forms",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian noun forms"])

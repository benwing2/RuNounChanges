#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# This script modifies Proto-Slavic pages containing links to Slovene words
# to contain the tonal version of the word by looking it up in the entry.
import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

GRAVE     = u"\u0300"
ACUTE     = u"\u0301"
CIRC      = u"\u0302"
TILDE     = u"\u0303"
MACRON    = u"\u0304"
BREVE     = u"\u0306"
DOTABOVE  = u"\u0307"
DIAER     = u"\u0308"
CARON     = u"\u030C"
DGRAVE    = u"\u030F"
INVBREVE  = u"\u0311"
DOTBELOW  = u"\u0323"
RINGBELOW = u"\u0325"
CEDILLA   = u"\u0327"
OGONEK    = u"\u0328"

skip_pages = [u"Reconstruction:Proto-Slavic/mělь",
    u"Reconstruction:Proto-Slavic/pazъ"]

def remove_slovene_accents(lemma):
  lemma = re.sub(u"[ÁÀÂȂȀ]", "A", lemma)
  lemma = re.sub(u"[áàâȃȁ]", "a", lemma)
  lemma = re.sub(u"[ÉÈÊȆȄỆẸĘ]",  "E", lemma)
  lemma = re.sub(u"[éèêȇȅệẹęə]",  "e", lemma)
  lemma = re.sub(u"[ÍÌÎȊȈ]", "I", lemma)
  lemma = re.sub(u"[íìîȋȉ]", "i", lemma)
  lemma = re.sub(u"[ÓÒÔȎȌỘỌǪ]", "O", lemma)
  lemma = re.sub(u"[óòôȏȍộọǫ]", "o", lemma)
  lemma = re.sub(u"[ŔȒȐ]", "R", lemma)
  lemma = re.sub(u"[ŕȓȑ]", "r", lemma)
  lemma = re.sub(u"[ÚÙÛȖȔ]", "U", lemma)
  lemma = re.sub(u"[úùûȗȕ]", "u", lemma)
  lemma = re.sub(u"ł", "l", lemma)
  lemma = re.sub(GRAVE, "", lemma)
  lemma = re.sub(ACUTE, "", lemma)
  lemma = re.sub(DGRAVE, "", lemma)
  lemma = re.sub(INVBREVE, "", lemma)
  lemma = re.sub(CIRC, "", lemma)
  lemma = re.sub(DOTBELOW, "", lemma)
  lemma = re.sub(OGONEK, "", lemma)
  return lemma

def look_up_tonal_form(pagename, pagemsg, verbose):
  try:
    page = pywikibot.Page(site, pagename)
  except Exception as e:
    pagemsg("WARNING: Error looking up page %s: %s" % (pagename,
      str(e)))
    return None
  try:
    if not page.exists():
      if verbose:
        pagemsg("look_up_tonal_form: Page %s doesn't exist" % pagename)
      return None
  except Exception as e:
    pagemsg("WARNING: Error checking page existence for %s: %s" % (pagename,
      str(e)))
    return None
  tonal_forms = []
  for t in blib.parse(page).filter_templates():
    if str(t.name) == "sl-tonal":
      if verbose:
        pagemsg("look_up_tonal_form: For page %s, found tonal template %s" %
            (pagename, str(t)))
      if tonal_forms:
        pagemsg("WARNING: Found multiple {{sl-tonal}} calls for page %s: new one is %s; can't handle" % (pagename,
          str(t)))
        return None
      tonal_forms.append(getparam(t, "1"))
      for param in ["2", "3", "4", "5", "6"]:
        if getparam(t, param):
          tonal_forms.append(getparam(t, param))
  return tonal_forms

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if pagetitle in skip_pages:
    pagemsg("Skipping because in skip list")
    return

  pagemsg("Processing")

  text = str(page.text)
  notes = []
  parsed = blib.parse(page)
  saw_sl_tonal = False
  saw_sl_plain = 0
  for t in parsed.filter_templates():
    # In case we already substituted multiple tonal variants, the first
    # one will have {{l|sl|...}} and we'll try to replace it again unless
    # we have this check.
    if str(t.name) == "l/sl-tonal":
      pagemsg("Already found %s, not replacing anything" % str(t))
      saw_sl_tonal = True
    if str(t.name) == "l" and getparam(t, "1") == "sl":
      saw_sl_plain += 1
  if saw_sl_plain and saw_sl_tonal:
    pagemsg("WARNING: Saw both {{l|sl|...}} and {{l/sl-tonal|...}}, needs fixing")
  if saw_sl_plain > 1:
    pagemsg("WARNING: Saw multiple {{l|sl|...}}, check if substitution is correct")
  if saw_sl_tonal:
    return

  # The repeating while loop was used previously for handling multiple
  # variants, where the template had to be replaced with multiple templates
  # by substituting into the raw page text, and then we had to restart
  # template processing so the substitution didn't disappear.
  repeat = True
  while repeat:
    parsed = blib.parse(page)
    for t in parsed.filter_templates():
      origt = str(t)
      if str(t.name) in ["l"] and getparam(t, "1") == "sl":
        linkpage = getparam(t, "2")
        altlink = getparam(t, "3")
        defn = getparam(t, "4")
        gloss = getparam(t, "gloss")
        tgloss = getparam(t, "t")
        gender = getparam(t, "g")
        gender2 = getparam(t, "g2")
        if (defn and 1 or 0) + (gloss and 1 or 0) + (tgloss and 1 or 0) > 1:
          pagemsg("WARNING: Found more than one of defn=%s, gloss=%s, t=%s in %s, skipping"
              % (defn, gloss, tgloss, str(t)))
          continue
        defn = defn or gloss or tgloss
        if altlink:
          if remove_slovene_accents(linkpage) != remove_slovene_accents(altlink):
            pagemsg("WARNING: Template %s has both link and altlink and they don't point to the same page skipping" %
                str(t))
            continue
          linkpage = altlink
        for param in t.params:
          pname = str(param.name)
          if pname not in ["1", "2", "3", "4", "gloss", "t", "g", "g2", "pos"]:
            pagemsg("WARNING: Found unexpected param %s in %s, skipping" %
                (pname, str(t)))
            break
        else:
          tonal_forms = look_up_tonal_form(remove_slovene_accents(linkpage),
              pagemsg, verbose)
          if tonal_forms:
            if False: #len(tonal_forms) > 1:
              pass
              # This code was formerly used when {{l/sl-tonal}} didn't
              # support multiple alternants, and used {{l|sl|...}} on all
              # alternants but the final one.

              #non_final_forms = tonal_forms[:-1]
              #final_form = tonal_forms[-1]
              #newsub = "%s, {{l/sl-tonal|%s%s%s%s}}" % (
              #    ", ".join("{{l-REPLACEME|sl|%s}}" % x for x in non_final_forms),
              #    final_form, "|gloss=%s" % defn if defn else "",
              #    "|g=%s" % gender if gender else "",
              #    "|g2=%s" % gender2 if gender2 else "")
              #eventual_newsub = newsub.replace("{{l-REPLACEME|", "{{l|")
              #fromsub = str(t)
              #fromtext = str(parsed)
              #newtext = fromtext.replace(fromsub, newsub)
              #if newtext == fromtext:
              #  pagemsg("WARNING: Something wrong, can't locate template %s in text"
              #      % fromsub)
              #else:
              #  pagemsg("Replaced %s with %s (multiple tonal variants)" % (fromsub, eventual_newsub))
              #  if len(newtext) - len(fromtext) != len(newsub) - len(fromsub):
              #    pagemsg("WARNING: Length mismatch when replacing multiple tonal variants, may have matched multiple templates: from=%s, to=%s" % (
              #      fromsub, newsub))
              #  notes.append("replaced Slovene %s with multi tonal variants %s" % (linkpage, ",".join(tonal_forms)))
              #  page.text = newtext
              #  break
            else:
              t.name = "l/sl-tonal"
              rmparam(t, "2")
              rmparam(t, "3")
              rmparam(t, "4")
              for i, form in enumerate(tonal_forms):
                t.add(str(i+1), form)
              rmparam(t, "t")
              if defn:
                t.add("gloss", defn)
              else:
                rmparam(t, "gloss")
              notes.append("replaced Slovene %s with tonal %s" % (linkpage,
                ", ".join(tonal_forms)))
      newt = str(t)
      if origt != newt:
        pagemsg("Replaced %s with %s" % (origt, newt))
    else:
      repeat = False

  return str(parsed).replace("{{l-REPLACEME|", "{{l|"), notes

parser = blib.create_argparser(u"Convert Slovene links in Proto-Slavic pages to tonal form",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Proto-Slavic lemmas"])

#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def base_default_verb_forms(verb):
  vowel = u"aeiouáéíóúàèìòùâêîôûäëïöüæœø"
  ulvowel = vowel + u"AEIOUÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÄËÏÖÜÆŒØ"
  
  if re.search("([sxz]|[cs]h)$", verb):
    s_form = verb + "es"
  elif re.search("[^aeiou]y$", verb):
    s_form = verb[:-1] + "ies"
  else:
    s_form = verb + "s"

  # (1) Check for C*VC verbs.
  #
  # flip -> flipping/flipped, strum -> strumming/strummed, nag -> nagging/nagged, etc.
  # Do not include words with final -y, e.g. 'stay' (staying/stayed), 'toy' (toying/toyed),
  # or with final -w, e.g. 'flow' (flowing/flowed), or with final -h, e.g. 'ah' (ahing/ahed),
  # or with final -x, e.g. 'box' (boxing/boxed), or ending in an uppercase consonant,
  # e.g. 'XOR' (XORing/XORed), 'OK' (OKing/OKed). Check specially for initial y- as a consonant,
  # e.g. 'yip' (yipping/yipped), otherwise treat y as a vowel, so we don't trigger on 'hyphen'
  # but do trigger on 'gyp'.
  m = re.search("^[Yy][" + vowel + "y]([^A-Z" + vowel + "ywxh])$", verb)
  if not m:
    m = re.search("^[^" + ulvowel + "yY]*[" + ulvowel + "yY]([^A-Z" + vowel + "ywxh])$", verb)
  if m:
    last_cons = m.group(1)
    ing_form = verb + last_cons + "ing"
    ed_form = verb + last_cons + "ed"
  else:
    # (2) Generate -ing form.
    # (2a) lie -> lying, untie -> untying, etc.
    m = re.search("^(.*)ie$", verb)
    if m:
      ing_form = m.group(1) + "ying"
    else:
      # (2b) argue -> arguing, sprue -> spruing, dialogue -> dialoguing, etc.
      m = re.search("^(.*)ue$", verb)
      if m:
        ing_form = m.group(1) + "uing"
      else:
        m = re.search("^(.*[" + ulvowel + "yY][^" + vowel + "y]+)e$", verb)
        if m:
          # (2c) baptize -> baptizing, rake -> raking, type -> typing, parse -> parsing, etc.
          # (ending in vowel + consonant(s) + -e); also argue -> arguing, devalue -> devaluing, etc.
          # (ending in vowel + optional consonant(s) + -ue); but not referee -> refereeing,
          # backhoe -> backhoeing, redye -> redyeing (ending in some other vowel + -e or in -ye);
          # and not be -> being (no vowel before the consonant preceding the -e)
          ing_form = m.group(1) + "ing"
        else:
          # (2d) regular verbs
          ing_form = verb + "ing"

    # (3) Generate -ed form.
    if verb.endswith("e"):
      # (3a) baptize -> baptized, rake -> raked, parse -> parsed, free -> freed, hoe -> hoed
      ed_form = verb + "d"
    else:
      m = re.search("^(.*[^" + ulvowel + "yY])y$", verb)
      if m:
        # (3b) marry -> married, levy -> levied, try -> tried, etc.; but not toy -> toyed
        ed_form = m.group(1) + "ied"
      else:
        # (3c) regular verbs
        ed_form = verb + "ed"

  return s_form, ing_form, ed_form

def default_verb_forms(verb):
  full_s_form, full_ing_form, full_ed_form = base_default_verb_forms(verb)
  if " " in verb:
    m = re.search("^(.*?)( .*)$", verb)
    first, rest = m.groups()
    first_s_form, first_ing_form, first_ed_form = base_default_verb_forms(first)
    return full_s_form, full_ing_form, full_ed_form, first_s_form + rest, first_ing_form + rest, first_ed_form + rest
  else:
    return full_s_form, full_ing_form, full_ed_form, None, None, None

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if "en-verb" not in text:
    return

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace title")
    return

  parsed = blib.parse_text(text)

  num_would_convert = 0
  num_would_not_convert = 0
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "en-verb":
      origt = unicode(t)
      if getparam(t, "new"):
        pagemsg("Template has new=%s, not touching: %s" % (getparam(t, "new"), unicode(t)))
        continue
      pagename = getparam(t, "pagename") or pagetitle
      par1 = getparam(t, "1") or getparam(t, "pres_3sg") or getparam(t, "pres_3sg1")
      par2 = getparam(t, "2") or getparam(t, "pres_ptc") or getparam(t, "pres_ptc1")
      par3 = getparam(t, "3") or getparam(t, "past") or getparam(t, "past1")
      par4 = getparam(t, "4") or getparam(t, "past_ptc") or getparam(t, "past_ptc1")
      pres_3sg_form = None
      pres_ptc_form = None
      past_form = None
      legacy = False
      converted = False

      new_default_s, new_default_ing, new_default_ed, split_default_s, split_default_ing, split_default_ed = (
        default_verb_forms(pagename)
      )

      if par3 and par4 and par3 == par4 and not getparam(t, "past_ptc_qual") and not getparam(t, "past_ptc1_qual"):
        pagemsg("Removing redundant 4=%s: %s" % (par4, unicode(t)))
        rmparam(t, "4")
        rmparam(t, "past_ptc")
        rmparam(t, "past_ptc1")
        notes.append("remove redundant 4= from {{en-verb}}")
        converted = True

      if not par1 and not par2 and not par3:
        if converted:
          num_would_convert += 1
        else:
          num_would_not_convert += 1
        continue

      if par1 and not par2 and not par3:
        # "New" format
        if par1 == "es":
          pres_3sg_form = pagename + "es"
          pres_ptc_form = pagename + "ing"
          past_form = pagename + "ed"
        elif par1 == "ies":
          if not pagename.endswith("y"):
            pagemsg("WARNING: 1=ies but pagename %s doesn't end in -y: %s" % (pagename, unicode(t)))
            num_would_not_convert += 1
            continue
          stem = pagename[:-1]
          pres_3sg_form = stem + "ies"
          pres_ptc_form = stem + "ying"
          past_form = stem + "ied"
        elif par1 == "d":
          pres_3sg_form = pagename + "s"
          pres_ptc_form = pagename + "ing"
          past_form = pagename + "d"
        elif par1 == "++":
          pagemsg("Template has 1=++, not touching: %s" % unicode(t))
          continue
        else:
          pres_3sg_form = pagename + "s"
          pres_ptc_form = par1 + "ing"
          past_form = par1 + "ed"
      else:
        # "Legacy" format
        if par3:
          pass
        else:
          if par2:
            legacy = True
          if par2 == "es":
            pres_3sg_form = par1 + "es"
            pres_ptc_form = par1 + "ing"
            past_form = par1 + "ed"
          elif par2 == "ies":
            if par1 + "y" != pagename:
              pagemsg("WARNING: Legacy -ies format, 1=%s + y is not pagename %s: %s" % (
                par1, pagename, unicode(t)))
            pres_3sg_form = par1 + "ies"
            pres_ptc_form = par1 + "ying"
            past_form = par1 + "ied"
          elif par2 == "ing":
            pres_3sg_form = pagename + "s"
            pres_ptc_form = par1 + "ing"
            past_form = par1 + "ed"
          elif par2 == "ed":
            pres_3sg_form = pagename + "s"
            pres_ptc_form = par1 + "ing"
            past_form = par1 + "ed"
          elif par2 == "d":
            if par1 != pagename:
              pagemsg("WARNING: Legacy -d format, 1=%s is not pagename %s: %s" % (
                par1, pagename, unicode(t)))
            pres_3sg_form = pagename + "s"
            pres_ptc_form = par1 + "ing"
            past_form = par1 + "d"


      if not pres_3sg_form or not pres_ptc_form or not past_form:
        assert not pres_3sg_form and not pres_ptc_form and not past_form
        if pres_3sg_form in ["+", "++"] or pres_ptc_form in ["+", "++"] or past_form in ["+", "++"]:
          pagemsg("Template + or ++, not touching: %s" % unicode(t))
          continue
        pres_3sg_form = par1 or pagename + "s"
        pres_ptc_form = par2 or pagename + "ing"
        past_form = par3 or pagename + "ed"

      m = re.search("([bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ])$", pagename)
      if m:
        double_last_cons_stem = pagename + m.group(1)
      else:
        double_last_cons_stem = None
      if re.search("[sz]$", pagename):
        double_plus_s = double_last_cons_stem + "es"
        double_plus_ing = double_last_cons_stem + "ing"
        double_plus_ed = double_last_cons_stem + "ed"
      elif double_last_cons_stem:
        double_plus_s = new_default_s
        double_plus_ing = double_last_cons_stem + "ing"
        double_plus_ed = double_last_cons_stem + "ed"
      else:
        double_plus_s = None
        double_plus_ing = None
        double_plus_ed = None

      m = re.search("^(.*?[bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ])( .*)$", pagename)
      if m:
        first, rest = m.groups()
        first_double_last_cons = first + first[-1]
      else:
        first = None
        first_double_last_cons = None
      if first and re.search("[sz]$", first):
        double_plus_star_s = first_double_last_cons + "es" + rest
        double_plus_star_ing = first_double_last_cons + "ing" + rest
        double_plus_star_ed = first_double_last_cons + "ed" + rest
      elif first_double_last_cons:
        double_plus_star_s = split_default_s
        double_plus_star_ing = first_double_last_cons + "ing" + rest
        double_plus_star_ed = first_double_last_cons + "ed" + rest
      else:
        double_plus_star_s = None
        double_plus_star_ing = None
        double_plus_star_ed = None

      has4 = not not getparam(t, "4")

      if pres_3sg_form == new_default_s and pres_ptc_form == new_default_ing and past_form == new_default_ed:
        pagemsg("Converting %s to all-default format" % unicode(t))
        if has4:
          t.add("1", "")
        else:
          rmparam(t, "1")
        rmparam(t, "pres_3sg")
        rmparam(t, "pres_3sg1")
        if has4:
          t.add("2", "")
        else:
          rmparam(t, "2")
        rmparam(t, "pres_ptc")
        rmparam(t, "pres_ptc1")
        if has4:
          t.add("3", "")
        else:
          rmparam(t, "3")
        rmparam(t, "past")
        rmparam(t, "past1")
        if args.use_new:
          t.add("new", "1")
        notes.append("convert {{en-verb}} to all-default format")
        converted = True
      else:
        new_code = None
        if pres_3sg_form == double_plus_s and pres_ptc_form == double_plus_ing and past_form == double_plus_ed:
          new_code = "++"
        elif pres_3sg_form == split_default_s and pres_ptc_form == split_default_ing and past_form == split_default_ed:
          new_code = "*"
        elif pres_3sg_form == double_plus_star_s and pres_ptc_form == double_plus_star_ing and past_form == double_plus_star_ed:
          new_code = "++*"

        if new_code:
          pagemsg("Converting %s to %s format" % (unicode(t), new_code))
          t.add("1", new_code)
          rmparam(t, "pres_3sg")
          rmparam(t, "pres_3sg1")
          if has4:
            t.add("2", "")
          else:
            rmparam(t, "2")
          rmparam(t, "pres_ptc")
          rmparam(t, "pres_ptc1")
          if has4:
            t.add("3", "")
          else:
            rmparam(t, "3")
          rmparam(t, "past")
          rmparam(t, "past1")
          notes.append("convert {{en-verb}} to use %s" % new_code)
          converted = True

      if legacy and not converted:
        pagemsg("WARNING: Unable to convert legacy-formatted {{en-verb}} to new format: %s" % unicode(t))

      if converted:
        pagemsg("Would convert {{en-verb}}")
        num_would_convert += 1
      else:
        pagemsg("Would not convert {{en-verb}}")
        num_would_not_convert += 1

      if origt != unicode(t):
        pagemsg("Replaced %s with %s" % (origt, unicode(t)))

  if num_would_convert > 0 and num_would_not_convert > 0:
    pagemsg("Page with {{en-verb}}, would both convert %s and not convert %s" % (
      num_would_convert, num_would_not_convert))
  elif num_would_convert > 0:
    pagemsg("Page with {{en-verb}}, would convert all %s instances" % num_would_convert)
  elif num_would_not_convert > 0:
    pagemsg("Page with {{en-verb}}, would not convert %s instances" % num_would_not_convert)
  return unicode(parsed), notes

parser = blib.create_argparser("Convert {{en-verb}} forms to new format",
  include_pagefile=True, include_stdin=True)
parser.add_argument('--use-new', help="Use new=1 with all defaults", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:en-verb"])

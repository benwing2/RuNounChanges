#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

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

def split_first_rest(form):
  m = re.search("^(.*?)( .*)$", form)
  if m:
    return m.groups()
  else:
    return None, None

def default_verb_forms(verb):
  full_s_form, full_ing_form, full_ed_form = base_default_verb_forms(verb)
  if " " in verb:
    first, rest = split_first_rest(verb)
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
      origt = str(t)
      if getparam(t, "new"):
        pagemsg("Template has new=%s, not touching: %s" % (getparam(t, "new"), str(t)))
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

      default_s, default_ing, default_ed, split_default_s, split_default_ing, split_default_ed = (
        default_verb_forms(pagename)
      )

      dont_touch = ["+", "++", "*", "++*"]

      if par3 and par4 and par3 == par4 and not getparam(t, "past_ptc_qual") and not getparam(t, "past_ptc1_qual"):
        pagemsg("Removing redundant 4=%s: %s" % (par4, str(t)))
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
            pagemsg("WARNING: 1=ies but pagename %s doesn't end in -y: %s" % (pagename, str(t)))
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
        elif par1 in dont_touch:
          pagemsg("Template has 1=%s, not touching: %s" % (par1, str(t)))
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
                par1, pagename, str(t)))
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
                par1, pagename, str(t)))
            pres_3sg_form = pagename + "s"
            pres_ptc_form = par1 + "ing"
            past_form = par1 + "d"

      if not pres_3sg_form or not pres_ptc_form or not past_form:
        assert not pres_3sg_form and not pres_ptc_form and not past_form
        if pres_3sg_form in dont_touch or pres_ptc_form in dont_touch or past_form in dont_touch:
          pagemsg("Template %s, not touching: %s" % (" or ".join(dont_touch), str(t)))
          continue
        pres_3sg_form = par1 or default_s
        pres_ptc_form = par2 or default_ing
        past_form = par3 or default_ed

      past_ptc_form = par4 or past_form

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
        double_plus_s = default_s
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

      if pres_3sg_form == default_s and pres_ptc_form == default_ing and past_form == default_ed:
        pagemsg("Converting %s to all-default format" % str(t))
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
        new_code_msg = None
        remove4 = False
        if pres_3sg_form == double_plus_s and pres_ptc_form == double_plus_ing and past_form == double_plus_ed:
          new_code = "++"
        elif pres_3sg_form == split_default_s and pres_ptc_form == split_default_ing and past_form == split_default_ed:
          new_code = "*"
        elif pres_3sg_form == double_plus_star_s and pres_ptc_form == double_plus_star_ing and past_form == double_plus_star_ed:
          new_code = "++*"
        elif " " in pagename:
          first, rest = split_first_rest(pagename)
          default_first_s, default_first_ing, default_first_ed = base_default_verb_forms(first)
          first_s, rest_s = split_first_rest(pres_3sg_form)
          first_ing, rest_ing = split_first_rest(pres_ptc_form)
          first_ed, rest_ed = split_first_rest(past_form)
          first_en, rest_en = split_first_rest(past_ptc_form)
          rest_unmatch = False
          if rest_s != rest:
            pagemsg("WARNING: Skipping because rest of 1=%s doesn't match pagename: %s" % (pres_3sg_form, str(t)))
            rest_unmatch = True
          elif rest_ing != rest:
            pagemsg("WARNING: Skipping because rest of 2=%s doesn't match pagename: %s" % (pres_ptc_form, str(t)))
            rest_unmatch = True
          elif rest_ed != rest:
            pagemsg("WARNING: Skipping because rest of 3=%s doesn't match pagename: %s" % (past_form, str(t)))
            rest_unmatch = True
          elif rest_en != rest:
            pagemsg("WARNING: Skipping because rest of 4=%s doesn't match pagename: %s" % (past_ptc_form, str(t)))
            rest_unmatch = True
          if not rest_unmatch:
            if first_s == default_first_s:
              first_s = ""
            if first_ing == default_first_ing:
              first_ing = ""
            if first_ed == default_first_ed:
              first_ed = ""
            if first_en == default_first_ed:
              first_en = ""
            inside_forms = [first_s, first_ing, first_ed, first_en]
            while inside_forms and not inside_forms[-1]:
              del inside_forms[-1]
            if len(inside_forms) == 4 and inside_forms[2] == inside_forms[3]:
              del inside_forms[3]
            if not inside_forms:
              pagemsg("WARNING: Something wrong, all-default multiword {{en-verb}} should have been caught above: %s" % str(t))
            else:
              head = getparam(t, "head")
              if head:
                if blib.remove_links(head) != pagename:
                  pagemsg("WARNING: head %s doesn't agree with pagename after links removed: %s" % (head, str(t)))
                else:
                  if "[[" not in head:
                    pagemsg("No links in head %s, removing redundant head: %s" % (head, str(t)))
                    notes.append("remove redundant head=")
                    rmparam(t, "head")
                  else:
                    m = re.search(r"^(\[\[.*?\]\]|.*?)( .*)$", head)
                    if not m:
                      pagemsg("WARNING: Something wrong, can't match first and rest of head %s: %s" % (head, str(t)))
                    if m:
                      firsthead, resthead = m.groups()
                      if blib.remove_links(firsthead) == first and blib.remove_links(resthead) == rest:
                        new_code = "%s<%s>%s" % (firsthead, ",".join(inside_forms), resthead)
                        new_code_msg = "'%s'" % new_code
                        pagemsg("Removing head %s, links moved into 1=: %s" % (head, str(t)))
                        notes.append("move head= links into 1=")
                        rmparam(t, "head")
              if not new_code:
                new_code = "%s<%s>%s" % (first, ",".join(inside_forms), rest)
                new_code_msg = "'%s'" % new_code
              remove4 = True

        if new_code:
          pagemsg("Converting %s to %s" % (str(t), new_code_msg or "%s format" % new_code))
          t.add("1", new_code)
          rmparam(t, "pres_3sg")
          rmparam(t, "pres_3sg1")
          if has4 and not remove4:
            t.add("2", "")
          else:
            rmparam(t, "2")
          rmparam(t, "pres_ptc")
          rmparam(t, "pres_ptc1")
          if has4 and not remove4:
            t.add("3", "")
          else:
            rmparam(t, "3")
          rmparam(t, "past")
          rmparam(t, "past1")
          if remove4:
            rmparam(t, "4")
            rmparam(t, "past_ptc")
            rmparam(t, "past_ptc1")
          notes.append("convert {{en-verb}} to use %s" % new_code_msg or new_code)
          converted = True

      if legacy and not converted:
        pagemsg("WARNING: Unable to convert legacy-formatted {{en-verb}} to new format: %s" % str(t))

      if converted:
        pagemsg("Would convert {{en-verb}}")
        num_would_convert += 1
      else:
        pagemsg("Would not convert {{en-verb}}")
        num_would_not_convert += 1

      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))

  if num_would_convert > 0 and num_would_not_convert > 0:
    pagemsg("Page with {{en-verb}}, would both convert %s and not convert %s" % (
      num_would_convert, num_would_not_convert))
  elif num_would_convert > 0:
    pagemsg("Page with {{en-verb}}, would convert all %s instances" % num_would_convert)
  elif num_would_not_convert > 0:
    pagemsg("Page with {{en-verb}}, would not convert %s instances" % num_would_not_convert)
  return str(parsed), notes

parser = blib.create_argparser("Convert {{en-verb}} forms to new format",
  include_pagefile=True, include_stdin=True)
parser.add_argument('--use-new', help="Use new=1 with all defaults", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:en-verb"])

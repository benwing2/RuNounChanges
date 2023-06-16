#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site

import rulib

lemmas = []

def is_transitive_verb(pagename, pagemsg, errandpagemsg):
  verb_section = blib.find_lang_section(pagename, "Russian", pagemsg, errandpagemsg)
  if not verb_section:
    errandpagemsg("WARNING: Couldn't find Russian section for verb %s" % pagename)
    return False

  parsed = blib.parse_text(verb_section)
  for t in parsed.filter_templates():
    if tname(t) == "ru-verb":
      if getparam(t, "2") in ["impf", "pf", "both"]:
        pagemsg("Saw transitive verb: %s" % str(t))
        return True
      pagemsg("Saw intransitive verb: %s" % str(t))

  return False

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  section = blib.find_lang_section_from_text(pagetext, "Russian", pagemsg)
  if not section:
    errandpagemsg("WARNING: Couldn't find Russian section")
    return

  if "==Etymology" in section:
    return
  if rulib.check_for_alt_yo_terms(section, pagemsg):
    return
  parsed = blib.parse_text(section)
  for t in parsed.filter_templates():
    if tname(t) in ["ru-participle of"]:
      pagemsg("Skipping participle")
      return
  saw_verb = False
  saw_passive = False
  saw_bad_passive = False
  for t in parsed.filter_templates():
    if tname(t) in ["passive of", "passive form of"]:
      saw_passive = True
  if not saw_passive and ("passive of" in section or
    "passive form of" in section):
    saw_bad_passive = True
  splits = []
  for t in parsed.filter_templates():
    if tname(t) == "ru-verb":
      saw_verb = True
      saw_paired_verb = False
      printed_msg = False
      heads = blib.fetch_param_chain(t, "1", "head") or [pagetitle]
      refl = heads[0].endswith(u"ся") or heads[0].endswith(u"сь")
      if refl:
        m = re.search(u"^(.*)(с[яь])$", heads[0])
        assert m
        transverb_no_passive = (False if (saw_passive or saw_bad_passive)
          else is_transitive_verb(rulib.remove_accents(m.group(1)), pagemsg, errandpagemsg))
        if (saw_passive or saw_bad_passive or transverb_no_passive):
          splits.append((heads, [m.group(1)],
            "%s+-%s" % (m.group(1), m.group(2)),
            "active-passive%s%s" % (
              saw_bad_passive and " (saw-bad-passive)" or "",
              transverb_no_passive and " (missing-passive-decl)" or ""
            )
          ))
          continue
      if getparam(t, "2").startswith("impf"):
        pfs = blib.fetch_param_chain(t, "pf", "pf")
        for otheraspect in pfs:
          if heads[0][0:2] == otheraspect[0:2]:
            saw_paired_verb = True
        if saw_paired_verb:
          splits.append((heads, pfs, ",".join(pfs), "paired-impf"))
          printed_msg = True
      if getparam(t, "2").startswith("pf"):
        prefixes = [
          u"взъ", u"вз", u"вс", u"возъ", u"воз", u"вос", u"вы́",
          u"въ", u"в",
          u"до", u"за", u"изъ", u"из", u"ис", u"на",
          u"объ", u"об", u"отъ", u"от", u"о",
          u"пере", u"подъ", u"под", u"по", u"предъ", u"пред", u"пре",
          u"при", u"про",
          u"разъ", u"раз", u"рас", u"съ", u"с", u"у"
        ]
        for break_reflexives in [False, True]:
          head = heads[0]
          if break_reflexives:
            if not head.endswith(u"ся") and not head.endswith(u"сь"):
              break
            reflsuf = "+-" + head[-2:] # fetch reflexive suffix
            head = head[:-2] # drop reflexive suffix
          else:
            reflsuf = ""
          for prefix in prefixes:
            m = re.match("^(%s)(.*)$" % prefix, head)
            if m:
              base = rulib.remove_monosyllabic_accents(
                re.sub(u"^ы", u"и", m.group(2))
              )
              if rulib.remove_accents(base) in lemmas:
                base_to_do = base
              elif rulib.remove_accents("-" + base) in lemmas:
                base_to_do = "-" + base
              else:
                base_to_do = None
              if base_to_do:
                prefix = prefix.replace(u"ъ", "")
                if m.group(1) == u"вы́":
                  need_accent = "-NEED-ACCENT"
                else:
                  need_accent = ""
                splits.append((heads, [base_to_do],
                  "%s-+%s%s%s" % (prefix, base_to_do, reflsuf, need_accent),
                  "strip-prefix"))
                printed_msg = True
      if not printed_msg:
        msg("%s no-etym misc" % ",".join(heads))
  for derived_terms, base_terms, analysis, comment in splits:
    warnings = []
    base_terms_no_accent = []
    for term in base_terms:
      term = rulib.remove_accents(term)
      if term not in base_terms_no_accent:
        base_terms_no_accent.append(term)
    if len(base_terms_no_accent) > 1:
      errandpagemsg("WARNING: Multiple base pages %s for base lemmas %s" % (
        ",".join(base_terms_no_accent), ",".join(base_terms)))
      continue
    if base_terms_no_accent[0] not in lemmas:
      continue
    derived_defns = rulib.find_defns(section)
    if not derived_defns:
      errandpagemsg("WARNING: Couldn't find definitions for derived term %s" %
          ",".join(derived_terms))
      continue
    base_section = blib.find_lang_section(base_terms_no_accent[0], "Russian", pagemsg, errandpagemsg)
    if not base_section:
      errandpagemsg("WARNING: Couldn't find Russian section for base term %s" %
          base_terms_no_accent[0])
      continue
    base_defns = rulib.find_defns(base_section)
    if not base_defns:
      errandpagemsg("WARNING: Couldn't find definitions for base term %s" %
          ",".join(base_terms))
      continue
    def concat_defns(defns):
      return ";".join(defns).replace("_", r"\u").replace(" ", "_")
    msg("%s %s%s no-etym %s %s //// %s" %
      (",".join(derived_terms), analysis,
        " WARNING:%s" % ",".join(warnings) if warnings else "",
        comment, concat_defns(base_defns), concat_defns(derived_defns)))
  if not saw_verb:
        msg("%s no-etym misc" % pagetitle)

# Pages specified using --pages or --pagefile may have accents, which will be stripped.
parser = blib.create_argparser("Find analyses for Russian verbs without declension",
    include_pagefile=True, include_stdin=True, canonicalize_pagename=rulib.remove_accents)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def scrape_pagetitle(page, index):
  lemmas.append(str(page.title()))
blib.do_pagefile_cats_refs(args, start, end, scrape_pagetitle, default_cats=["Russian verbs"])
blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Russian verbs"])

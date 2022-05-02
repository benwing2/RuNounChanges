#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

import infltags

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Bulgarian", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  if "Pronunciation 1" not in secbody:
    return

  if "==Etymology" in secbody:
    pagemsg("WARNING: Saw both ==Pronunciation 1== and ==Etymology==/==Etymology 1==, can't handle")
    return

  if "==Pronunciation==" in secbody:
    pagemsg("WARNING: Saw both ==Pronunciation 1== and ==Pronunciation==, can't handle")
    return

  pronunciation_secs = []

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)
  pronsec_text_parts = []
  saw_pron_1 = False
  above_pron_1_sec_0 = subsections[0]
  above_pron_1 = None
  pronsec = None
  for k in xrange(2, len(subsections), 2):
    if "==Pronunciation" in subsections[k - 1]:
      if "==Pronunciation 1" in subsections[k - 1]:
        above_pron_1 = above_pron_1_sec_0 + "".join(pronsec_text_parts)
      else:
        if pronsec is None:
          pagemsg("WARNING: Something wrong, saw %s and don't have pronsec from previous Pronunciation" %
            subsections[k - 1])
          return
        pronunciation_secs.append((pronsec, "".join(pronsec_text_parts)))
      pronsec_text_parts = []

      pronsec = subsections[k].strip()
      pronsec = re.sub(r"^\{\{rfc-pron-n.*?\}\}\n", "", pronsec, 0, re.M)
    else:
    pronsec_text_parts.append(subsections[k - 1])
    pronsec_text_parts.append(subsections[k])
  if pronsec is None:
    pagemsg("WARNING: Something wrong, didn't see any Pronunciation sections")
    return
  pronunciation_secs.append((pronsec, "".join(pronsec_text_parts)))

  observed_pronuns = []
  observed_lemma = None

  for pronsec_index, (pronsec, pronsec_text) in enumerate(pronunciation_secs):
    parsed = blib.parse_text(pronsec)
    pronsec_prons = []
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "bg-IPA":
        pron = getparam(t, "1")
        endschwa = not not getparam(t, "endschwa")
        pronsec_prons.append((pron, endschwa))
      else:
        pagemsg("WARNING: Unrecognized template in ==Pronunciation %s== section, skipping: %s" %
          (pronsec_index + 1, unicode(t)))
        return
    parsed = blib.parse_text(pronsec_text)
    pronsec_types = []
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn in ["inflection of", "infl of"]:
        lang = getparam(t, "1")
        if lang != "bg":
          pagemsg("WARNING: Saw invalid language %s, skipping: %s" % (lang, unicode(t)))
          return
        lemma = getparam(t, "2")
        if not observed_lemma:
          observed_lemma = lemma
        elif lemma != observed_lemma:
          pagemsg("WARNING: Saw two lemmas %s and %s, skipping: %s" %
            (observed_lemma, lemma, unicode(t)))
          return
        if getparam(t, "3"):
          pagemsg("WARNING: Saw display/alt form of lemma, skipping: %s" % unicode(t))
          return
        tags = blib.fetch_param_chain(t, "4")
        tag_sets = infltags.split_tags_into_tag_sets(tags)
        for tag_set in tag_sets:
          if "pres" in tag_set and "ind" in tag_set:
            pronsec_type = "present indicative"
          elif "aor" in tag_set and "ind" in tag_set:
            pronsec_type = "aorist"
          elif "impf" in tag_set and "ind" in tag_set:
            pronsec_type = "imperfect"
          elif "imp" in tag_set:
            pronsec_type = "imperative"
          elif "vnoun" in tag_set:
            pronsec_type = "verbal noun"
          elif "past" in tag_set and "pass" in tag_set and "part" in tag_set:
            pronsec_type = "past passive participle"
          elif "aor" in tag_set and "part" in tag_set:
            pronsec_type = "aorist participle"
          elif "impf" in tag_set and "part" in tag_set:
            pronsec_type = "imperfect participle"
          else:
            pagemsg("WARNING: Unrecognized tag set %s, skipping: %s" %
              ("|".join(tag_set), unicode(t)))
          if pronsec_type not in pronsec_types:
            pronsec_types.append(pronsec_type)
    if not pronsec_types:
      pagemsg("WARNING: Couldn't extract pronunciation section types in ==Pronunciation %s== section, skipping" %
        (pronsec_index + 1))
      return
    for pronsec_pron in pronsec_prons:
      for observed_pronun, observed_pronun_types in observed_pronuns:
        if pronsec_pron == observed_pronun:
          for pronsec_type in pronsec_types:
            if pronsec_type not in observed_pronun_types:
              observed_pronun_types.append(pronsec_type)
          break
      else: # no break
        observed_pronuns.append((pronsec_pron, pronsec_types))

  # Reformat section using new pronunciations

  secbody = ...
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Reformat Bulgarian pages with ==Pronunciation 1==", include_pagefile=True,
    include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_cats=["Bulgarian terms with IPA pronunciation"], edit=True, stdin=True)

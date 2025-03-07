#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

positive_ending_tags = {
  'en': ['str//wk|nom//acc|m|s', 'wk|dat|m//n|s', 'str//wk|dat|p'],
  'em': ['str|dat|m//n|s'],
  'er': ['str//wk|dat|f|s'],
  't': ['str//wk|nom//acc|n|s'],
}

rename_templates_with_lang = [
  'inflected form of',
]

rename_templates_without_lang = [
  'lb-inflected form of',
]

rename_templates = rename_templates_with_lang + rename_templates_without_lang

def process_text_on_page(pagetitle, index, text):
  global args

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  subsections = re.split("(^==+[^=\n]+==+\n)", text, 0, re.M)
  for j in range(2, len(subsections), 2):
    if not re.search("==(Adjective|Numeral|Ordinal Numeral|Participle)==", subsections[j - 1]):
      continue
    parsed = blib.parse_text(subsections[j])
    for t in parsed.filter_templates():
      origt = str(t)
      tn = tname(t)
      if tn in rename_templates_without_lang:
        lemma = getparam(t, "1")
        langparam = None
        lemmaparam = "1"
      elif tn in rename_templates_with_lang and t.has("lang") and getparam(t, "lang") == "lb":
        lemma = getparam(t, "1")
        langparam = "lang"
        lemmaparam = "1"
      elif tn in rename_templates_with_lang and not t.has("lang") and getparam(t, "1") == "lb":
        lemma = getparam(t, "2")
        langparam = "1"
        lemmaparam = "2"
      else:
        continue

      lemmas_to_try = [lemma]
      if lemma.endswith("e"):
        # lemma with a schwa
        lemmas_to_try.append(lemma[:-1])
      if lemma == "gutt":
        lemmas_to_try.append("gudd")

      ending_sets_to_try = [positive_ending_tags]

      endings_to_try = []
      for ending_sets in ending_sets_to_try:
        for ending, tag_sets in ending_sets.items():
          if pagetitle.endswith(ending):
            endings_to_try.append((ending, tag_sets))
      if len(endings_to_try) == 0:
        pagemsg("WARNING: Can't identify ending of non-lemma form, skipping")
        continue
      found_combinations = []
      for ending_to_try, tag_sets in endings_to_try:
        for lemma_to_try in lemmas_to_try:
          if lemma_to_try + ending_to_try == pagetitle:
            found_combinations.append((lemma_to_try, ending_to_try, tag_sets))
      if len(found_combinations) == 0:
        pagemsg("WARNING: Can't match lemma %s with page title (tried lemma variants %s and endings %s), skipping" %
          (lemma, "/".join(lemmas_to_try),
            "/".join(ending_to_try for ending_to_try, tag_sets in endings_to_try)))
        continue
      if len(found_combinations) > 1:
        pagemsg("WARNING: Found multiple possible matching endings for lemma %s (found possibilities %s), skipping" %
          (lemma, "/".join("%s+%s" % (lemmas_to_try, endings_to_try) for
            lemma_to_try, ending_to_try, tag_sets in found_combinations)))
        continue
      lemma_to_try, ending_to_try, tag_sets = found_combinations[0]
      # Erase all params.
      if langparam:
        rmparam(t, langparam)
      elif getparam(t, "lang") == "lb":
        # Sometimes |lang=lb redundantly occurs; remove it if so
        rmparam(t, "lang")
      rmparam(t, lemmaparam)
      tr = getparam(t, "tr")
      rmparam(t, "tr")
      if len(t.params) > 0:
        pagemsg("WARNING: Original template %s has extra params, skipping" % origt)
        return None, None
      # Set new name
      blib.set_template_name(t, "inflection of")
      # Put back new params.
      t.add("1", "lb")
      t.add("2", lemma)
      if tr:
        t.add("tr", tr)
      t.add("3", "")
      nextparam = 4
      for tag in "|;|".join(tag_sets).split("|"):
        t.add(str(nextparam), tag)
        nextparam += 1
      notes.append("replace %s with %s" % (origt, str(t)))
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))
    subsections[j] = str(parsed)
  text = "".join(subsections)

  return text, notes

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  text = str(page.text)
  return process_text_on_page(pagetitle, index, text)

parser = blib.create_argparser("Replace {{lb-inflected form of}} with proper call to {{inflection of}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in rename_templates:
  msg("Processing references to Template:%s" % template)
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)

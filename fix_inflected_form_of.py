#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

positive_ending_tags = {
  'en': ['str|gen|m//n|s', 'wk//mix|gen//dat|all-gender|s', 'str//wk//mix|acc|m|s', 'str|dat|p', 'wk//mix|all-case|p'],
  'e': ['str//mix|nom//acc|f|s', 'str|nom//acc|p', 'wk|nom|all-gender|s', 'wk|acc|f//n|s'],
  'er': ['str//mix|nom|m|s', 'str|gen//dat|f|s', 'str|gen|p'],
  'es': ['str//mix|nom//acc|n|s'],
  'em': ['str|dat|m//n|s'],
}
comparative_ending_tags = {
  'er' + key: [tag + '|comd' for tag in value] for key, value in positive_ending_tags.iteritems()
}
# for mehr, besser besucht, etc.
special_comparative_ending_tags = {
  key: [tag + '|comd' for tag in value] for key, value in positive_ending_tags.iteritems()
}
superlative_ending_tags = {
  'st' + key: [tag + '|supd' for tag in value] for key, value in positive_ending_tags.iteritems()
}
# for größt, bestbesucht, etc.
special_superlative_ending_tags = {
  key: [tag + '|supd' for tag in value] for key, value in positive_ending_tags.iteritems()
}

rename_templates_with_lang = [
  'inflected form of',
]

rename_templates_without_lang = [
  'de-inflected form of',
]

rename_templates = rename_templates_with_lang + rename_templates_without_lang

def process_text_on_page(index, pagetitle, text):
  global args

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if not args.stdin:
    pagemsg("Processing")

  # Greatly speed things up when --stdin by ignoring pages without any
  # relevant templates
  for template in rename_templates:
    if template in text:
      break
  else:
    return

  notes = []

  subsections = re.split("(^==+[^=\n]+==+\n)", text, 0, re.M)
  for j in range(2, len(subsections), 2):
    if not re.search("==(Adjective|Numeral|Participle)==", subsections[j - 1]):
      continue
    parsed = blib.parse_text(subsections[j])
    for t in parsed.filter_templates():
      origt = unicode(t)
      tn = tname(t)
      if tn in rename_templates_without_lang:
        lemma = getparam(t, "1")
        langparam = None
        lemmaparam = "1"
      elif tn in rename_templates_with_lang and t.has("lang") and getparam(t, "lang") == "de":
        lemma = getparam(t, "1")
        langparam = "lang"
        lemmaparam = "1"
      elif tn in rename_templates_with_lang and not t.has("lang") and getparam(t, "1") == "de":
        lemma = getparam(t, "2")
        langparam = "1"
        lemmaparam = "2"
      else:
        continue

      lemmas_to_try = [lemma]
      # flott -> flottesten, barsch -> barschesten, betagt -> betagtesten,
      # herzlos -> herzlosesten, frohgemut -> frohgemutesten,
      # amyloid -> amyloidesten, erdnah -> erdnahesten, and others
      # unpredictably
      lemmas_to_try.append(lemma + "e")
      if re.search("e[mnlr]$", lemma):
        # simpel -> simplen
        lemmas_to_try.append(lemma[0:-2] + lemma[-1])
      if re.search("e$", lemma):
        # bitweise -> bitweisen
        lemmas_to_try.append(lemma[0:-1])
      if re.search("[^aeiouy][aeiouy][^aeiouy]$", lemma):
        # fit -> fitten, fit -> fittesten
        lemmas_to_try.append(lemma + lemma[-1])
        lemmas_to_try.append(lemma + lemma[-1] + "e")
      m = re.search("^(.*?)(au|[aou])([^aeiouy]+)$", lemma)
      if m:
        # Umlautable adjectives: nass -> nässeren, gesund -> gesünderen, geraum -> geräumeren
        umlauts = {"a": u"ä", "o": u"ö", "u": u"ü", "au": u"äu"}
        umlauted_lemma = m.group(1) + umlauts[m.group(2)] + m.group(3)
        lemmas_to_try.append(umlauted_lemma)
        # Add -e in case of nass -> nässesten
        lemmas_to_try.append(umlauted_lemma + "e")
      if re.search("hoch$", lemma):
        # ranghoch -> ranghohen
        lemmas_to_try.append(lemma[0:-4] + "hoh")
        # ranghoch -> ranghöheren; ranghöchsten will be handled above
        lemmas_to_try.append(lemma[0:-4] + u"höh")
      if re.search("nah$", lemma):
        # körpernah -> körpernächsten; körpernäheren will be handled above
        lemmas_to_try.append(lemma[0:-3] + u"näch")
      if re.search("gut$", lemma):
        # gut -> besseren
        lemmas_to_try.append(lemma[0:-3] + "bess")
        # gut -> besten
        lemmas_to_try.append(lemma[0:-3] + "be")
      if re.search("viel$", lemma):
        # viel -> mehren
        lemmas_to_try.append(lemma[0:-4] + "meh")
        # viel -> meisten
        lemmas_to_try.append(lemma[0:-4] + "mei")
      if re.search("rosa$", lemma):
        # rosa -> rosanen, hellrosa -> hellrosanen
        lemmas_to_try.append(lemma + "n")

      ending_sets_to_try = [superlative_ending_tags, comparative_ending_tags, positive_ending_tags]
      if lemma == "viel":
        if pagetitle.startswith("mehr"):
          lemmas_to_try = ["mehr"]
          ending_sets_to_try = [special_comparative_ending_tags]
        elif pagetitle.startswith("meist"):
          # normal ending_sets_to_try works
          lemmas_to_try = ["mei"]
      elif lemma.endswith(u"groß"):
        # größer handled normally
        if re.search(u"größte[mnrs]?$", pagetitle):
          lemmas_to_try = [lemma[0:-4] + u"größt"]
          ending_sets_to_try = [special_superlative_ending_tags]
      elif lemma.endswith("gross"):
        # grösser handled normally
        if re.search(u"grösste[mnrs]?$", pagetitle):
          lemmas_to_try = [lemma[0:-5] + u"grösst"]
          ending_sets_to_try = [special_superlative_ending_tags]
      else:
        gut_prefixed = [
          ("gutbesucht", ("besser besucht", "bestbesucht")),
          ("guterhalten", ("besser erhalten", "besterhalten")),
          ("gutgelaunt", ("besser gelaunt", "bestgelaunt")),
        ]
        for gut, (besser, best) in gut_prefixed:
          if lemma == gut:
            if pagetitle.startswith(besser):
              lemmas_to_try = [besser]
              ending_sets_to_try = [special_comparative_ending_tags]
            elif pagetitle.startswith(best):
              lemmas_to_try = [best]
              ending_sets_to_try = [special_superlative_ending_tags]

      endings_to_try = []
      for ending_sets in ending_sets_to_try:
        for ending, tag_sets in ending_sets.iteritems():
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
      # If nothing found, and lemma ends in -er, assume the lemma is the strong
      # nominative singular and try again with the -er taken off.
      if len(found_combinations) == 0 and re.search("er$", lemma):
        lemmas_to_try.append(lemma[0:-2])
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
      elif getparam(t, "lang") == "de":
        # Sometimes |lang=de redundantly occurs; remove it if so
        rmparam(t, "lang")
      rmparam(t, lemmaparam)
      if len(t.params) > 0:
        pagemsg("WARNING: Original template %s has extra params, skipping" % origt)
        continue
      # Set new name
      blib.set_template_name(t, "inflection of")
      # Put back new params.
      t.add("1", "de")
      t.add("2", lemma)
      t.add("3", "")
      nextparam = 4
      for tag in "|;|".join(tag_sets).split("|"):
        t.add(str(nextparam), tag)
        nextparam += 1
      notes.append("replace %s with %s" % (origt, unicode(t)))
      pagemsg("Replaced <%s> with <%s>" % (origt, unicode(t)))
    subsections[j] = unicode(parsed)
  text = "".join(subsections)

  return text, notes

parser = blib.create_argparser("Replace {{inflected form of}} with proper call to {{inflection of}}",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
  default_refs=["Template:%s" % template for template in rename_templates], edit=True, stdin=True)

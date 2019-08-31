#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

import lalib
from lalib import remove_macrons

import clean_latin_long_vowels

heads_and_defns_cache = {}
infl_forms_cache = {}
get_headword_from_template_cache = {}
expand_text_cache = {}

def lookup_inflection(lemma, pos, expected_headtemps, expected_infltemp, pagemsg,
    errandpagemsg):
  global args
  lemma_pagetitle = remove_macrons(lemma)

  orig_pagemsg = pagemsg
  orig_errandpagemsg = errandpagemsg
  def pagemsg(txt):
    orig_pagemsg("%s: %s" % (lemma, txt))
  def errandpagemsg(txt):
    orig_errandpagemsg("%s: %s" % (lemma, txt))
  def expand_text(tempcall):
    cache_key = (tempcall, lemma_pagetitle)
    if cache_key in expand_text_cache:
      retval = expand_text_cache[cache_key]
      if args.verbose:
        pagemsg("Found (%s, %s)=%s in expand_text_cache" %
            (tempcall, lemma_pagetitle, retval))
      return retval
    if args.verbose:
      pagemsg("Couldn't find (%s, %s) in expand_text_cache" %
          (tempcall, lemma_pagetitle))
    result = blib.expand_text(tempcall, lemma_pagetitle, pagemsg, args.verbose)
    expand_text_cache[cache_key] = result
    return result

  if lemma_pagetitle in heads_and_defns_cache:
    if args.verbose:
      pagemsg("Found %s in heads_and_defns_cache" % lemma_pagetitle)
    retval = heads_and_defns_cache[lemma_pagetitle]
  else:
    if args.verbose:
      pagemsg("Couldn't find %s in heads_and_defns_cache" % lemma_pagetitle)
    page = pywikibot.Page(site, lemma_pagetitle)
    try:
      exists = blib.try_repeatedly(lambda: page.exists(), pagemsg, "determine if page exists")
    except pywikibot.exceptions.InvalidTitle as e:
      pagemsg("WARNING: Invalid title %s, skipping" % lemma_pagetitle)
      heads_and_defns_cache[lemma_pagetitle] = "nonexistent"
      traceback.print_exc(file=sys.stdout)
      return None
    if not exists:
      pagemsg("WARNING: Lemma %s doesn't exist" % lemma)
      heads_and_defns_cache[lemma_pagetitle] = "nonexistent"
      return None

    retval = clean_latin_long_vowels.find_heads_and_defns(page, pagemsg)
    heads_and_defns_cache[lemma_pagetitle] = retval

  if retval == "nonexistent":
    pagemsg("WARNING: Lemma %s doesn't exist (cached)" % lemma)
    return None
  if retval is None:
    return None

  (
    sections, j, secbody, sectail, has_non_latin, subsections,
    parsed_subsections, headwords, pronun_sections, etym_sections
  ) = retval

  matched_head = False

  inflargs_sets = []

  for allow_macron_mismatch in [False, True]:
    for headword in headwords:
      ht = headword['head_template']
      tn = tname(ht)
      if tn in expected_headtemps:
        oright = unicode(ht)
        heads = lalib.la_get_headword_from_template(ht, lemma_pagetitle,
            pagemsg, expand_text)
        for head in heads:
          if head == lemma:
            break
          if allow_macron_mismatch and remove_macrons(head) == remove_macrons(lemma):
            pagemsg("WARNING: Matching lemma %s against actual lemma %s" % (
              lemma, head))
            break
        else:
          # no break
          continue
        for inflt in headword['infl_templates']:
          infltn = tname(inflt)
          if infltn != expected_infltemp:
            pagemsg("WARNING: Saw bad declension template for %s, expected {{%s}}: %s" % (
              pos, expected_infltemp, unicode(inflt)))
            continue

          originflt = unicode(inflt)
          inflargs = lalib.generate_infl_forms(pos, originflt, errandpagemsg, expand_text)
          if inflargs is None:
            continue
          inflargs_sets.append(inflargs)
          matched_head = True
    if matched_head:
      break
    if not allow_macron_mismatch:
      pagemsg("WARNING: Couldn't find head that matches with macrons, trying again allowing macron differences")
  if not matched_head:
    pagemsg("WARNING: Couldn't find any matching heads, even allowing macron differences")
    return None
  return inflargs_sets

def process_text_on_page(index, pagetitle, text):
  global args

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  if not args.stdin:
    pagemsg("Processing")

  # Greatly speed things up when --stdin by ignoring non-Latin pages
  if "==Latin==" not in text:
    return None, None

  retval = clean_latin_long_vowels.find_heads_and_defns(page, pagemsg)
  if retval is None:
    return None, None

  (
    sections, j, secbody, sectail, has_non_latin, subsections,
    parsed_subsections, headwords, pronun_sections, etym_sections
  ) = retval

  for headword in headwords:
    ht = headword['head_template']
    tn = tname(ht)

    if tn == "la-noun-form" or tn == "head" and getparam(ht, "1") == "la" and getparam(ht, "2") == "noun form":
      pos = "noun"
      tag_set_groups = lalib.noun_tag_groups
      possible_slots = lalib.la_noun_decl_overrides
      expected_headtemps = ["la-noun"]
      expected_infltemp = "la-ndecl"
    elif tn == "la-proper noun-form" or tn == "head" and getparam(ht, "1") == "la" and getparam(ht, "2") == "proper noun form":
      pos = "pn"
      tag_set_groups = lalib.noun_tag_groups
      possible_slots = lalib.la_noun_decl_overrides
      expected_headtemps = ["la-proper noun"]
      expected_infltemp = "la-ndecl"
    #elif tn == "la-pronoun-form" or tn == "head" and getparam(ht, "1") == "la" and getparam(ht, "2") == "pronoun form":
    #  pos = "pronoun"
    #  tag_set_groups = lalib.adj_tag_groups
    #  possible_slots = lalib.la_adj_decl_overrides
    #  expected_headtemp = ???
    elif tn == "la-verb-form" or tn == "head" and getparam(ht, "1") == "la" and getparam(ht, "2") == "verb form":
      pos = "verb"
      tag_set_groups = lalib.verb_tag_groups
      possible_slots = lalib.la_verb_overrides
      expected_headtemps = ["la-verb"]
      expected_infltemp = "la-conj"
    elif tn == "la-adj-form" or tn == "head" and getparam(ht, "1") == "la" and getparam(ht, "2") == "adjective form":
      pos = "adj"
      tag_set_groups = lalib.adj_tag_groups
      possible_slots = lalib.la_adj_decl_overrides
      expected_headtemps = ["la-adj", "la-adj-comparative", "la-adj-superlative"]
      expected_infltemp = "la-adecl"
    elif tn == "la-part-form" or tn == "head" and getparam(ht, "1") == "la" and getparam(ht, "2") == "participle form":
      pos = "part"
      tag_set_groups = lalib.adj_tag_groups
      possible_slots = lalib.la_adj_decl_overrides
      expected_headtemps = ["la-part"]
      expected_infltemp = "la-adecl"
    #elif tn == "la-suffix-form" or tn == "head" and getparam(ht, "1") == "la" and getparam(ht, "2") == "suffix form":
    #  pos = "suffix"
    elif tn == "la-num-form" or tn == "head" and getparam(ht, "1") == "la" and getparam(ht, "2") == "numeral form":
      pos = "numadj"
      tag_set_groups = lalib.adj_tag_groups
      possible_slots = lalib.la_adj_decl_overrides
      expected_headtemps = ["la-num-adj"]
      expected_infltemp = "la-adecl"
    else:
      continue

    headword_forms = lalib.la_get_headword_from_template(ht, pagetitle, pagemsg)

    for t in headword['infl_of_templates']:
      lang = getparam(t, "lang")
      if lang:
        lemma_param = 1
      else:
        lang = getparam(t, "1")
        lemma_param = 2
      if lang != "la":
        errandpagemsg("WARNING: In Latin section, found {{inflection of}} for different language %s: %s" % (
          lang, unicode(t)))
        continue
      lemma = getparam(t, str(lemma_param))
      inflargs_sets = lookup_inflection(lemma, pos, expected_headtemps,
          expected_infltemp, pagemsg, errandpagemsg)
      if inflargs_sets is None:
        pagemsg("WARNING: Lemma %s doesn't exist or has no %s heads" % (lemma, pos))
        continue

      # fetch tags
      tags = []
      for param in t.params:
        pname = unicode(param.name).strip()
        pval = unicode(param.value).strip()
        if re.search("^[0-9]+$", pname):
          if int(pname) >= lemma_param + 2:
            if pval:
              tags.append(pval)
      # split tags into tag sets (which may be multipart) and further
      # split any multipart tag sets into component tag sets
      tag_sets = [tag_set
        for maybe_multipart_tag_set in lalib.split_tags_into_tag_sets(tags)
        for tag_set in lalib.split_multipart_tag_set(maybe_multipart_tag_set)
      ]
      for tag_set in tag_sets:
        slot = lalib.tag_set_to_slot(tag_set, tag_set_groups, pagemsg)
        if slot is None:
          continue
        if slot not in possible_slots:
          pagemsg("WARNING: Unrecognized slot %s from tag set: %s" % (
            slot, unicode(t)))
          continue

        matched_form = False
        for allow_macron_mismatch in [False, True]:
          for inflargs in inflargs_sets:
            if slot not in inflargs:
              continue
            forms = inflargs[slot]
            for form in forms.split(","):
              if form in headword_forms:
                matched_form = True
                pagemsg("Matched headword form %s exactly (slot %s, lemma %s)" %  (form, slot, lemma))
                break
              if allow_macron_mismatch:
                for headword_form in headword_forms:
                  if remove_macrons(form) == remove_macrons(headword_form):
                    pagemsg("WARNING: Matching headword form %s against actual form %s" % (
                      headword_form, form))
                    matched_form = True
                    break
                if matched_form:
                  break
            if matched_form:
              break
          if matched_form:
            break
          if not allow_macron_mismatch:
            pagemsg("WARNING: Couldn't find form that matches with macrons any of %s (slot %s, lemma %s), trying again allowing macron differences" % (
              ",".join(headword_forms), slot, lemma))
        if not matched_form:
          pagemsg("WARNING: Couldn't find any matching forms for headword forms %s (slot %s, lemma %s), even allowing macron differences" % (
            ",".join(headword_forms), slot, lemma))
  return None, None

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  text = unicode(page.text)
  return process_text_on_page(index, pagetitle, text)

parser = blib.create_argparser("Check for Latin forms that don't match headword")
parser.add_argument("--stdin", help="Read dump from stdin.", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.stdin:
  blib.parse_dump(sys.stdin, process_text_on_page)
else:
  for i, page in blib.cat_articles("Latin non-lemma forms", start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)

#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

cons_re = u"[bcdfghjklmnprřqstvwxzčňšžďť]"

# Regexes matching noun endings. Assume -ova and -ovo cannot be nouns. Regexes must be end-anchored.
noun_endings = [cons_re, "(?<!ov)a", "(?<!ov)o", "e", u"í"]

infer_adj_lemma = [
    [u"ý", u"ý"],
    [u"ův", u"ův"],
    [u"á", u"ý"],
    [u"ova", u"ův"],
    [u"é", u"ý"],
    [u"ovo", u"ův"],
    # FIXME, this might be a masc animate plural of -ý
    [u"í", u"í"],
]

adj_form_endings = []
adj_lemma_endings = []

for form_ending, lemma_ending in infer_adj_lemma:
  adj_form_endings.append(form_ending)
  if lemma_ending not in adj_lemma_endings:
    adj_lemma_endings.append(lemma_ending)

particles = [
  # List of prepositions and particles, from Janda and Townsend pp. 40-42
  # prepositions
  u"během", u"běheme", "bez", u"blízko", "daleko", "dle", "do", "k", "ke", "ku", "kolem", "koleme", u"kromě", "mezi",
  "mimo", u"místo", "na", "nad", "nade", "naproti", "navzdory", "o", "ob", "obe", "od", "ode", "okolo", "po",
  u"poblíž", u"poblíže" "pod", "pode", u"podél", u"podéle", "podle", "pro", "proti", u"před", u"přede", u"přes",
  u"přese", u"při", "s", "se", "skrz", "skrze", "u", u"uprostřed", u"uprostřede", u"uvnitř", u"uvnitře", "v", "ve",
  u"včetně", "vedle", u"vně", u"vůči", "vyjma", "z", "ze", "za", "zpod", "zpode",
  # conjunctions
  "a", u"ačkoliv", "ale", "ani", u"aniž", u"až", u"buď", "i", "dokud", "jak", u"jelikož", "jestli", u"jestliže",
  u"kdežto", u"když", "nebo", "anebo", u"neboť", u"než", u"nýbrž", "pokud", u"poněvadž", u"protože", u"přestože",
  "zda", "zdali", u"že",
  # omitted conjunctions
  "jako",
  # particles
  "ale", "copak", "hele", u"kéž", u"konečně", "no", "nu", u"nuže", u"přece", "tedy", "teda", u"třeba", u"vždyť"
  ]

# List of words where we use the specified declension, to deal with cases
# where there are multiple declensions; we have to be careful here to make
# sure more than one declension isn't actually used in different lemmas
use_given_decl = {}

use_given_page_decl = {}

class Headword(object):
  def __init__(self, lemma, infl, separator, could_be_noun, could_be_adj):
    self.lemma = lemma
    self.infl = infl
    self.separator = separator
    self.could_be_noun = could_be_noun
    self.could_be_adj = could_be_adj

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  subpagetitle = re.sub("^.*:", "", pagetitle)

  notes = []

  parsed = blib.parse_text(text)

  # Find the declension arguments for LEMMA and inflected form INFL, the WORDINDth word in the expression. Return value
  # is a tuple (DECL, POS) where POS == "noun", "adj" or "indecl".
  def find_decl_args(lemma, infl, wordind):
    declpage = pywikibot.Page(site, lemma)
    if infl == lemma:
      wordlink = infl
    else:
      wordlink = "[[%s|%s]]" % (lemma, infl)

    if not declpage.exists():
      pagemsg("WARNING: Page doesn't exist, can't locate decl for word #%s, skipping: lemma=%s, infl=%s" %
          (wordind, lemma, infl))
      return
    parsed = blib.parse_text(declpage.text)
    decl_templates = []
    headword_templates = []
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn in ["cs-ndecl", "cs-adecl"]:
        pagemsg("find_decl_args: Found decl template: %s" % unicode(t))
        decl_templates.append(t)
      if tn in ["cs-noun", "cs-proper noun"]:
        pagemsg("find_decl_args: Found headword template: %s" % unicode(t))
        headword_templates.append(t)

    if not decl_templates:
      for headt in headword_templates:
        if getparam(headt, "indecl"):
          return "", "indecl"
      pagemsg("WARNING: No decl template during decl lookup for word #%s, skipping: lemma=%s, infl=%s" %
          (wordind, lemma, infl))
      return

    if len(decl_templates) == 1:
      decl_template = decl_templates[0]
    else:
      # Multiple decl templates
      if lemma in use_given_decl:
        overriding_decl = use_given_decl[lemma]
        pagemsg("WARNING: Multiple decl templates during decl lookup for word #%s and not adjectival, using overriding declension %s: lemma=%s, infl=%s" %
            (wordind, overriding_decl, lemma, infl))
        decl_template = blib.parse_text(overriding_decl).filter_templates()[0]
      elif pagetitle in use_given_page_decl:
        overriding_decl = use_given_page_decl[pagetitle].get(lemma, None)
        if not overriding_decl:
          pagemsg("WARNING: Missing entry for ambiguous-decl lemma for word #%s, skipping: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
          return
        else:
          pagemsg("WARNING: Multiple decl templates during decl lookup for word #%s and not adjectival, using overriding declension %s: lemma=%s, infl=%s" %
              (wordind, overriding_decl, lemma, infl))
          decl_template = blib.parse_text(overriding_decl).filter_templates()[0]
      else:
        pagemsg("WARNING: Multiple decl templates during decl lookup for word #%s and not adjectival, skipping: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
        return

    pagemsg("find_decl_args: Using decl template: %s" % unicode(decl_template))
    if tname(decl_template) == "cs-adecl":
      return "+", "adj"

    # cs-ndecl
    assert tname(decl_template) == "cs-ndecl"
    decl = getparam(decl_template, "1")
    if "<" in decl:
      pagemsg("WARNING: Saw angle bracket in declension '%s' for word #%s, skipping: lemma=%s, infl=%s" %
          (decl, wordind, lemma, infl))
      return
    if "((" in decl:
      pagemsg("WARNING: Saw multiple alternants in declension '%s' for word #%s, skipping: lemma=%s, infl=%s" %
          (decl, wordind, lemma, infl))
      return
    return decl, "noun"

  headword_template = None
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["cs-ndecl"]:
      pagemsg("Found %s, skipping" % tn)
      return
    if tn in ["cs-noun", "cs-proper noun"]:
      if headword_template:
        pagemsg("WARNING: Multiple cs-noun or cs-proper noun templates, skipping")
        return
      headword_template = t

  if not headword_template:
    pagemsg("WARNING: Can't find headword template, skipping")
    return

  pagemsg("Found headword template: %s" % unicode(headword_template))

  headword_is_proper = tname(headword_template) == "cs-proper noun"

  if getparam(headword_template, "indecl") or "[[Category:Czech indeclinable nouns]]" in text:
    pagemsg("WARNING: Indeclinable noun, skipping")
    return

  rfinfl = "{{rfinfl|cs|%s}}" % ("proper noun" if headword_is_proper else "noun")
  def print_from_to():
    pagemsg("<from> %s <to> %s <end> <from> %s <to> %s <end>" % (rfinfl, rfinfl, unicode(headword_template), unicode(headword_template)))

  headword = getparam(headword_template, "head")
  saw_explicit_headword = not not headword
  for badparam in ["head2"]:
    val = getparam(headword_template, badparam)
    if val:
      pagemsg("WARNING: Found extra param, can't handle, skipping: %s=%s" % (
        badparam, val))
      print_from_to()
      return
  if not headword:
    headword = re.sub("([^ -]+)", r"[[\1]]", pagetitle)

  # Here we use a capturing split, and treat what we want to capture as
  # the splitting text, backwards from what you'd expect. The separators
  # will fall at 0, 2, ... and the headwords as 1, 3, ... There will be
  # an odd number of items, and the first and last should be empty.
  headwords_separators = re.split(r"(\[\[.*?\]\][^ -]*|[^ -]+)", headword)
  if headwords_separators[0] != "" or headwords_separators[-1] != "":
    pagemsg("WARNING: Found junk at beginning or end of headword, skipping")
    print_from_to()
    return

  # List of Headword objects. Separator is the separator that goes after the word.
  headwords = []
  wordind = 0
  for i in range(1, len(headwords_separators), 2):
    hword = headwords_separators[i]
    separator = headwords_separators[i+1]
    if i < len(headwords_separators) - 2 and separator != " " and separator != "-":
      pagemsg("WARNING: Separator after word #%s isn't a space or hyphen, can't handle: word=<%s>, separator=<%s>" %
          (wordind + 1, hword, separator))
      print_from_to()
      return
    # Canonicalize two-part link in headword
    m = re.search(r"^\[\[([^\[\]|]+)\|([^\[\]|]+)\]\]([^ -]*)$", hword)
    if m:
      lemma, infl, aftertext = m.groups()
      infl += aftertext
      lemma = re.sub("#Czech$", "", lemma)
      if lemma == infl:
        hword = "[[%s]]" % infl
      else:
        hword = "[[%s|%s]]" % (lemma, infl)
    # Canonicalize links of the form [[Fermi]]ho
    m = re.search(r"^\[\[([^\[\]|]+)\]\]([^ -]+)$", hword)
    if m:
      lemma, aftertext = m.groups()
      infl = lemma + aftertext
      hword = "[[%s|%s]]" % (lemma, infl)

    # Break apart into lemma and inflection
    m = re.search(r"^\[\[([^\[\]|]+)\|([^\[\]|]+)\]\]$", hword)
    undeclined = False
    if m:
      lemma, infl = m.groups()
    else:
      m = re.search(r"^\[\[([^\[\]|]+)\]\]$", hword)
      if m:
        infl = m.group(1)
        lemma = infl
      else:
        infl = hword
        lemma = hword
        undeclined = True
    # If didn't see explicit headword, try to work out the headword lemmas and infls
    could_be_adj = False
    could_be_noun = False
    if infl == lemma and not undeclined and not saw_explicit_headword:
      for infl_ending, lemma_ending in infer_adj_lemma:
        if infl.endswith(infl_ending):
          lemma_base = infl[0:-len(infl_ending)]
          lemma = lemma_base + lemma_ending
          could_be_adj = True
          break
      for ending_re in noun_endings:
        if re.search(ending_re + "$", infl):
          could_be_noun = True
          break
    elif not undeclined:
      # infer whether adj or noun
      for infl_ending, lemma_ending in infer_adj_lemma:
        if infl.endswith(infl_ending) and lemma.endswith(lemma_ending):
          could_be_adj = True
          break
      if infl == lemma:
        for ending_re in noun_endings:
          if re.search(ending_re + "$", lemma):
            could_be_noun = True
            break

    headwords.append(Headword(lemma, infl, separator, could_be_noun, could_be_adj))
    wordind += 1

  def print_headword(headword):
    if headword.lemma == headword.infl:
      lemmainfl = "[[%s]]" % headword.lemma
    else:
      lemmainfl = "[[%s|%s]]" % (headword.lemma, headword.infl)
    return "%s(could_be_noun=%s, could_be_adj=%s)" % (lemmainfl, headword.could_be_noun, headword.could_be_adj)
  pagemsg("Found headwords: %s" % " @@ ".join(print_headword(h) for h in headwords))

  # Get headword genders (includes animacy and number)
  genders = blib.fetch_param_chain(headword_template, "1", "g")
  genders_include_pl = len([x for x in genders if re.search(r"\bp\b", x)]) > 0

  # Try to figure out which words are inflected and which words aren't
  possible_noun_inds = set()
  for wordind, headword in enumerate(headwords):
    if headword.infl == headword.lemma and headword.infl in particles:
      pass
    elif headword.could_be_noun and not headword.could_be_adj:
      possible_noun_inds.add(wordind)
  if len(possible_noun_inds) > 1:
    pagemsg("WARNING: Multiple possible nouns indexed %s among headwords, skipping" % (
      ",".join(str(ind + 1) for ind in sorted(list(possible_noun_inds)))))
    print_from_to()
    return
  if len(possible_noun_inds) == 0:
    # Try again, this time not skipping adjectives
    possible_noun_inds = set()
    for wordind, headword in enumerate(headwords):
      if headword.infl == headword.lemma and headword.infl in particles:
        pass
      elif headword.could_be_noun:
        possible_noun_inds.add(wordind)
    if len(possible_noun_inds) > 1:
      pagemsg("WARNING: Multiple possible nouns indexed %s among headwords, skipping" % (
        ",".join(str(ind + 1) for ind in sorted(list(possible_noun_inds)))))
      print_from_to()
      return
    if len(possible_noun_inds) == 0:
      pagemsg("WARNING: No possible nouns among headwords, skipping")
      print_from_to()
      return
  noun_ind = list(possible_noun_inds)[0]
  noun_decl = None
  headword_parts = []
  decl_parts = []
  for wordind, headword in enumerate(headwords):
    if headword.infl == headword.lemma and headword.infl in particles:
      headword.pos = "indecl"
    elif wordind == noun_ind:
      headword.pos = "noun"
    elif headword.could_be_adj:
      headword.pos = "adj"
    else:
      headword.pos = "indecl"

    if headword.lemma == headword.infl:
      lemmainfl = headword.lemma
      headword_lemmainfl = "[[%s]]" % headword.lemma
    else:
      lemmainfl = "[[%s|%s]]" % (headword.lemma, headword.infl)
      headword_lemmainfl = lemmainfl
    headword_parts.append(headword_lemmainfl)
    headword_parts.append(headword.separator)
    if headword.pos == "noun":
      pagemsg("Looking up declension for lemma %s, infl %s" % (headword.lemma, headword.infl))
      retval = find_decl_args(headword.lemma, headword.infl, wordind)
      if not retval:
        pagemsg("WARNING: Can't get declension for %s, skipping" % headword.lemma)
        print_from_to()
        return
      decl, declpos = retval
      if declpos == "indecl":
        if headword.lemma == headword.infl:
          lemmainfl = "[[%s]]" % headword.lemma
        decl_parts.append(lemmainfl)
      else:
        decl_parts.append("%s<%s>" % (lemmainfl, decl))
        noun_decl = decl
    elif headword.pos == "adj":
      decl_parts.append("%s<+>" % lemmainfl)
    else:
      if headword.lemma == headword.infl:
        lemmainfl = "[[%s]]" % headword.lemma
      decl_parts.append(lemmainfl)
    decl_parts.append(headword.separator)

  new_decl_template = "{{cs-ndecl|%s}}" % "".join(decl_parts)
  pagemsg("Generated new declension template %s" % new_decl_template)
  new_headword_template = unicode(headword_template)
  if not saw_explicit_headword:
    new_headword = "".join(headword_parts)
    potential_new_headword_template = re.sub(r"\}\}$", "|head=%s}}" % "".join(new_headword), new_headword_template)
    if "|" not in new_headword:
      pagemsg("Generated new headword template %s, no two-part links so not needed" % potential_new_headword_template)
    else:
      pagemsg("Generated new headword template %s" % potential_new_headword_template)
      new_headword_template = potential_new_headword_template
  gender = None
  def new_print_from_to():
    pagemsg("<from> %s <to> %s <end> <from> %s <to> %s <end>" % (rfinfl, new_decl_template, unicode(headword_template), new_headword_template))
  if noun_decl is not None:
    if noun_decl.startswith("m.an"):
      gender = "m-an"
    elif noun_decl.startswith("m"):
      gender = "m-in"
    elif noun_decl.startswith("f"):
      gender = "f"
    elif noun_decl.startswith("n"):
      gender = "n"
    else:
      pagemsg("WARNING: Unable to extract gender from noun declension '%s', skipping" % noun_decl)
      new_print_from_to()
      return
  if set(genders) != set([gender]):
    pagemsg("WARNING: Declension gender %s != headword gender(s) %s" % (gender, ",".join(genders)))
    new_print_from_to()
    return

  new_print_from_to()
  return None

parser = blib.create_argparser("Infer declensions for multiword Czech nouns",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

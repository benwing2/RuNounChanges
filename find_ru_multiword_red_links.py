#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Find redlinks (non-existent pages) in multiword Russian lemmas, i.e. individual
# words in multiword lemmas that don't exist as lemmas. Output data in two
# ways: As we encounter each redlink (but only the first time encountered),
# and sorted by number of occurrences.

import pywikibot, re, sys, argparse
import traceback

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

import rulib

# For each lemma seen, count of how many times seen
lemma_count = {}
# For each nonexistent lemma seen, message indicating what type of nonexistence
# ('does not exist', 'exists as redirect', 'exists as superlative',
# 'exists as non-lemma').
nonexistent_lemmas = {}
# For each nonexistent lemma seen, list of all pages referencing it.
nonexistent_lemmas_refs = {}
lemmas = set()

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  parsed = blib.parse_text(text)

  def check_lemma(lemma):
    if lemma in lemma_count:
      lemma_count[lemma] += 1
      if lemma in nonexistent_lemmas:
        nonexistent_lemmas_refs[lemma].append(pagetitle)
    else:
      lemma_count[lemma] = 1
      if lemma not in lemmas:
        page = pywikibot.Page(site, lemma)
        if blib.safe_page_exists(page, errandpagemsg):
          pagetext = blib.safe_page_text(page, errandpagemsg)
          if re.search("#redirect", pagetext, re.I):
            nonexistent_msg = "exists as redirect"
          elif re.search(r"\{\{superlative of", pagetext):
            nonexistent_msg = "exists as superlative"
          else:
            nonexistent_msg = "exists as non-lemma"
        else:
          nonexistent_msg = "does not exist"
        pagemsg("Referenced lemma %s: %s" % (lemma, nonexistent_msg))
        nonexistent_lemmas[lemma] = nonexistent_msg
        nonexistent_lemmas_refs[lemma] = [pagetitle]

  def process_arg_set(arg_set):
    if not arg_set:
      return
    offset = 0
    if re.search(r"^[a-f]'*(,[a-f]'*)*$", arg_set[offset]):
      offset = 1
    if len(arg_set) <= offset:
      return
    # Remove * meaning non-stressed
    lemma = re.sub(r"^\*", "", arg_set[offset])
    # Remove translit
    lemma = re.sub("//.*$", "", lemma)
    if not lemma:
      return
    headwords_separators = re.split(r"(\[\[.*?\]\]|[^ \-]+)", lemma)
    if headwords_separators[0] != "" or headwords_separators[-1] != "":
      pagemsg("WARNING: Found junk at beginning or end of headword, skipping: %s" % lemma)
      return
    wordind = 0
    for i in range(1, len(headwords_separators), 2):
      hword = headwords_separators[i]
      separator = headwords_separators[i+1]
      if i < len(headwords_separators) - 2 and separator != " " and separator != "-":
        pagemsg("WARNING: Separator after word #%s isn't a space or hyphen, can't handle: word=<%s>, separator=<%s>" %
            (wordind + 1, hword, separator))
        continue
      hword = hword.replace("#Russian", "")
      hword = rulib.remove_accents(blib.remove_right_side_links(hword))
      check_lemma(hword)
      wordind += 1

  def process_new_style_headword(htemp):
    # Split out the arg sets in the declension and check the
    # lemma of each one, taking care to handle cases where there is no lemma
    # (it would default to the page name).

    highest_numbered_param = 0
    for p in htemp.params:
      pname = str(p.name)
      if re.search("^[0-9]+$", pname):
        highest_numbered_param = max(highest_numbered_param, int(pname))

    # Now split based on arg sets.
    arg_set = []
    for i in range(1, highest_numbered_param + 2):
      end_arg_set = False
      val = getparam(htemp, str(i))
      if (i == highest_numbered_param + 1 or val in ["or", "_", "-"] or
          re.search("^join:", val)):
        end_arg_set = True

      if end_arg_set:
        process_arg_set(arg_set)
        arg_set = []
      else:
        arg_set.append(val)

  def process_verb_headword(htemp):
    # Look for either space-delimited words or bracket-delimited sections.
    words = [x for num, x in
        enumerate(re.split(r"([^\s\[\]]+|\[\[.*?\]\])", getparam(htemp, "1")))
        if num % 2 == 1]
    for word in words:
      word = word.replace("#Russian", "")
      word = rulib.remove_accents(blib.remove_right_side_links(word))
      if "[" in word or "]" in word:
        pagemsg("WARNING: Found stray bracket in word %s in %s" %
            (word, str(htemp)))
      else:
        check_lemma(word)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "ru-decl-noun-see":
      pagemsg("WARNING: Skipping ru-decl-noun-see, can't handle yet: %s" % str(t))
    elif tn in ["ru-noun+", "ru-proper noun+"]:
      pagemsg("Found %s" % str(t))
      process_new_style_headword(t)
    elif tn in ["ru-verb"]:
      pagemsg("Found %s" % str(t))
      process_verb_headword(t)
    elif tn in ["ru-noun", "ru-proper noun"]:
      pagemsg("WARNING: Skipping ru-noun or ru-proper noun, can't handle yet: %s" % str(t))

parser = blib.create_argparser("Find red links in multiword Russian lemmas",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

msg("Reading Russian lemmas")
for i, page in blib.cat_articles("Russian lemmas", start, end):
  lemmas.add(str(page.title()))

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:tracking/ru-headword/space-in-headword/" + pos
    for pos in ["nouns", "proper nouns", "verbs"]])

for lemma, nonexistent_msg in sorted(nonexistent_lemmas.items(), key=lambda pair:(-lemma_count[pair[0]], pair[0])):
  msg("* [[%s]] (%s occurrence%s): %s (refs: %s)" % (lemma, lemma_count[lemma],
    "" if lemma_count[lemma] == 1 else "s", nonexistent_msg,
    ", ".join("[[%s]]" % x for x in nonexistent_lemmas_refs[lemma])))

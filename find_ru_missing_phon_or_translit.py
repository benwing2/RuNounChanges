#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Go through Russian lemmas looking for pages with missing phon= or missing translit.
# Currently we just look for э in the ru-IPA call but not in the page title.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

import runounlib

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if u"э" in pagetitle:
    pagemsg(u"Skipping because has э in page title")
    return

  words = re.split("[ -]", pagetitle)

  parsed = blib.parse_text(text)
  found_ru_ipa = []
  prons = []
  saw_phon = False
  saw_epsilon_pron = [False] * len(words)
  saw_no_epsilon_pron = [False] * len(words)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "ru-IPA":
      pron = getparam(t, "phon")
      if pron:
        found_ru_ipa.append(("phon", pron))
        prons.append("phon=%s" % pron)
        saw_phon = True
      else:
        pron = getparam(t, "1")
        if not pron:
          pron = pagetitle
        found_ru_ipa.append(("nophon", pron))
        prons.append(pron)
        if u"э" in pron:
          pagemsg("WARNING: Likely missing phon=: %s" % str(t))
      pronwords = re.split("[ -]", pron)
      if len(words) != len(pronwords):
        pagemsg("WARNING: Something wrong, %s words but %s pron words: pron is %s" % (
          len(words), len(pronwords), pron))
      else:
        for index, pronword in enumerate(pronwords):
          if u"э" in pronword:
            saw_epsilon_pron[index] = True
          else:
            saw_no_epsilon_pron[index] = True

  pronstr = ",".join(prons)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["ru-noun+", "ru-proper noun+"]:
      per_word_info = runounlib.split_noun_decl_arg_sets(t, pagemsg)
      if len(per_word_info) != len(words):
        pagemsg("WARNING: Something wrong, %s words but %s lemmas" % (
          len(words), len(per_word_info)))
      else:
        for index, (word, arg_sets) in enumerate(zip(words, per_word_info)):
          lemmas = []
          split_lemmas = []
          saw_tr_with_epsilon = False
          saw_tr_without_epsilon = False
          saw_no_tr = False
          for arg_set in arg_sets:
            lemma = arg_set[1]
            if not lemma:
              lemma = pagetitle
            if "//" in lemma:
              ru, tr = lemma.split("//")
            else:
              ru = lemma
              tr = ""
            split_lemmas.append((ru, tr))
            lemmas.append(lemma)
            if u"ɛ" in tr or re.search(u"[aeiouyáéíóúý][eé]", tr):
              saw_tr_with_epsilon = True
            elif tr:
              saw_tr_without_epsilon = True
            else:
              saw_no_tr = True

          lemmastr = "|or|".join(lemmas)

          if saw_epsilon_pron[index] != saw_tr_with_epsilon:
            if saw_epsilon_pron[index]:
              pagemsg(u"WARNING: Saw э in pron %s but not decl %s for word %s" % (
                pronstr, lemmastr, word))
            else:
              pagemsg(u"WARNING: Saw ɛ in decl %s but not pron %s for word %s" % (
                lemmastr, pronstr, word))
          saw_non_tr_with_epsilon = saw_tr_without_epsilon or saw_no_tr
          if saw_no_epsilon_pron[index] != saw_non_tr_with_epsilon:
            if saw_no_epsilon_pron[index]:
              pagemsg(u"WARNING: Saw pron %s without э but not decl %s without ɛ for word %s"
                  % (pronstr, lemmastr, word))
            else:
              pagemsg(u"WARNING: Saw decl %s without ɛ but not pron %s without э for word %s"
                  % (lemmastr, pronstr, word))

parser = blib.create_argparser("Find missing phon= or transit in Russian lemmas",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--fix-star", action="store_true", help="Fix pronun lines missing * at beginning")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Russian lemmas"])

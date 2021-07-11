#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
import unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, site

GR = u"\u0300"

recognized_suffixes = [
  # -(m)ente, -(m)ento
  ("ment([eo])", ur"mént\1"), # must precede -ente/o below
  ("ent([eo])", ur"ènt\1"), # must follow -mente/o above
  # verbs
  ("izzare", u"iddzàre"), # must precede -are below
  ("izzarsi", u"iddzàrsi"), # must precede -arsi below
  ("([ai])re", r"\1" + GR + "re"), # must follow -izzare above
  ("([ai])rsi", r"\1" + GR + "rsi"), # must follow -izzarsi above
  # nouns
  ("izzatore", u"iddzatóre"), # must precede -tore below
  ("([st])ore", ur"\1óre"), # must follow -izzatore above
  ("izzatrice", u"iddzatrìce"), # must precede -trice below
  ("trice", u"trìce"), # must follow -izzatrice above
  ("izzazione", u"iddzatsióne"), # must precede -zione below
  ("zione", u"tsióne"), # must precede -one below and follow -izzazione above
  ("one", u"óne"), # must follow -zione above
  ("acchio", u"àcchio"),
  ("acci([ao])", ur"àcci\1"),
  ("([aiu])ggine", r"\1" + GR + "ggine"),
  ("aggio", u"àggio"),
  ("([ai])gli([ao])", r"\1" + GR + r"gli\2"),
  ("ai([ao])", ur"ài\1"),
  ("([ae])nza", r"\1" + GR + "ntsa"),
  ("ario", u"àrio"),
  ("([st])orio", ur"\1òrio"),
  ("astr([ao])", ur"àstr\1"),
  ("ell([ao])", ur"èll\1"),
  ("etta", u"étta"),
  # do not include -etto, both ètto and étto are common
  ("ezza", u"éttsa"),
  ("ficio", u"fìcio"),
  ("ier([ao])", ur"ièr\1"),
  ("ifero", u"ìfero"),
  ("ismo", u"ìsmo"),
  ("ista", u"ìsta"),
  ("izi([ao])", ur"ìtsi\1"),
  ("logia", u"logìa"),
  # do not include -otto, both òtto and ótto are common
  ("tudine", u"tùdine"),
  ("ura", u"ùra"),
  ("([^aeo])uro", ur"\1ùro"),
  # adjectives
  ("izzante", u"iddzànte"), # must precede -ante below
  ("ante", u"ànte"), # must follow -izzante above
  ("izzando", u"iddzàndo"), # must precede -ando below
  ("([ae])ndo", r"\1" + GR + "ndo"), # must follow -izzando above
  ("([ai])bile", r"\1" + GR + "bile"),
  ("ale", u"àle"),
  ("([aeiou])nico", r"\1" + GR + "nico"),
  ("([ai])stic([ao])", r"\1" + GR + r"stic\2"),
  # exceptions to the following: àbato, àcato, acròbata, àgata, apòstata, àstato, cìato, fégato, omeòpata,
  # sàb(b)ato, others?
  ("at([ao])", ur"àt\1"),
  ("([ae])tic([ao])", r"\1" + GR + r"tic\2"),
  ("ense", u"ènse"),
  ("esc([ao])", ur"ésc\1"),
  ("evole", u"évole"),
  # FIXME: Systematic exceptions to the following in 3rd plural present tense verb forms
  ("ian([ao])", ur"iàn\1"),
  ("iv([ao])", ur"ìv\1"),
  ("oide", u"òide"),
  ("oso", u"óso"),
]

unstressed_words = {
  "il", "lo", "la", "i", "gli", "le", # definite articles
  "un", # indefinite articles
  "mi", "ti", "si", "ci", "vi", "li", # object pronouns
  "me", "te", "se", "ce", "ve", "ne", # conjunctive object pronouns
  "e", "ed", "o", "od", # conjunctions
  "chi", "che", "non", # misc particles
  "di", "del", "dei", # prepositions
  "a", "ad", "al", "ai",
  "da", "dal", "dai",
  "in", "nel", "nei",
  "con", "col", "coi",
  "su", "sul", "sui",
  "per", "pei",
  "tra", "fra",
}

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  subsections = re.split("(^==+[^=\n]+==+\n)", text, 0, re.M)

  has_etym_sections = "==Etymology 1==" in text
  saw_existing_pron = False

  etymsection = "top" if has_etym_sections else "all"
  for k in xrange(2, len(subsections), 2):
    m = re.search("==Etymology ([0-9]*)==", subsections[k - 1])
    if m:
      etymsection = m.group(1)
    if "==Pronunciation==" in subsections[k - 1]:
      parsed = blib.parse_text(subsections[k])

      respellings = []
      prev_it_IPA_t = None
      must_continue = False
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn == "it-IPA":
          if prev_it_IPA_t:
            pagemsg("WARNING: Saw multiple {{it-IPA}} templates in a single Pronunciation section: %s, %s" % (
              unicode(prev_it_IPA_t), unicode(t)))
            must_continue = True
            break
          prev_it_IPA_t = t
          for param in t.params:
            pn = pname(param)
            pv = unicode(param.value).strip().replace(" ", "_")
            if re.search("^[0-9]+$", pn):
              respellings.append(pv)
            else:
              respellings.append("%s=%s" % (pn, pv))
      if must_continue:
        continue

      if respellings:
        pagemsg("<respelling> %s: %s <end> EXISTING" % (etymsection, " ".join(respellings)))
        saw_existing_pron = True

  if not saw_existing_pron:
    msgs = []
    def append_msg(txt):
      if txt not in msgs:
        msgs.append(txt)
    respelled_words = []
    traditional_respelled_words = []
    for word in pagetitle.split(" "):
      if word in unstressed_words:
        respelled_words.append(word)
        traditional_respelled_words.append(word)
        continue
      if re.search(u"[àèéìòóù]", word):
        respelled_words.append(word)
        traditional_respelled_words.append(word)
        continue
      if word.startswith("-"):
        respelled_words.append(word)
        traditional_respelled_words.append(word)
        append_msg("SUFFIX")
        continue
      if word.endswith("-"):
        respelled_words.append(word)
        traditional_respelled_words.append(word)
        append_msg("PREFIX")
        continue
      m = re.search("^([^AEIOUaeiou]*)([AIUaiu])([^A-Z0-9aeiou]*[aeiou]?)$", word)
      if m:
        first, vowel, rest = m.groups()
        accented = unicodedata.normalize("NFC", first + vowel + GR + rest)
        respelled_words.append(accented)
        traditional_respelled_words.append(accented)
        append_msg("AUTOACCENTED")
        continue
      for suf, repl in recognized_suffixes:
        subbed_word = unicodedata.normalize("NFC", re.sub(suf + "$", repl, word))
        if subbed_word != word:
          append_msg("AUTOSUBBED")
          break
      else: # no break
        append_msg("NEED_ACCENT")
        subbed_word = word
      if pagetitle.endswith("ese"):
        respelled_words.append(re.sub("ese$", u"ése", word))
        traditional_respelled_words.append(re.sub("ese$", u"é[s]e", word))
        append_msg("AUTO_ESE")
      elif pagetitle.endswith("oso"):
        respelled_words.append(re.sub("oso$", u"óso", word))
        traditional_respelled_words.append(re.sub("oso$", u"ó[s]o", word))
        append_msg("AUTO_OSO")
      else:
        respelled_words.append(subbed_word)
        traditional_respelled_words.append(subbed_word)
      hacked_subbed = subbed_word.lower()
      if re.search(u"[aeiouàèéìòóù]s[aeiouàèéìòóù]", hacked_subbed):
        append_msg("S_BETWEEN_VOWELS")
      if "z" in hacked_subbed:
        append_msg("Z")
      if re.search(u"[aeiouàèéìòóù]i([^aeiouàèéìòóù]|$)", hacked_subbed):
        append_msg("FALLING_IN_I")
      hacked_subbed = re.sub("([gq])u", r"\1w", hacked_subbed)
      hacked_subbed = hacked_subbed.replace("gli", "gl")
      hacked_subbed = re.sub("([cg])i", r"\1", hacked_subbed)
      if re.search(u"[^aeiouàèéìòóù][iu][aeiouàèéìòóù]", hacked_subbed):
        append_msg("HIATUS")
    respelled_term = "_".join(respelled_words)
    traditional_respelled_term = "_".join(traditional_respelled_words)
    respellings = [respelled_term]
    if respelled_term != traditional_respelled_term:
      respellings.append("#" + traditional_respelled_term)
    pagemsg("<respelling> %s: %s <end> %s" % ("top" if has_etym_sections else "all",
      " ".join(x.replace(" ", "_") for x in respellings), " ".join(msgs)))

parser = blib.create_argparser("Snarf Italian pronunciations for fixing",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

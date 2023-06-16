#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

hindi_head_templates = [
  "hi-adj form",
  "hi-adj",
  "hi-adv",
  "hi-con",
  "hi-diacritical mark",
  "hi-interj",
  "hi-num",
  "hi-noun",
  "hi-noun form",
  "hi-num-card",
  "hi-particle",
  "hi-perfect participle",
  "hi-phrase",
  "hi-post",
  "hi-prefix",
  "hi-prep",
  "hi-pron",
  "hi-proper noun",
  "hi-proverb",
  "hi-suffix",
  "hi-verb",
  "hi-verb form",
]

def canonicalize_tr(tr):
  tr = tr.lower()
  def remove_extraneous_nasalization(m):
    nasal_to_non_nasal = {
      u"ã": "a",
      u"ẽ": "e",
      u"ĩ": "i",
      u"õ": "o",
      u"ũ": "u",
    }
    nasal_vowel, rest = m.groups()
    return nasal_to_non_nasal[nasal_vowel] + rest
  tr = re.sub(u"([ãẽĩõũ])([nṅṇñm][^ aeiouāīūĕŏěǒãẽĩõũ])", remove_extraneous_nasalization, tr)
  tr = tr.replace(u"â", u"ā")
  tr = tr.replace(u"ê", u"e")
  tr = tr.replace(u"î", u"ī")
  tr = tr.replace(u"ô", u"o")
  tr = tr.replace(u"û", u"ū")
  tr = tr.replace(u"ō", "o")
  tr = tr.replace(u"ē", "e")
  tr = tr.replace(u"'", "")
  return tr


def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  head_template_tr = None
  head_auto_tr = None
  noun_head_template = None
  saw_ndecl = False
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn in hindi_head_templates:
      if noun_head_template and head_template_tr and not saw_ndecl:
        pagemsg("WARNING: Missing declension for noun needing phonetic respelling, headtr=%s, autotr=%s: %s" % (
          ",".join(head_template_tr), ",".join(head_auto_tr), str(noun_head_template)))
      if tn in ["hi-noun", "hi-proper noun"]:
        noun_head_template = t
      else:
        noun_head_template = None
      saw_ndecl = False
      head_template_tr = []
      head_auto_tr = []
      multi_trs = False
      for i in range(2, 10):
        if getparam(t, "tr%s" % i):
          multi_trs = True
          # We might have tr=some special translit and tr2=the default one, and in that case
          # we don't want to remove tr2= even though it appears redundant.
          pagemsg("More than one translit, not removing any redundant ones: %s" % str(t))
          break
      for i in range(1, 10):
        trparam = "tr" if i == 1 else "tr%s" % i
        origtr = getparam(t, trparam)
        tr = canonicalize_tr(origtr)
        if tr:
          headparam = "head" if i == 1 else "head%s" % i
          head = getparam(t, headparam)
          if head:
            head = blib.remove_links(head)
          else:
            head = pagetitle
          autotr = expand_text("{{xlit|hi|%s}}" % head)
          if autotr is not None:
            if autotr == tr and not multi_trs:
              assert i == 1
              pagemsg("WARNING: Removing redundant translit tr=%s for head %s" % (
                tr, head))
              rmparam(t, "tr")
              notes.append("remove redundant tr=%s from {{%s}}" % (tr, tn))
            else:
              head_template_tr.append(tr)
              head_auto_tr.append(autotr)
              pagemsg("Page has non-redundant translit %s=%s vs. auto tr=%s in {{%s}}" % (
                trparam, tr, autotr, tn))
              if origtr != tr:
                pagemsg("Canonicalizing %s=%s to %s: %s" % (trparam, origtr, tn, str(t)))
                t.add(trparam, tr)
                notes.append("canonicalize %s=%s to %s in {{%s}}" % (trparam, origtr, tr, tn))
      if str(t) != origt:
        pagemsg("Replaced %s with %s" % (origt, str(t)))
    if tn == "hi-ndecl":
      saw_ndecl = True
      decl = getparam(t, "1")
      phon_respellings = re.findall("//([^<>, -]*)", decl)
      if head_template_tr is None:
        pagemsg("WARNING: Saw {{hi-ndecl}} before any headwords: %s" % str(t))
      else:
        respelling_tr = [expand_text("{{xlit|hi|%s}}" % x) for x in phon_respellings]
        if None in respelling_tr:
          pagemsg("WARNING: Error during phonetic respelling translit, skipping")
          continue
        respelling_tr = [x.replace(".", "") for x in respelling_tr]
        for phon_respelling in phon_respellings:
          if u"॰" in phon_respelling:
            pagemsg(u"WARNING: Saw ॰ in phon_respelling %s in %s" % (
              phon_respelling, str(t)))
        if head_template_tr and not phon_respellings:
          pagemsg("WARNING: Missing phonetic respelling in %s, headtr=%s, autotr=%s" % (
            str(t), ",".join(head_template_tr), ",".join(head_auto_tr)))
        elif phon_respellings and not head_template_tr:
          pagemsg("WARNING: Extra phonetic respelling %s (translit %s) in %s, no head tr" % (
            ",".join(phon_respellings), ",".join(respelling_tr), str(t)))
        elif set(respelling_tr) != set(head_template_tr):
          pagemsg("WARNING: Phonetic respelling %s (translit %s) in %s differs from head translit %s, auto translit %s" % (
            ",".join(phon_respellings), ",".join(respelling_tr), str(t),
            ",".join(head_template_tr), ",".join(head_auto_tr)))
        elif phon_respellings:
          pagemsg("Phonetic respelling %s (translit %s) in %s agrees with head translit %s, auto translit %s" % (
            ",".join(phon_respellings), ",".join(respelling_tr), str(t),
            ",".join(head_template_tr), ",".join(head_auto_tr)))

  if noun_head_template and head_template_tr and not saw_ndecl:
    pagemsg("WARNING: Missing declension for noun needing phonetic respelling, headtr=%s, autotr=%s: %s" % (
      ",".join(head_template_tr), ",".join(head_auto_tr), str(noun_head_template)))

  return str(parsed), notes

parser = blib.create_argparser("Remove redundant translit from Hindi headwords and check translit against phonetic respelling",
  include_pagefile=True, include_stdin=True)
parser.add_argument('--direcfile', help="File containing output from find_regex.py.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, default_cats=["Hindi lemmas"], edit=True, stdin=True)

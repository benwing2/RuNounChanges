#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Add pos= to ru-IPA pronunciations. Also find instances where и or я has
# been used phonetically in place of е and put back to е.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru
import runounlib as runoun

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping page")
    return

  titlewords = re.split("[ -]", pagetitle)
  saw_e = False
  for word in titlewords:
    if word.endswith(u"е") and not ru.is_monosyllabic(word):
      saw_e = True
      break
  if not saw_e:
    pagemsg("No possible final unstressed -е in page title, skipping")
    return
  if " " in pagetitle or "-" in pagetitle:
    pagemsg("WARNING: Space or hyphen in page title and probable final unstressed -e, not sure how to handle yet")
    return

  text = unicode(page.text)
  notes = []

  foundrussian = False
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in xrange(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections, skipping page")
        return
      foundrussian = True

      subsections = re.split("(^===(?:Etymology|Pronunciation) [0-9]+===\n)", sections[j], 0, re.M)
      # If no separate etymology sections, add extra stuff at the beginning
      # to fit the pattern
      if len(subsections) == 1:
        subsections = ["", ""] + subsections

      saw_unstressed_e = False
      saw_unstressed_i = False
      saw_unstressed_ja = False
      saw_unstressed_y = False
      saw_unstressed_a = False
      saw_ru_IPA = False
      for k in xrange(0, len(subsections), 2):
        for t in blib.parse_text(subsections[k]).filter_templates():
          if unicode(t.name) == "ru-IPA":
            saw_ru_IPA = True

            phon = (getparam(t, "phon") or getparam(t, "1") or pagetitle).lower()
            if not ru.is_monosyllabic(phon):
              if re.search(u"е" + ru.DOTABOVE + "?$", phon):
                saw_unstressed_e = True
              elif re.search(u"и" + ru.DOTABOVE + "?$", phon):
                saw_unstressed_i = True
              elif re.search(u"я" + ru.DOTABOVE + "?$", phon):
                saw_unstressed_ja = True
              elif re.search(u"[цшж]ы" + ru.DOTABOVE + "?$", phon):
                saw_unstressed_y = True
              elif re.search(u"[цшж]а" + ru.DOTABOVE + "?$", phon):
                saw_unstressed_a = True
              elif not re.search(u"[еэѐ][" + ru.AC + ru.GR + ru.CFLEX + ru.DUBGR + "]?$", phon):
                pagemsg(u"WARNING: ru-IPA phonology doesn't end in [еэия] or hard sibilant + [ыа], something wrong, skipping page: %s" %
                    unicode(t))
                return
      if not saw_ru_IPA:
        pagemsg("WARNING: No ru-IPA on page, skipping page")
        return
      if saw_unstressed_e:
        pagemsg(u"Saw unstressed -е, continuing")
      if saw_unstressed_i:
        pagemsg(u"Saw unstressed -и, continuing")
      if saw_unstressed_ja:
        pagemsg(u"Saw unstressed -я, continuing")
      if saw_unstressed_y:
        pagemsg(u"Saw unstressed -ы after hard sibilant, continuing")
      if saw_unstressed_a:
        pagemsg(u"Saw unstressed -а after hard sibilant, continuing")
      if (not saw_unstressed_e and not saw_unstressed_i
          and not saw_unstressed_ja and not saw_unstressed_y
          and not saw_unstressed_a):
        pagemsg(u"No unstressed -е/и/я, skipping page")
        return

      pron_for_all_etym = []
      first_section_parsed = blib.parse_text(subsections[0])
      for t in first_section_parsed.filter_templates():
        if unicode(t.name) == "ru-IPA":
          pron_for_all_etym.append(t)
          pagemsg("Saw ru-IPA covering multiple etymological sections: %s" %
              unicode(t))
      # If saw ru-IPA covering multiple etym sections, make sure we don't
      # also have pronuns inside the etym sections, and then treat as one
      # single section for the purposes of finding POS's
      if pron_for_all_etym:
        for k in xrange(2, len(subsections), 2):
          for t in blib.parse_text(subsections[k]).filter_templates():
            if unicode(t.name) == "ru-IPA":
              pagemsg("WARNING: Saw ru-IPA covering multiple etym sections and also ru-IPA inside an etym section, skipping page")
              return
        subsections = ["", "", "".join(subsections)]

      for k in xrange(2, len(subsections), 2):
        pos = set()
        prons = []
        parsed = blib.parse_text(subsections[k])
        for t in parsed.filter_templates():
          def getp(param):
            return getparam(t, param)
          tname = unicode(t.name)
          if tname in ["ru-noun", "ru-proper noun"]:
            if getparam(t, "2") == "-":
              pagemsg("Found invariable noun: %s" % unicode(t))
              pos.add("inv")
            else:
              pagemsg("Found declined noun: %s" % unicode(t))
              pos.add("n")
          elif tname in ["ru-noun+", "ru-proper noun+"]:
            pagemsg("Found declined noun: %s" % unicode(t))
            pos.add("n")
          elif tname == "comparative of" and getp("lang") == "ru":
            pagemsg("Found comparative: %s" % unicode(t))
            pos.add("com")
          elif tname == "ru-adv":
            pagemsg("Found adverb: %s" % unicode(t))
            pos.add("adv")
          elif tname == "ru-adj":
            pagemsg("Found adjective: %s" % unicode(t))
            pos.add("a")
          elif tname == "head" and getp("1") == "ru" and getp("2") == "verb form":
            pagemsg("Found verb form: %s" % unicode(t))
            pos.add("v")
          elif tname == "head" and getp("1") == "ru" and getp("2") == "adjective form":
            pagemsg("Found adjective form: %s" % unicode(t))
            pos.add("a")
          elif tname == "head" and getp("1") == "ru" and getp("2") == "pronoun form":
            pagemsg("Found pronoun form: %s" % unicode(t))
            pos.add("pro")
          elif tname == "inflection of" and getp("lang") == "ru":
            for param in t.params:
              if unicode(param.value) in ["pre", "prep", "prepositional"]:
                pagemsg("Found prepositional case inflection: %s" % unicode(t))
                pos.add("pre")
                break
            for param in t.params:
              if unicode(param.value) in ["dat", "dative"]:
                pagemsg("Found dative case inflection: %s" % unicode(t))
                pos.add("dat")
                break
            for param in t.params:
              if unicode(param.value) in ["voc", "vocative"]:
                pagemsg("Found vocative case inflection: %s" % unicode(t))
                pos.add("voc")
                break
          elif tname == "prepositional singular of" and getp("lang") == "ru":
            pagemsg("Found prepositional case inflection: %s" % unicode(t))
            pos.add("pre")
          elif tname == "dative singular of" and getp("lang") == "ru":
            pagemsg("Found dative case inflection: %s" % unicode(t))
            pos.add("dat")
          elif tname == "vocative singular of" and getp("lang") == "ru":
            pagemsg("Found vocative case inflection: %s" % unicode(t))
            pos.add("voc")



            ...
        subsections[k] = unicode(parsed)
      sections[j] = "".join(subsections)

  new_text = "".join(sections)

  if new_text != text:
    notes.append("add pos= to ru-IPA templates")
    assert notes
    comment = "; ".join(notes)
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = new_text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser("Add pos= to final -е ru-IPA, fix use of phonetic -и/-я")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for category in ["Russian lemmas", "Russian non-lemma forms"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    msg("Page %s %s: Processing" % (i, unicode(page.title())))
    process_page(i, page, args.save, args.verbose)

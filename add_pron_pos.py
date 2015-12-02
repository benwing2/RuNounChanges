#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Add pos= to ru-IPA pronunciations. Also find instances where и/я/ы/а has
# been used phonetically in place of е and put back to е.

# FIXME:
#
# 1. (DONE) Go through pages with spaces in them, looking for non-final words
#    with final -и or whatever in place of -е. Fix them.
# 2. (DONE) Remove final ! and ? from page title when looking for final -е.
# 3. (DONE) Recognize prepositions and nnp's

import pywikibot, re, sys, codecs, argparse
from collections import Counter

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru
import runounlib as runoun

pages_pos = {}

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  override_pos = pages_pos.get(pagetitle, None)
  if override_pos:
    del pages_pos[pagetitle]

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping page")
    return

  titlewords = re.split(u"([ ‿-]+)", re.sub("[!?]$", "", pagetitle))
  saw_e = False
  for word in titlewords:
    if word.endswith(u"е") and not ru.is_monosyllabic(word):
      saw_e = True
      break
  if not saw_e:
    pagemsg(u"No possible final unstressed -е in page title, skipping")
    return

  if (" " in pagetitle or "-" in pagetitle) and not override_pos:
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

      subsections_with_ru_ipa_to_fix = set()
      subsections_with_ru_ipa = set()
      for k in xrange(0, len(subsections), 2):
        for t in blib.parse_text(subsections[k]).filter_templates():
          if unicode(t.name) == "ru-IPA":
            subsections_with_ru_ipa.add(k)
            if getparam(t, "pos"):
              pagemsg("Already has pos=, skipping template in section %s: %s" %
                  (k//2, unicode(t)))
            else:
              phon = (getparam(t, "phon") or getparam(t, "1") or pagetitle).lower()
              phonwords = re.split(u"([ ‿-]+)", phon)
              if len(phonwords) != len(titlewords):
                pagemsg("WARNING: #Words (%s) in phon=%s not same as #words (%s) in title, skipping phon" % (
                    (len(phonwords)+1)//2, phon, (len(titlewords)+1)//2))
              else:
                for i in xrange(0, len(phonwords), 2):
                  titleword = titlewords[i]
                  phonword = phonwords[i]
                  wordno = i//2 + 1
                  if ru.is_monosyllabic(phonword):
                    pagemsg("Skipping monosyllabic pronun %s (#%s) in section %s: %s" %
                        (phonword, wordno, k//2, unicode(t)))
                  elif not titleword.endswith(u"е"):
                    pagemsg(u"Skipping title word %s (#%s) in section %s because doesn't end in -е" %
                        (titleword, wordno, k//2))
                  elif re.search(u"([еия]|цы|[кгхцшжщч]а)" + ru.DOTABOVE + "?$", phonword):
                    pagemsg("Found template that will be modified due to phonword %s, titleword %s (#%s) in section %s: %s" %
                        (phonword, titleword, wordno, k//2, unicode(t)))
                    subsections_with_ru_ipa_to_fix.add(k)
                  elif not re.search(u"[еэѐ][" + ru.AC + ru.GR + ru.CFLEX + ru.DUBGR + "]?$", phonword):
                    pagemsg(u"WARNING: ru-IPA pronunciation word %s (#%s) doesn't end in [еэия] or hard sibilant + [ыа] when corresponding titleword %s ends in -е, something wrong in section %s: %s" %
                        (phonword, wordno, titleword, k//2, unicode(t)))
                  else:
                    pagemsg(u"Pronun word %s (#%s) with final -э or stressed vowel, ignoring in section %s: %s" %
                        (phonword, wordno, k//2, unicode(t)))

      if not subsections_with_ru_ipa:
        pagemsg("No ru-IPA on page, skipping page")
        return
      if not subsections_with_ru_ipa_to_fix:
        pagemsg("No fixable ru-IPA on page, skipping page")
        return

      # If saw ru-IPA covering multiple etym sections, make sure we don't
      # also have pronuns inside the etym sections, and then treat as one
      # single section for the purposes of finding POS's
      if 0 in subsections_with_ru_ipa:
        if len(subsections_with_ru_ipa) > 1:
          pagemsg("WARNING: Saw ru-IPA in section 0 (covering multiple etym or pronun sections) and also inside etym/pronun section(s) %s; skipping page" %
              (",".join(k//2 for k in subsections_with_ru_ipa if k > 0)))
          return
        subsections = ["", "", "".join(subsections)]
        subsections_with_ru_ipa_to_fix = {2}

      for k in subsections_with_ru_ipa_to_fix:
        pagemsg("Fixing section %s" % (k//2))
        parsed = blib.parse_text(subsections[k])

        if override_pos:
          pos = override_pos
        else:
          pos = set()
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
              for param in t.params:
                if re.search("^[0-9]+$", unicode(param.name)) and "+" in unicode(param.value):
                  pagemsg("Found declined adjectival noun, treating as adjective: %s" % unicode(t))
                  pos.add("a")
                  break
              else:
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
            elif tname == "head" and getp("1") == "ru":
              if getp("2") == "verb form":
                pagemsg("Found verb form: %s" % unicode(t))
                pos.add("v")
              elif getp("2") in ["adjective form", "participle form"]:
                pagemsg("Found adjective form: %s" % unicode(t))
                pos.add("a")
              elif getp("2") == "pronoun form":
                pagemsg("Found pronoun form: %s" % unicode(t))
                pos.add("pro")
              elif getp("2") == "preposition":
                pagemsg("Found preposition: %s" % unicode(t))
                pos.add("p")
              elif getp("2") == "numeral":
                pagemsg("Found numeral: %s" % unicode(t))
                pos.add("num")
              elif getp("2") == "pronoun":
                pagemsg("Found pronoun: %s" % unicode(t))
                pos.add("pro")
            elif tname == "inflection of" and getp("lang") == "ru":
              saw_nom = False
              saw_p = False
              for param in t.params:
                val = unicode(param.value)
                if val in ["nom", "nominative"]:
                  saw_nom = True
                if val in ["p", "plural"]:
                  saw_p = True
                if saw_nom and saw_p:
                  pagemsg("Found nominative plural case inflection: %s" % unicode(t))
                  pos.add("nnp")
                  saw_nom = False
                  saw_p = False
                if val == ';':
                  # May have multiple inflections separated by semicolon;
                  # reset flags if so
                  saw_nom = False
                  saw_p = False
                if val in ["pre", "prep", "prepositional"]:
                  pagemsg("Found prepositional case inflection: %s" % unicode(t))
                  pos.add("pre")
                if val in ["dat", "dative"]:
                  pagemsg("Found dative case inflection: %s" % unicode(t))
                  pos.add("dat")
                if val in ["voc", "vocative"]:
                  pagemsg("Found vocative case inflection: %s" % unicode(t))
                  pos.add("voc")
            elif tname == "prepositional singular of" and getp("lang") == "ru":
              pagemsg("Found prepositional case inflection: %s" % unicode(t))
              pos.add("pre")
            elif tname == "dative singular of" and getp("lang") == "ru":
              pagemsg("Found dative case inflection: %s" % unicode(t))
              pos.add("dat")
            elif tname == "vocative singular of" and getp("lang") == "ru":
              pagemsg("Found vocative case inflection: %s" % unicode(t))
              pos.add("voc")

          if "dat" in pos and "pre" in pos:
            pagemsg("Removing pos=dat because pos=pre is found")
            pos.remove("dat")
          if "com" in pos:
            if "a" in pos:
              pagemsg("Removing pos=a because pos=com is found")
              pos.remove("a")
            if "adv" in pos:
              pagemsg("Removing pos=adv because pos=com is found")
              pos.remove("adv")
          if "a" in pos and "nnp" in pos:
            pagemsg("Removing pos=nnp because pos=a is found")
            pos.remove("nnp")
          if not pos:
            pagemsg("WARNING: Can't locate any parts of speech, skipping section")
            continue
          if len(pos) > 1:
            pagemsg("WARNING: Found multiple parts of speech, skipping section: %s" %
                ",".join(pos))
            continue
          pos = list(pos)[0]

        for t in parsed.filter_templates():
          if unicode(t.name) == "ru-IPA":
            param = "phon"
            phon = getparam(t, param)
            if not phon:
              param = "1"
              phon = getparam(t, "1")
              if not phon:
                param = "pagetitle"
                phon = pagetitle
            origt = unicode(t)
            if getparam(t, "pos"):
              pass # Already output msg
            else:
              phonwords = re.split("([ -]+)", phon)
              if len(phonwords) != len(titlewords):
                pass # Already output message
              else:
                for i in xrange(0, len(phonwords), 2):
                  titleword = titlewords[i]
                  phonword = phonwords[i]
                  lphonword = phonword.lower()
                  wordno = i//2 + 1

                  if ru.is_monosyllabic(phonword):
                    pass # Already output msg
                  elif not titleword.endswith(u"е"):
                    pass # Already output msg
                  elif re.search(u"([еия]|цы|[кгхцшжщч]а)" + ru.DOTABOVE + "?$", lphonword):
                    # Found a template to modify
                    if re.search(u"е" + ru.DOTABOVE + "?$", lphonword):
                      pass # No need to canonicalize
                    else:
                      if re.search(u"и" + ru.DOTABOVE + "?$", lphonword):
                        pagemsg(u"phon=%s (word #%s) ends in -и, will modify to -е in section %s: %s" % (phonword, wordno, k//2, unicode(t)))
                        notes.append(u"unstressed -и -> -е")
                      elif re.search(u"я" + ru.DOTABOVE + "?$", lphonword):
                        pagemsg(u"phon=%s (word #%s) ends in -я, will modify to -е in section %s: %s" % (phonword, wordno, k//2, unicode(t)))
                        notes.append(u"unstressed -я -> -е")
                      elif re.search(u"цы" + ru.DOTABOVE + "?$", lphonword):
                        pagemsg(u"phon=%s (word #%s) ends in ц + -ы, will modify to -е in section %s: %s" % (phonword, wordno, k//2, unicode(t)))
                        notes.append(u"unstressed -ы after ц -> -е")
                      elif re.search(u"[кгхцшжщч]а" + ru.DOTABOVE + "?$", lphonword):
                        pagemsg(u"phon=%s (word #%s) ends in unpaired cons + -а, will modify to -е in section %s: %s" % (phonword, wordno, k//2, unicode(t)))
                        notes.append(u"unstressed -а after unpaired cons -> -е")
                      else:
                        assert False, "Something wrong, strange ending, logic not correct: section %s, phon=%s (word #%s)" % (k//2, phonword, wordno)
                      newphonword = re.sub(u"[ияыа](" + ru.DOTABOVE + "?)$", ur"е\1", phonword)
                      newphonword = re.sub(u"[ИЯЫА](" + ru.DOTABOVE + "?)$", ur"Е\1", newphonword)
                      pagemsg("Modified phon=%s (word #%s) to %s in section %s: %s" % (
                        phonword, wordno, newphonword, k//2, unicode(t)))
                      phonwords[i] = newphonword
                newphon = "".join(phonwords)
                if newphon != phon:
                  assert param != "pagetitle", u"Something wrong, page title should not have -и or similar that needs modification: section %s, phon=%s, newphon=%s" % (k//2, phon, newphon)
                  if pos in ["voc", "inv", "pro"]:
                    pagemsg(u"WARNING: pos=%s may be unstable or inconsistent in handling final -е, please check change of phon=%s to %s in section %s: %s" % (
                      pos, phon, newphon, k//2, unicode(t)))
                  pagemsg("Modified phon=%s to %s in section %s: %s" % (
                    phon, newphon, k//2, unicode(t)))
                  if pos == "none":
                    pagemsg("WARNING: pos=none, should not occur, not modifying phon=%s to %s in section %s: %s" % (
                      phon, newphon, k//2, unicode(t)))
                  else:
                    t.add(param, newphon)

                if pos == "none":
                  pagemsg("WARNING: pos=none, should not occur, not setting pos= in section %s: %s" %
                      (k//2, unicode(t)))
                else:
                  t.add("pos", pos)
                  notes.append("added pos=%s%s" % (pos, override_pos and " (override)" or ""))
                  pagemsg("Replaced %s with %s in section %s%s" % (
                    origt, unicode(t), k//2, override_pos and " (using override)" or ""))
        subsections[k] = unicode(parsed)
      sections[j] = "".join(subsections)

  new_text = "".join(sections)

  def fmt_key_val(key, val):
    if val == 1:
      return "%s" % key
    else:
      return "%s (%s)" % (key, val)

  if new_text != text:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, new_text))
    assert notes
    # Group identical notes together and append the number of such identical
    # notes if > 1, putting 'added pos=X' notes before others, so we get e.g.
    # "added pos=n (2); added pos=a; unstressed -и -> -е (2)" from five
    # original notes.
    # 1. Count items in notes[] and return a key-value list in descending order
    notescount = Counter(notes).most_common()
    # 2. Extract 'added pos=X' items; we put them first; note, descending order
    #    of # of times each note has been seen is maintained
    added_pos = [(x, y) for x, y in notescount if x.startswith("added pos=")]
    # 3. Extract other items
    not_added_pos = [(x, y) for x, y in notescount if not x.startswith("added pos=")]
    # 4. Recreate notes for 'added pos=X', then others
    notes = [fmt_key_val(x, y) for x, y in added_pos]
    notes.extend([fmt_key_val(x, y) for x, y in not_added_pos])

    comment = "; ".join(notes)
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = new_text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser(u"Add pos= to final -е ru-IPA, fix use of phonetic -и/-я")
parser.add_argument('--posfile', help="File containing parts of speech for pages, in the form of part of speech, space, page name, one per line")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

if args.posfile:
  for line in codecs.open(args.posfile, "r", "utf-8"):
    line = line.strip()
    m = re.search(r"^(.*?) (.*)$", line)
    if not m:
      msg("WARNING: Can't parse line: %s" % line)
    else:
      pos, page = m.groups()
      pages_pos[page] = pos

for category in ["Russian lemmas", "Russian non-lemma forms"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)

for page, pos in pages_pos.iteritems():
  msg("Page 000 %s: WARNING: Override for non-existent page, pos=%s" % (
    page, pos))

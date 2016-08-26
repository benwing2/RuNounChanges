#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Add pos= to ru-IPA pronunciations. Also find instances where и/я/ы/а/е̂ has
# been used phonetically in place of е and put back to е.

# FIXME:
#
# 1. (DONE) Go through pages with spaces in them, looking for non-final words
#    with final -и or whatever in place of -е. Fix them.
# 2. (DONE) Remove final ! and ? from page title when looking for final -е.
# 3. (DONE) Recognize prepositions and nnp's
# 4. Handle adding pos=imp to imperatives in -[дт]ься.
# 5. (DONE) Fix handling of adjectival non-lemmas.
# 6. (DONE) Allow control of processing lemmas or non-lemmas.
# 7. (MOSTLY DONE) Proper handling of multiword non-lemmas.

import pywikibot, re, sys, codecs, argparse
from collections import Counter

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru
import runounlib as runoun

pages_pos = {}

# Return True if ARG1 is an accent class or a set of accent classes separated
# by commas.
def arg1_is_stress(arg1):
  if not arg1: return False
  for arg in re.split(",", arg1):
    if not re.search("^[a-f]'?'?$", arg):
      return False
  return True

def split_words(pagename, capture_delims):
  return re.split(u"([ ‿-]+)" if capture_delims else u"[ ‿-]+",
      re.sub("[!?]$", "", pagename))

# For the given multiword noun lemma and ru-noun-table declension template,
# figure out whether each word is declined as a noun, adjective or invariable.
def find_noun_word_types_of_decl(lemma, decl_template, pagemsg):

  words = split_words(lemma, False)

  if unicode(decl_template.name) == "ru-decl-adj":
    per_word_types = []
    for i in xrange(0, len(words) - 1):
      per_word_types.append("inv")
    per_word_types.append("a")
    return per_word_types

  # Split out the arg sets in the declension and check the
  # lemma of each one, taking care to handle cases where there is no lemma
  # (it would default to the page name).

  highest_numbered_param = 0
  for p in decl_template.params:
    pname = unicode(p.name)
    if re.search("^[0-9]+$", pname):
      highest_numbered_param = max(highest_numbered_param, int(pname))

  # Now gather the numbered arguments into arg sets, gather the arg sets into
  # groups of arg sets (one group per word), and gather the info for all
  # words. An arg set is a list of arguments describing a declension,
  # e.g. ["b", u"поро́к", "*"]. There may be multiple arg sets per word;
  # in particular, if a word has a compound declension consisting of two
  # or more declensions separated by "or". Code taken from ru-noun.lua.
  offset = 0
  arg_sets = []
  arg_set = []
  per_word_info = []
  for i in xrange(1, highest_numbered_param + 2):
    end_arg_set = False
    end_word = False
    val = getparam(decl_template, str(i))
    if i == highest_numbered_param + 1 or val in ["_", "-"] or re.search("^join:", val):
      end_arg_set = True
      end_word = True
    elif val == "or":
      end_arg_set = True

    if end_arg_set:
      arg_sets.append(arg_set)
      arg_set = []
      offset = i
      if end_word:
        per_word_info.append(arg_sets)
        arg_sets = []
    else:
      # If the first argument isn't stress, that means all arguments
      # have been shifted to the left one. We want to shift them
      # back to the right one, so we change the offset so that we
      # get the same effect of skipping a slot in the arg set.
      if i - offset == 1 and not arg1_is_stress(val):
        offset -= 1
        arg_set.append("")
      if i - offset > 4:
        pagemsg("WARNING: Too many arguments for argument set: arg %s = %s" %
            (i, (val or "(blank)")))
      arg_set.append(val)

  def get_per_word_info(words, per_word_info):
    per_word_types = []
    for word, arg_sets in zip(words, per_word_info):
      word_types = set()
      for arg_set in arg_sets:
        pagemsg("arg_set: %s" % "|".join(arg_set))
        if len(arg_set) < 3:
          word_types.add("decln")
        elif "$" in arg_set[2]:
          word_types.add("inv")
        elif "+" in arg_set[2]:
          word_types.add("a")
        elif "manual" in arg_set[2]:
          pagemsg("WARNING: Found manually-declined noun in lemma %s, skipping: decl = %s" %
              (lemma, unicode(decl_template)))
          return None
        else:
          word_types.add("decln")
      if len(word_types) > 1:
        pagemsg("WARNING: Found multiple declension types %s for word %s in lemma %s, skipping: decl = %s" %
            (",".join(word_types), word, lemma, unicode(decl_template)))
        return None
      per_word_types.append(list(word_types)[0])
    return per_word_types

  if len(words) != len(per_word_info):
    if len(per_word_info) == 1:
      pos = get_per_word_info(lemma, per_word_info)[0]
      per_word_types = []
      for i in xrange(0, len(words) - 1):
        per_word_types.append("inv")
      per_word_types.append(pos)
      return per_word_types

    pagemsg("WARNING: Lemma %s has %s words but %s words in declension, skipping: decl = %s" %
        (lemma, len(words), len(per_word_info), unicode(decl_template)))
    return None

  return get_per_word_info(words, per_word_info)

# For the given multiword noun lemma (possibly with accents), figure out
# whether each word is declined as a noun, adjective or invariable.
def find_noun_word_types(lemma, pagemsg):
  declpage = pywikibot.Page(site, ru.remove_accents(lemma))

  if not declpage.exists():
    pagemsg("WARNING: Page doesn't exist when looking up declension, skipping")
    return None

  parsed = blib.parse_text(declpage.text)
  decl_templates = []
  for t in parsed.filter_templates():
    tname = unicode(t.name)
    if tname in ["ru-noun-table", "ru-decl-adj"]:
      pagemsg("find_noun_word_types: Found decl template: %s" % unicode(t))
      decl_templates.append(t)

  if not decl_templates:
    pagemsg("WARNING: Found no decl templates, skipping")
    return None

  per_word_types = find_noun_word_types_of_decl(lemma, decl_templates[0],
      pagemsg)
  if not per_word_types:
    return None
  for decl in decl_templates[1:]:
    other_per_word_types = find_noun_word_types_of_decl(lemma, decl, pagemsg)
    if not other_per_word_types:
      return None
    if other_per_word_types != per_word_types:
      pagemsg("WARNING: Found word types %s for decl %s, not same as word types %s for decl %s on same page" %
          (",".join(other_per_word_types), unicode(decl),
           ",".join(per_word_types), unicode(decl_templates[0])))
      return None

  seen_poses = set()
  for t in parsed.filter_templates():
    tname = unicode(t.name)
    if tname == "ru-IPA":
      val = getparam(t, "pos")
      if val:
        seen_poses.add(val)
      else:
        seen_poses.add("unknown")

  return per_word_types, seen_poses

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

  titlewords = split_words(pagetitle, True)
  saw_e = False
  for word in titlewords:
    if word.endswith(u"е") and not ru.is_monosyllabic(word):
      saw_e = True
      break
  if not saw_e:
    pagemsg(u"No possible final unstressed -е in page title, skipping")
    return

  #if (" " in pagetitle or "-" in pagetitle) and not override_pos:
  #  pagemsg(u"WARNING: Space or hyphen in page title and probable final unstressed -е, not sure how to handle yet")
  #  return

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
                  elif re.search(u"([еия]|цы|е̂|[кгхцшжщч]а)" + ru.DOTABOVE + "?$", phonword):
                    pagemsg("Found template that will be modified due to phonword %s, titleword %s (#%s) in section %s: %s" %
                        (phonword, titleword, wordno, k//2, unicode(t)))
                    subsections_with_ru_ipa_to_fix.add(k)
                  elif not re.search(u"[еэѐ][" + ru.AC + ru.GR + ru.CFLEX + ru.DUBGR + "]?$", phonword):
                    pagemsg(u"WARNING: ru-IPA pronunciation word %s (#%s) doesn't end in [еэия] or е̂ or hard sibilant + [ыа] when corresponding titleword %s ends in -е, something wrong in section %s: %s" %
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
          is_lemma = set()
          lemma = set()
          saw_acc = False
          saw_noun_form = False
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
              is_lemma.add(True)
            elif tname in ["ru-noun+", "ru-proper noun+"]:
              for param in t.params:
                if re.search("^[0-9]+$", unicode(param.name)) and "+" in unicode(param.value):
                  pagemsg("Found declined adjectival noun, treating as adjective: %s" % unicode(t))
                  pos.add("a")
                  break
              else:
                pagemsg("Found declined noun: %s" % unicode(t))
                pos.add("n")
              is_lemma.add(True)
            elif tname == "comparative of" and getp("lang") == "ru":
              pagemsg("Found comparative: %s" % unicode(t))
              pos.add("com")
              is_lemma.add(False)
            elif tname == "ru-adv":
              pagemsg("Found adverb: %s" % unicode(t))
              pos.add("adv")
              is_lemma.add(True)
            elif tname == "ru-adj":
              pagemsg("Found adjective: %s" % unicode(t))
              pos.add("a")
              is_lemma.add(True)
            elif tname == "ru-noun form":
              pagemsg("Found noun form: %s" % unicode(t))
              saw_noun_form = True
              is_lemma.add(False)
            elif tname == "head" and getp("1") == "ru":
              if getp("2") == "verb form":
                pagemsg("Found verb form: %s" % unicode(t))
                pos.add("v")
                is_lemma.add(False)
              elif getp("2") in ["adjective form", "participle form"]:
                pagemsg("Found adjective form: %s" % unicode(t))
                pos.add("a")
                is_lemma.add(False)
              elif getp("2") == "noun form":
                pagemsg("Found noun form: %s" % unicode(t))
                saw_noun_form = True
                is_lemma.add(False)
              elif getp("2") == "pronoun form":
                pagemsg("Found pronoun form: %s" % unicode(t))
                pos.add("pro")
                is_lemma.add(False)
              elif getp("2") == "preposition":
                pagemsg("Found preposition: %s" % unicode(t))
                pos.add("p")
                is_lemma.add(True)
              elif getp("2") == "numeral":
                pagemsg("Found numeral: %s" % unicode(t))
                pos.add("num")
                is_lemma.add(True)
              elif getp("2") == "pronoun":
                pagemsg("Found pronoun: %s" % unicode(t))
                pos.add("pro")
                is_lemma.add(True)
            elif tname == "inflection of" and getp("lang") == "ru":
              is_lemma.add(False)
              lemma.add(getp("1"))
              if saw_noun_form:
                inflection_groups = []
                inflection_group = []
                for param in t.params:
                  if param.name in ["1", "2"]:
                    continue
                  val = unicode(param.value)
                  if val == ";":
                    if inflection_group:
                      inflection_groups.append(inflection_group)
                      inflection_group = []
                  else:
                    inflection_group.append(val)
                if inflection_group:
                  inflection_groups.append(inflection_group)
                for igroup in inflection_groups:
                  igroup = set(igroup)
                  is_plural = not not ({"p", "plural"} & igroup)
                  if is_plural and ({"nom", "nominative"} & igroup):
                    pagemsg("Found nominative plural case inflection: %s" % unicode(t))
                    pos.add("nnp")
                  elif {"acc", "accusative"} & igroup:
                    # We use "n" for misc cases, but skip accusative for now,
                    # adding "n" later if we haven't seen nnp to avoid problems
                    # below with the check for multiple pos's (nom pl and acc pl
                    # are frequently the same)
                    saw_acc = True
                  elif not is_plural and (
                      {"pre", "prep", "prepositional"} & igroup):
                    pagemsg("Found prepositional singular case inflection: %s" % unicode(t))
                    pos.add("pre")
                  elif not is_plural and ({"dat", "dative"} & igroup):
                    pagemsg("Found dative singular case inflection: %s" % unicode(t))
                    pos.add("dat")
                  elif not is_plural and ({"voc", "vocative"} & igroup):
                    pagemsg("Found vocative case inflection: %s" % unicode(t))
                    pos.add("voc")
                  else:
                    pos.add("n")
            elif tname == "prepositional singular of" and getp("lang") == "ru":
              pagemsg("Found prepositional singular case inflection: %s" % unicode(t))
              pos.add("pre")
              is_lemma.add(False)
              lemma.add(getp("1"))
            elif tname == "dative singular of" and getp("lang") == "ru":
              pagemsg("Found dative singular case inflection: %s" % unicode(t))
              pos.add("dat")
              is_lemma.add(False)
              lemma.add(getp("1"))
            elif tname == "vocative singular of" and getp("lang") == "ru":
              pagemsg("Found vocative case inflection: %s" % unicode(t))
              pos.add("voc")
              is_lemma.add(False)
              lemma.add(getp("1"))

          if saw_acc and "nnp" not in pos:
            pos.add("n")
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

          # If multiword term or potential adjectival term, can't trust
          # the part of speech coming from the above process
          if (" " in pagetitle or "-" in pagetitle or re.search(u"[ыиео]́?е$", pagetitle)):
            if not is_lemma:
              pagemsg("WARNING: Can't determine whether lemma or not, skipping section")
              continue
            if len(is_lemma) > 1:
              pagemsg("WARNING: Found both lemma and non-lemma parts of speech, skipping section")
              continue
            is_lemma = list(is_lemma)[0]
            if (" " in pagetitle or "-" in pagetitle) and is_lemma:
              pagemsg(u"WARNING: Space or hyphen in lemma page title and probable final unstressed -e, not sure how to handle yet, skipping section")
              continue
            if not lemma:
              pagemsg("WARNING: Non-lemma form and can't determine lemma, skipping section")
              continue
            if len(lemma) > 1:
              pagemsg("WARNING: Found inflections of multiple lemmas, skipping section: %s" %
                  ",".join(lemma))
              continue
            lemma = list(lemma)[0]
            retval = find_noun_word_types(lemma, pagemsg)
            if not retval:
              continue
            word_types, seen_pos_specs = retval
            words = split_words(pagetitle, False)
            assert len(words) == len(word_types)
            modified_word_types = []
            need_to_continue = False
            # FIXME: Should we be using phonetic version of lemma?
            for wordno, (word, ty) in enumerate(zip(words, word_types)):
              if (word.endswith(u"е") and not ru.is_monosyllabic(word) and
                  ty == "inv"):
                if len(seen_pos_specs) > 1:
                  pagemsg(u"WARNING: In multiword term %s, found word %s ending in -е and marked as invariable and lemma has ambiguous pos= params (%s), not sure what to do, skipping section" %
                      (pagetitle, word, ",".join(seen_pos_specs)))
                  need_to_continue = True
                  break
                elif not seen_pos_specs:
                  pagemsg(u"WARNING: In multiword term %s, found word %s ending in -е and marked as invariable and lemma has no pos= params, not sure what to do, skipping section" %
                      (pagetitle, word))
                  need_to_continue = True
                  break
                else:
                  seen_pos_spec = list(seen_pos_specs)[0]
                  seen_poses = re.split("/", seen_pos_spec)
                  if len(seen_poses) == 1:
                    ty = seen_poses[0]
                  elif len(words) != len(seen_poses):
                    pagemsg(u"WARNING: In multiword term %s, found word %s ending in -е and marked as invariable and lemma param pos=%s has wrong number of parts of speech, not sure what to do, skipping section" %
                        (pagetitle, word, seen_pos_spec))
                    need_to_continue = True
                    break
                  else:
                    ty = seen_poses[wordno]
              if ty == "decln":
                modified_word_types.append(pos)
              else:
                modified_word_types.append(ty)
            if need_to_continue:
              continue
            pos = "/".join(modified_word_types)

        # Check whether there's a pronunciation with final -е for a given
        # word. There are some entries that have multiple pronunciations,
        # one with final -е and one with something else, e.g. final -и,
        # and we want to leave those alone with a warning.
        saw_final_e = {}
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
            if getparam(t, "pos"):
              pass # Already output msg
            else:
              phonwords = re.split("([ -]+)", phon)
              if len(phonwords) != len(titlewords):
                pass # Already output message
              else:
                for i in xrange(0, len(phonwords), 2):
                  if re.search(u"е$", phonwords[i]):
                    saw_final_e[i] = True

        # Now modify the templates.
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
                  elif re.search(u"([еия]|цы|е̂|[кгхцшжщч]а)" + ru.DOTABOVE + "?$", lphonword):
                    # Found a template to modify
                    if re.search(u"е" + ru.DOTABOVE + "?$", lphonword):
                      pass # No need to canonicalize
                    else:
                      if saw_final_e.get(i, False):
                        pagemsg(u"WARNING: Found another pronunciation with final -е, skipping: phon=%s (word #%s)" % (
                          phonword, wordno))
                        continue
                      if re.search(u"и" + ru.DOTABOVE + "?$", lphonword):
                        pagemsg(u"phon=%s (word #%s) ends in -и, will modify to -е in section %s: %s" % (phonword, wordno, k//2, unicode(t)))
                        notes.append(u"unstressed -и -> -е")
                      elif re.search(u"е̂$", lphonword):
                        # Make this a warning because we're not sure this is correct
                        pagemsg(u"WARNING: phon=%s (word #%s) ends in -е̂, will modify to -е in section %s: %s" % (phonword, wordno, k//2, unicode(t)))
                        notes.append(u"-е̂ -> -е")
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
                      newphonword = re.sub(u"(?:[ияыа]|е̂)(" + ru.DOTABOVE + "?)$", ur"е\1", phonword)
                      newphonword = re.sub(u"(?:[ИЯЫА]|Е̂)(" + ru.DOTABOVE + "?)$", ur"Е\1", newphonword)
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
parser.add_argument('--cats', default="lemma,nonlemma", help="Categories to do (lemma, nonlemma or comma-separated list)")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.posfile:
  for line in codecs.open(args.posfile, "r", "utf-8"):
    line = line.strip()
    m = re.search(r"^(.*?) (.*)$", line)
    if not m:
      msg("WARNING: Can't parse line: %s" % line)
    else:
      pos, page = m.groups()
      pages_pos[page] = pos

categories = []
for cattype in re.split(",", args.cats):
  if cattype == "lemma":
    categories.append("Russian lemmas")
  elif cattype == "nonlemma":
    categories.append("Russian non-lemma forms")
  else:
    raise RuntimeError("Invalid value %s, should be 'lemma' or 'nonlemma'" %
        cattype)
for category in categories:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)

for page, pos in pages_pos.iteritems():
  msg("Page 000 %s: WARNING: Override for non-existent page, pos=%s" % (
    page, pos))

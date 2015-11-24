#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Fix ru-noun headers to be ru-noun+ and ru-proper noun to ru-proper noun+
# for multiword nouns by looking up the individual declensions of the words.

# Example page:
#
# ==Russian==
#
# ===Pronunciation===
# * {{ru-IPA|са́харная ва́та}}
#
# ===Noun===
# {{ru-noun|[[сахарный|са́харная]] [[вата|ва́та]]|f-in}}
#
# # [[cotton candy]], [[candy floss]], [[fairy floss]]
#
# ====Declension====
# {{ru-decl-noun-see|сахарный|вата}}
#
# [[Category:ru:Foods]]

# FIXME:
#
# 1. (DONE, NEEDS TESTING) Warnings like this should be fixable:
#    Page 99 Дедушка Мороз: WARNING: Can't sub word link [[мороз|Моро́з]] into decl lemma моро́з
# 2. (DONE) This warning should be fixable:
#    Page 756 десертное вино: WARNING: case nom_sg, existing forms [[десе́ртный|десе́ртное]] [[вино́]] not same as proposed [[десертный|десе́ртное]] [[вино́]]
# 3. (DONE, DEFINITELY NEEDS TESTING) Plural nouns
# 4. (DONE, NEEDS TESTING) Multiple inflected nouns, esp. in hyphenated compounds
# 5. (DONE) Don't choke when found notes= as long as there's only one
#    (choke if multiple because the footnote symbols might be duplicated),
#    instead issue warning

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam

import rulib as ru
import runounlib as runoun

site = pywikibot.Site()

def msg(text):
  print text.encode("utf-8")

def errmsg(text):
  print >>sys.stderr, text.encode("utf-8")

# [singular ending, plural ending, gender, requires special case (1)]
pl_data = [
    ["", u"ы", "m", False],
    ["", u"и", "m", False],
    [u"ь", u"и", "mf", False],
    [u"й", u"и", "m", False],
    ["", u"а", "m", True],
    [u"а", u"ы", "f", False],
    [u"а", u"и", "f", False],
    [u"я", u"и", "f", False],
    [u"о", u"а", "n", False],
    [u"е", u"а", "n", False],
    [u"е", u"я", "n", False],
    [u"о", u"и", "n", True]
]

consonant_re = u"[бдфгклмнпрствхзшщчжц]"

particles = [
  # List of prepositions and particles, from ru-pron.lua
  u"по", u"в", u"на", u"до",
  u"без", u"близ", u"в", u"во", u"до",
  u"из-под", u"из-за", u"за", u"из", u"изо",
  u"к", u"ко", u"меж", u"на", u"над", u"надо", u"о", u"об", u"обо", u"от",
  u"по", u"под", u"подо", u"пред", u"предо", u"при", u"про", u"перед", u"передо",
  u"через", u"с", u"со", u"у", u"не",
  # Others
  u"и", u"де"
  ]

# List of words where we use the specified declension, to deal with cases
# where there are multiple declensions; we have to be careful here to make
# sure more than one declension isn't actually used in different lemmas
use_given_decl = {u"туз": u"{{ru-noun-table|b|a=a}}",
    u"род": u"{{ru-noun-table|e}}",
    u"лев": u"{{ru-noun+|b||*|a=an}}",
    u"ключ": u"{{ru-noun-table|b}}",
}

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    if verbose:
      pagemsg("Expanding text: %s" % tempcall)
    result = site.expand_text(tempcall, title=pagetitle)
    if verbose:
      pagemsg("Raw result is %s" % result)
    if result.startswith('<strong class="error">'):
      result = re.sub("<.*?>", "", result)
      pagemsg("WARNING: Got error: %s" % result)
      return False
    return result

  origtext = page.text
  parsed = blib.parse_text(origtext)

  # Find the declension arguments for LEMMA and inflected form INFL,
  # the WORDINDth word in the expression. Return value is a tuple of
  # four items: a list of (NAME, VALUE) tuples for the arguments, whether
  # the word is an adjective, the value of n= (if given), and the value
  # of a= (if given).
  def find_decl_args(lemma, infl, wordind):
    declpage = pywikibot.Page(site, lemma)
    if ru.remove_accents(infl) == lemma:
      wordlink = "[[%s]]" % infl
    else:
      wordlink = "[[%s|%s]]" % (lemma, infl)

    if not declpage.exists():
      if re.search(u"(ий|ый|ой)$", lemma):
        pagemsg("WARNING: Page doesn't exist, assuming word #%s adjectival: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
        return [("1", wordlink), ("2", "+")], True, None, None
      else:
        pagemsg("WARNING: Page doesn't exist, can't locate decl for word #%s, skipping: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
        return None
    parsed = blib.parse_text(declpage.text)
    decl_templates = []
    headword_templates = []
    decl_z_templates = []
    for t in parsed.filter_templates():
      if unicode(t.name) in ["ru-noun-table", "ru-decl-adj"]:
        decl_templates.append(t)
      if unicode(t.name) in ["ru-noun", "ru-proper noun"]:
        headword_templates.append(t)
      if unicode(t.name) in ["ru-decl-noun-z"]:
        decl_z_templates.append(t)

    if not decl_templates:
      if decl_z_templates:
        # {{ru-decl-noun-z|звезда́|f-in|d|ё}}
        # {{ru-decl-noun-z|ёж|m-inan|b}}
        if len(decl_z_templates) > 1:
          pagemsg("WARNING: Multiple decl-z templates during decl lookup for word #%s, skipping: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
          return None
        else:
          decl_z_template = decl_z_templates[0]
          decl_template = blib.parse_text("{{ru-noun-table}}")
          decl_template.add("1", getparam(decl_z_template, "3"))
          decl_template.add("2", getparam(decl_z_template, "1"))
          zgender_anim = getparam(decl_z_template, "2")
          m = re.search(r"^([mfn])-(an|in|inan)$", zgender_anim)
          if not m:
            pagemsg("Unable to recognize z-decl gender/anim spec for word #%s, skipping: spec=%s, lemma=%s, infl=%s" %
                (wordind, zgender_anim, lemma, infl))
            return None
          zgender, zanim = m.groups()
          zspecial = zgender + re.sub(u"ё", u";ё", getparam(decl_z_template, "4"))
          # FIXME, properly we should check whether the gender is actually
          # needed and leave it off if not
          decl_template.add("3", zspecial)
          if zanim == "an":
            decl_template.add("a", "an")
          elif zanim == "inan":
            # FIXME, properly we should convert to either ai or ia depending
            # on the order of genders in the headword; this will have to
            # be a task for the script that converts z-decl to regular decl
            decl_template.add("a", "bi")
          # FIXME, save/convert overrides; but don't seem to be any in the
          # few words with zdecl (звезда, ёж)
          params_to_preserve = []
          for param in decl_z_template.params:
            name = unicode(param.name)
            if name not in ["1", "2", "3", "4"]:
              pagemsg("WARNING: Found named or extraneous numbered params in z-decl for word #%s, can't handle yet, skipping: %s, lemma=%s, infl=%s" %
                  (wordind, unicode(decl_z_template), lemma, infl))
              return None
          decl_templates = [decl_template]

      elif "[[Category:Russian indeclinable nouns]]" in declpage.text or [
        x for x in headword_templates if getparam(x, "3") == "-"]:
        return [("1", wordlink), ("2", "$")], False, None, None
      else:
        pagemsg("WARNING: No decl template during decl lookup for word #%s, skipping: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
        return None

    if len(decl_templates) == 1:
      decl_template = decl_templates[0]
    else:
      # Multiple decl templates
      for t in decl_templates:
        if unicode(t.name) == "ru-decl-adj" and re.search(u"(ий|ый|ой)$", lemma):
          pagemsg("WARNING: Multiple decl templates during decl lookup for word #%s, assuming adjectival: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
          decl_template = t
          break
      else:
        if lemma in use_given_decl:
          overriding_decl = use_given_decl[lemma]
          pagemsg("WARNING: Multiple decl templates during decl lookup for word #%s and not adjectival, using overriding declension %s: lemma=%s, infl=%s" %
              (wordind, overriding_decl, lemma, infl))
          decl_template = blib.parse_text(overriding_decl).filter_templates()[0]
        else:
          pagemsg("WARNING: Multiple decl templates during decl lookup for word #%s and not adjectival, skipping: lemma=%s, infl=%s" %
              (wordind, lemma, infl))
          return None

    if unicode(decl_template.name) == "ru-decl-adj":
      if re.search(ur"\bь\b", getparam(decl_template, "2")):
        return [("1", wordlink), ("2", u"+ь")], True, None, None
      else:
        return [("1", wordlink), ("2", "+")], True, None, None

    # ru-noun-table
    assert unicode(decl_template.name) == "ru-noun-table"

    # Split out the arg sets in the declension and check the
    # lemma of each one, taking care to handle cases where there is no lemma
    # (it would default to the page name).

    highest_numbered_param = 0
    for p in decl_template.params:
      pname = unicode(p.name)
      if re.search("^[0-9]+$", pname):
        highest_numbered_param = max(highest_numbered_param, int(pname))

    # Now gather the numbered arguments into arg sets. Code taken from
    # ru-noun.lua.
    offset = 0
    arg_sets = []
    arg_set = []
    for i in xrange(1, highest_numbered_param + 2):
      end_arg_set = False
      val = getparam(decl_template, str(i))
      if i == highest_numbered_param + 1:
        end_arg_set = True
      elif val == "_" or val == "-" or re.search("^join:", val):
        pagemsg("WARNING: Found multiword decl during decl lookup for word #%s, skipping: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
        return None
      elif val == "or":
        end_arg_set = True

      if end_arg_set:
        arg_sets.append(arg_set)
        arg_set = []
        offset = i
      else:
        arg_set.append(val)

    canon_infl = ru.remove_accents(infl).lower()
    canon_lemma = lemma.lower()
    ispl = False
    need_sc1 = False
    found_gender = None
    if canon_infl != canon_lemma:
      for sgend, plend, gender, is_sc1 in pl_data:
        if sgend:
          check_sgend = sgend
        else:
          check_sgend = consonant_re
        if re.search(check_sgend + "$", canon_lemma) and canon_infl == re.sub(sgend + "$", plend, canon_lemma):
          ispl = True
          found_gender = gender
          need_sc1 = is_sc1
          break
      else:
        pagemsg("WARNING: For word#%s, inflection not same as lemma, not recognized as plural, can't handle, skipping: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
        return None

    # Substitute the wordlink for any lemmas in the declension.
    # If plural, also add gender and verify special case (1) as necessary.
    # Concatenate all the numbered params, substituting the wordlink into
    # the lemma as necessary.
    numbered_params = []
    for arg_set in arg_sets:
      lemma_arg = 0
      if len(arg_set) > 0 and runoun.arg1_is_stress(arg_set[0]):
        lemma_arg = 1
      if len(arg_set) <= lemma_arg:
        arg_set.append("")
      if not arg_set[lemma_arg] or arg_set[lemma_arg].lower() == infl.lower() or (
          ru.is_monosyllabic(infl) and ru.remove_accents(arg_set[lemma_arg]).lower() ==
          ru.remove_accents(infl).lower()):
        arg_set[lemma_arg] = wordlink
      else:
        pagemsg("WARNING: Can't sub word link %s into decl lemma %s%s" % (
          wordlink, arg_set[lemma_arg], ispl and ", skipping" or ""))
        if ispl:
          return None

      if ispl:
        # Add the gender
        if len(arg_set) <= lemma_arg + 1:
          arg_set.append("")
        declarg = arg_set[lemma_arg + 1]

        # First, sub in gender
        m = re.search("(3f|[mfn])", declarg)
        if found_gender == "mf":
          if not m:
            pagemsg(u"WARNING: For singular in -ь and plural in -и, need gender in singular and don't have it, word #%s, skipping: lemma=%s, infl=%s" %
                (wordinfl, lemma, infl))
            return None
          decl_gender = m.group(1)
          if decl_gender == "n":
            pagemsg(u"WARNING: For singular in -ь and plural in -и, can't have neuter gender for word #%s, skipping: lemma=%s, infl=%s" %
                (wordinfl, lemma, infl))
            return None
          elif decl_gender in ["m", "3f"]:
            pagemsg(u"Singular in -ь and plural in -и, already found gender %s in decl for word #%s, taking no action: lemma=%s, infl=%s" %
                (decl_gender, wordind, lemma, infl))
          else:
            assert gender == "f"
            pagemsg(u"Singular in -ь and plural in -и, replacing f with 3f so singular will be recognized for word #%s: lemma=%s, infl=%s" %
                (wordind, lemma, infl))
            declarg = re.sub("f", "3f", declarg, 1)
        else:
          if m:
            decl_gender = m.group(1)
            if decl_gender == found_gender:
              pagemsg("Already found gender %s in decl for word #%s, taking no action: lemma=%s, infl=%s" %
                  (found_gender, wordind, lemma, infl))
            else:
              pagemsg("WARNING: Found wrong gender %s in decl for word #%s, forcibly replacing with lemma-form-derived gender %s: lemma=%s, infl=%s" %
                  (decl_gender, wordind, found_gender, lemma, infl))
              declarg = re.sub("(3f|[mfn])", found_gender, declarg, 1)
          else:
            pagemsg("No gender in decl for word #%s, adding gender %s: lemma=%s, infl=%s" %
                (wordind, found_gender, lemma, infl))
            declarg = found_gender + decl_arg

        # Now check special case 1
        if need_sc1 != ("(1)" in declarg):
          if need_sc1:
            pagemsg("Irregular plural calls for special case (1), but not present in decl arg for word #%s, skipping: declarg=%s, lemma=%s, infl=%s" % (
              wordind, declarg, lemma, infl))
            return None
          else:
            pagemsg("Special case (1) present in decl arg but plural for word #%s is regular, skipping: declarg=%s, lemma=%s, infl=%s" % (
              wordind, declarg, lemma, infl))
            return None

      if numbered_params:
        numbered_params.append("or")
      numbered_params.extend(arg_set)

    # Now gather all params, including named ones.
    params = []
    params.extend((str(i+1), val) for i, val in zip(xrange(len(numbered_params)), numbered_params))
    num = None
    anim = None
    for p in decl_template.params:
      pname = unicode(p.name)
      val = unicode(p.value)
      if pname == "a":
        anim = val
      elif pname == "n":
        num = val
      elif pname == "notes":
        params.append((pname, val))
      elif pname == "title":
        pagemsg("WARNING: Found explicit title= for word #%s, ignoring: lemma=%s, infl=%s, title=%s" %
            (wordind, lemma, infl, val))
      elif re.search("^[0-9]+$", pname):
        pass
      else:
        pname += str(wordind)
        params.append((pname, val))

    return params, False, num, anim


  headword_template = None
  see_template = None
  for t in parsed.filter_templates():
    tname = unicode(t.name)
    if tname == "ru-decl-noun-see":
      if see_template:
        pagemsg("WARNING: Multiple ru-decl-noun-see templates, skipping")
        return
      see_template = t
    if tname in ["ru-noun+", "ru-proper noun+"]:
      pagemsg("Found %s, skipping" % tname)
      return
    if tname in ["ru-noun", "ru-proper noun"]:
      if headword_template:
        pagemsg("WARNING: Multiple ru-noun or ru-proper noun templates, skipping")
        return
      headword_template = t

  if not headword_template:
    pagemsg("WARNING: Can't find headword template, skipping")
    return

  pagemsg("Found headword template: %s" % unicode(headword_template))

  headword_is_proper = unicode(headword_template.name) == "ru-proper noun"

  if getparam(headword_template, "3") == "-" or "[[Category:Russian indeclinable nouns]]" in page.text:
    pagemsg("WARNING: Indeclinable noun, skipping")
    return

  headword_trs = blib.process_arg_chain(headword_template, "tr", "tr")
  if headword_trs:
    pagemsg("WARNING: Found headword manual translit, skipping: %s" %
        ",".join(headword_trs))
    return

  headword = getparam(headword_template, "1")
  if "-" in headword:
    pagemsg("WARNING: Can't handle hyphens in headword, yet, skipping")
    return
  for badparam in ["head2", "gen2", "pl2"]:
    val = getparam(headword_template, badparam)
    if val:
      pagemsg("WARNING: Found extra param, can't handle, skipping: %s=%s" % (
        badparam, val))
      return

  # Here we use a capturing split, and treat what we want to capture as
  # the splitting text, backwards from what you'd expect. The separators
  # will fall at 0, 2, ... and the headwords as 1, 3, ... There will be
  # an odd number of items, and the first and last should be empty.
  headwords_separators = re.split(r"(\[\[.*?\]\]|[^ \-]+)", headword)
  if headwords_separators[0] != "" or headwords_separators[-1] != "":
    pagemsg("WARNING: Found junk at beginning or end of headword, skipping")
    return
  headwords = []
  # Separator at index 0 is the separator that goes after the first word
  # and before the second word.
  separators = []
  wordind = 0
  # FIXME, Here we try to handle hyphens, but we'll still have problems with
  # words like изба́-чита́льня with conjoined nouns, both inflected, because
  # we assume only one inflected noun (should be fixable without too much
  # work). We'll also have problems with e.g. пистолет-пулемёт Томпсона,
  # because the words are linked individually but the ru-decl-noun-see
  # has пистолет-пулемёт given as a single entry. We have a check below
  # to try to catch this case, because no inflected nouns will show up.
  for i in xrange(1, len(headwords_separators), 2):
    hword = headwords_separators[i]
    separator = headwords_separators[i+1]
    if separator != " " and separator != "-":
      pagemsg("WARNING: Separator after word #%s isn't a space or hyphen, can't handle: word=<%s>, separator=<%s>" %
          (wordind + 1, hword, separator))
      return
    headwords.append(hword)
    separators.append(separator)

  pagemsg("Found headwords: %s" % " @@ ".join(headwords))

  # Get headword genders (includes animacy and number)
  genders = blib.process_arg_chain(headword_template, "2", "g")
  genders_include_pl = len(x for x in genders if re.search(r"\bp\b")) > 0

  # Extract lemmas and inflections for each word in headword
  lemmas_infls = []
  saw_unlinked_word = False
  for word in headwords:
    m = re.search(r"^\[\[([^|]+)\|([^|]+)\]\]$", word)
    if m:
      lemma, infl = m.groups()
      lemma = ru.remove_accents(re.sub("#Russian$", "", lemma))
    else:
      m = re.search(r"^\[\[([^|]+)\]\]$", word)
      if m:
        infl = m.group(1)
      else:
        infl = word
        saw_unlinked_word = True
      lemma = ru.remove_accents(infl)
    lemmas_infls.append((lemma, infl))

  if see_template:
    pagemsg("Found decl-see template: %s" % unicode(see_template))
    inflected_words = set(ru.remove_accents(blib.remove_links(unicode(x.value)))
        for x in see_template.params)
  else:
    # Try to figure out which words are inflected and which words aren't
    pagemsg("No ru-decl-noun-see template, inferring which headword words are inflected")
    if saw_unlinked_word:
      pagemsg("WARNING: Unlinked word(s) in headword, skipping: %s" % headword)
      return
    inflected_words = set()
    saw_noun = False
    reached_uninflected = False
    wordind = 0
    for word, lemmainfl in zip(headwords, lemmas_infls):
      wordind += 1
      is_inflected = False
      lemma, infl = lemmainfl
      canon_infl = ru.remove_accents(infl).lower()
      canon_lemma = lemma.lower()
      if re.search(u"(ый|ий|ой)$", lemma):
        if re.search(u"(ый|ий|о́й|[ая]́?я|[ое]́?е|[ыи]́?е)$", infl):
          is_inflected = True
          pagemsg("Assuming word #%s is adjectival, inflected: lemma=%s, infl=%s" %
              (wordind, lemma, infl))
          if saw_noun:
            pagemsg("WARNING: Word #%s is adjectival inflected and follows inflected noun: lemma=%s, infl=%s" %
                (wordind, lemma, infl))
        else:
          pagemsg("Assuming word #%s is adjectival, uninflected: lemma=%s, infl=%s" %
              (wordind, lemma, infl))
      elif canon_lemma == canon_infl and canon_lemma not in particles:
        is_inflected = True
        pagemsg("Assuming word #%s is noun, inflected: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
        if saw_noun:
          pagemsg("WARNING: Saw second apparently inflected noun at word #%s, skipping: lemma=%s, infl=%s" %
              (wordind, lemma, infl))
          return
        else:
          saw_noun = True
      else:
        # FIXME, be smarter about nouns conjoined with и, e.g. Адам и Ева,
        # (might not be worth it, only five such nouns)
        if genders_include_pl and not_saw_noun and not reached_uninflected:
          # Check for plural inflection
          for sgend, plend, gender, is_sc1 in pl_data:
            if sgend:
              check_sgend = sgend
            else:
              check_sgend = consonant_re
            if re.search(check_sgend + "$", canon_lemma) and canon_infl == re.sub(sgend + "$", plend, canon_lemma):
              pagemsg("Assuming word #%s is plural noun, inflected: lemma=%s, infl=%s" %
                  (wordind, lemma, infl))
              saw_noun = True
              is_inflected = True
              break
        if not is_inflected:
          pagemsg("Assuming word #%s is non-adjectival, uninflected: lemma=%s, infl=%s" %
              (wordind, lemma, infl))
          if not saw_noun:
            pagemsg("WARNING: No inflected noun in headword, skipping: %s" %
                headword)
            return
      if is_inflected:
        if reached_uninflected:
          pagemsg("WARNING: Word #%s is apparently inflected and follows uninflected words, something might be wrong (or could be accusative after preposition), skipping: lemma=%s, infl=%s" %
                (wordind, lemma, infl))
          # FIXME, compile list where this is allowed
          return
        inflected_words.add(lemma)
      else:
        reached_uninflected = True
        if lemma in inflected_words:
          pagemsg("WARNING: Lemma appears both in inflected and uninflected words, can't handle skipping: lemma=%s (infl=%s at second appearance at word#%s)" %
              (lemma, infl, wordind))

  params = []
  saw_noun = False
  overall_num = None
  overall_anim = None

  wordind = 0
  offset = 0
  decl_notes = []
  for word, lemmainfl in zip(headwords, lemmas_infls):
    wordind += 1
    lemma, infl = lemmainfl
    # If not first word, add _ separator between words
    if wordind > 1:
      if separators[wordind - 2] == "-":
        separator = "-"
      elif separators[wordind - 2] == " ":
        separator = "_"
      else:
        pagemsg("WARNING: Something wrong, separator for word #%2 isn't space or hyphen: <%s>" %
            separators[wordind - 2])
        return
      params.append((str(offset + 1), separator))
      offset += 1

    if lemma in inflected_words:
      pagemsg("Looking up declension for lemma %s, infl %s" % (lemma, infl))
      retval = find_decl_args(lemma, infl, wordind)
      if not retval:
        pagemsg("WARNING: Can't get declension for %s, skipping" % headword)
        return
      wordparams, isadj, num, anim = retval
      num_numbered_params = 0
      if not isadj:
        if saw_noun:
          if wordind == 2 and len(headwords) == 2 and separator == "-":
            pagemsg("WARNING: Found apparent coordinate noun headword A-B, using first noun for overall num and anim, please check")
          elif see_template:
            pagemsg("WARNING: Multiple inflected nouns with ru-decl-noun-see template, allowing but please check")
          else:
            pagemsg("WARNING: Multiple inflected nouns without ru-decl-noun-see template, can't handle, skipping")
            return
        else:
          overall_num = num
          overall_anim = anim
          saw_noun = True
      for name, val in wordparams:
        if name == "notes":
          decl_notes.append(val)
        else:
          if re.search("^[0-9]+$", name):
            name = str(int(name) + offset)
            num_numbered_params += 1
          params.append((name, val))
      offset += num_numbered_params

    else:
      # Invariable
      if ru.is_unstressed(infl):
        word = "*" + word
      if infl == u"и":
        pagemsg(u"WARNING: Found и, check number args")
      params.append((str(offset + 1), word))
      params.append((str(offset + 2), "$"))
      offset += 2

  if len(decl_notes) > 1:
    pagemsg("WARNING: Found multiple notes=, can't handle, skipping: notes=%s" %
        " // ".join("<%s>" % x for x in decl_notes))
    return
  elif len(decl_notes) == 1:
    pagemsg("WARNING: Found notes=, need to check: notes=<%s>" % decl_notes[0])
    params.append(("notes", decl_notes[0]))
  if not saw_noun:
    pagemsg(u"WARNING: No inflected nouns, something might be wrong (e.g. the пистоле́т-пулемёт То́мпсона problem), can't handle, skipping")
    return

  if overall_anim in ["i", "in", "inan"] or not overall_anim:
    overall_anim = "in"
  elif overall_anim in ["a", "an", "anim"]:
    overall_anim = "an"
  elif overall_anim in ["b", "bi", "bian", "both"]:
    overall_anim = "bi"

  saw_in = -1
  saw_an = -1
  for i,g in enumerate(genders):
    if re.search(r"\bin\b", g) and saw_in < 0:
      saw_in = i
    if re.search(r"\ban\b", g) and saw_an < 0:
      saw_an = i
  if saw_in >= 0 and saw_an >= 0 and saw_in < saw_an:
    headword_anim = "ia"
  elif saw_in >= 0 and saw_an >= 0:
    headword_anim = "ai"
  elif saw_an >= 0:
    headword_anim = "an"
  elif saw_in >= 0:
    headword_anim = "in"
  else:
    headword_anim = overall_anim

  if overall_anim != headword_anim:
    pagemsg("WARNING: Overriding decl anim %s with headword anim %s" % (
      overall_anim, headword_anim))
  if headword_anim and headword_anim != "in":
    params.append(("a", headword_anim))

  if overall_num:
    overall_num = overall_num[0:1]
    canon_nums = {"s":"sg", "p":"pl", "b":"both"}
    if overall_num in canon_nums:
      overall_num = canon_nums[overall_num]
    else:
      pagemsg("WARNING: Bogus value for overall num in decl, skipping: %s" % overall_num)
      return
    if headword_is_proper:
      plval = getparam(headword_template, "4")
      if plval and plval != "-":
        if overall_num != "both":
          pagemsg("WARNING: Proper noun is apparently sg/pl but main noun not, skipping: %s" %
              headword)
          return
      elif overall_num == "both":
        pagemsg("WARNING: Proper noun has sg/pl main noun underlying it, assuming singular: %s" %
            headword)
        overall_num = None
      elif overall_num == "sg":
        overall_num = None
    if overall_num:
      params.append(("n", overall_num))

  generate_template = (blib.parse_text("{{ru-generate-noun-args}}").
      filter_templates()[0])
  for name, value in params:
    generate_template.add(name, value)
  proposed_template_text = unicode(generate_template)
  if headword_is_proper:
    proposed_template_text = re.sub(r"^\{\{ru-generate-noun-args",
        "{{ru-proper noun+", proposed_template_text)
  else:
    proposed_template_text = re.sub(r"^\{\{ru-generate-noun-args",
        "{{ru-noun+", proposed_template_text)
  proposed_decl_text = re.sub(r"^\{\{ru-generate-noun-args",
        "{{ru-noun-table", unicode(generate_template))

  def pagemsg_with_proposed(text):
    pagemsg("Proposed new template (WARNING, omits explicit gender and params to preserve from old template): %s" % proposed_template_text)
    pagemsg(text)

  if headword_is_proper:
    generate_template.add("ndef", "sg")
  generate_result = expand_text(unicode(generate_template))
  if not generate_result:
    pagemsg_with_proposed("WARNING: Error generating noun args, skipping")
    return
  args = ru.split_generate_args(generate_result)

  # This will check number mismatch (and animacy mismatch, but that shouldn't
  # occur as we've taken the animacy directly from the headword)
  new_genders = runoun.check_old_noun_headword_forms(headword_template, args,
      subpagetitle, pagemsg_with_proposed)
  if new_genders == None:
    return None

  orig_headword_template = unicode(headword_template)
  params_to_preserve = runoun.fix_old_headword_params(headword_template,
      params, new_genders, pagemsg_with_proposed)
  if params_to_preserve == None:
    return None

  headword_template.params.extend(params_to_preserve)

  notes = []
  ru_noun_changed = 0
  ru_proper_noun_changed = 0
  if unicode(headword_template.name) == "ru-noun":
    headword_template.name = "ru-noun+"
    notes.append("convert multi-word ru-noun to ru-noun+ by looking up decls")
  else:
    headword_template.name = "ru-proper noun+"
    notes.append("convert multi-word ru-proper noun to ru-proper noun+ by looking up decls")

  pagemsg("Replacing headword %s with %s" % (orig_headword_template, unicode(headword_template)))

  newtext = unicode(parsed)
  if not see_template:
    if "==Declension==" in newtext:
      pagemsg("WARNING: No ru-decl-noun-see template, but found declension section, not adding new declension, proposed declension follows: %s" %
          proposed_decl_text)
    else:
      nounsecs = re.findall("^===(?:Noun|Proper noun)===$", newtext, re.M)
      if len(nounsecs) == 0:
        pagemsg("WARNING: Found no noun sections, not adding new declension, proposed declension follows: %s" %
            proposed_decl_text)
      elif len(nounsecs) > 1:
        pagemsg("WARNING: Found multiple noun sections, not adding new declension, proposed declension follows: %s" %
            proposed_decl_text)
      else:
        text = newtext
        # Sub in after Noun or Proper noun section, before a following section
        # (====Synonyms====) or a wikilink ([[pl:гонка вооружений]]).
        newtext = re.sub(r"^(===(?:Noun|Proper noun)===$.*?)^(==|\[\[)",
            r"\1====Declension====\n%s\n\n" % proposed_decl_text, 1, re.M|re.S)
        if text == newtext:
          pagemsg("WARNING: Something wrong, can't sub in new declension, proposed declension follows: %s" %
              proposed_decl_text)
        else:
          pagemsg("Subbed in new declension: %s" % proposed_decl_text)
          notes.append("create declension from headword")
          if verbose:
            pagemsg("Replaced <%s> with <%s>" % text, newtext)

  comment = "; ".join(notes)
  if save:
    pagemsg("Saving with comment = %s" % comment)
    page.text = newtext
    page.save(comment=comment)
  else:
    pagemsg("Would save with comment = %s" % comment)


parser = argparse.ArgumentParser(description="Convert ru-noun to ru-noun+, ru-proper noun to ru-proper noun+ for multiword nouns")
parser.add_argument('start', help="Starting page index", nargs="?")
parser.add_argument('end', help="Ending page index", nargs="?")
parser.add_argument('--save', action="store_true", help="Save results")
parser.add_argument('--verbose', action="store_true", help="More verbose output")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for pos in ["nouns", "proper nouns"]:
  for refpage in ["Template:tracking/ru-headword/space-in-headword/%s" % pos,
      "Template:tracking/ru-headword/hyphen-no-space-in-headword/%s" % pos]:
    msg("PROCESSING REFERENCES TO: %s" % refpage)
    for i, page in blib.references(refpage, start, end):
      msg("Page %s %s: Processing" % (i, unicode(page.title())))
      process_page(i, page, args.save, args.verbose)

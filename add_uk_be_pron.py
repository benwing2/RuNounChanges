#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
import difflib
import unicodedata
from collections import Counter

import blib
from blib import getparam, rmparam, msg, site

import belib
import uklib
from belib import AC, GR
import ru_reverse_translit

# Original comment from Lua:
# [words which will be treated as accentless (i.e. their vowels will be
# reduced), and which will liaise with a preceding or following word;
# this will not happen if the words have an accent mark, cf.
# по́ небу vs. по не́бу, etc.]
# We use these lists to determine whether to auto-accent monosyllabic words.
accentless = {
  # class 'pre': particles that join with a following word
  'pre':set([u'без', u'близ', u'в', u'во', u'да', u'до',
    u'за', u'из', u'из-под', u'из-за', u'изо', u'к', u'ко', u'меж',
    u'на', u'над', u'надо', u'не', u'ни', u'об', u'обо', u'от', u'ото',
    u'перед', u'передо', u'по', u'под', u'подо', u'пред', u'предо', u'при', u'про',
    u'с', u'со', u'у', u'через']),
  # class 'prespace': particles that join with a following word, but only
  #   if a space (not a hyphen) separates them; hyphens are used here
  #   to spell out letters, e.g. а-эн-бэ́ for АНБ (NSA = National Security
  #   Agency) or о-а-э́ for ОАЭ (UAE = United Arab Emirates)
  'prespace':set([u'а', u'о']),
  # class 'post': particles that join with a preceding word
  'post':set([u'бы', u'б', u'ж', u'же', u'ли', u'либо', u'ль', u'ка',
    u'нибудь', u'тка']),
  # class 'posthyphen': particles that join with a preceding word, but only
  #   if a hyphen (not a space) separates them
  'posthyphen':set([u'то']),
}

skip_pages = [
    u"^б/у$",
    u"^в/о$",
    u"^г-ж",
    u"^г-н",
    u"^е$",
    u"^и$",
    # FIXME! Script wrongly removes the stressed form in the next three;
    # it should notice that the word is normally unstressed and not do this;
    # for the first one, should also notice that it's actually two words
    u"^м-да$",
    u"^на$",
    u"^не$",
    u"^промеж$", # has unstressed multisyllabic form
    u"^ы$",
    u"^я$"
]

# Pages where we allow unaccented multisyllabic words in the pronunciation.
# NOTE: This isn't actually necessary for бальза́м.* на́ душу because we
# rewrite it in manual_pronun_mapping to have ‿ in на́‿душу, which gets
# treated as a single word for unaccented-checking.
allow_unaccented = [
    u"^бальзам.* на душу"
]

applied_manual_pronun_mappings = set()

# Used when the automatic headword->pronun mapping fails for non-lemma forms
# (typically, where there's a secondary stress along with either multiword
# phrases or accent type c/d/e/f or accent type b with masculine nouns;
# basically, where there is a non-identity pronunciation mapping and the stem
# of the headword, including acute accents, isn't a possible beginning
# substring of the non-lemma form, and reverse-translit from the translit
# won't generate the right pronunciation [reverse-translit will correctly
# handle most cases where е is pronounced э]). Each tuple is of the form
# (HEADWORD, SUB) where HEADWORD is a regex and SUB is either a single string
# to substitute in the regex or a list of such strings. (In place of a single
# string can be a three-entry type of (SUB, TEXTBEFORE, TEXTAFTER) for
# cases where there is surrounding text such as {{i|romantic meeting}} or
# {{a|Moscow}}). The entries included are those that won't be handled right;
# for single words with secondary accents, these are typically for the
# non-lemma forms that don't have the same stress as the headword (e.g.
# (u"^авиакорпус", u"а̀виакорпус") handles plurals like а̀виакорпусы́,
# а̀виакорпусо́в vs. headword авиако́рпус.
#
# To find new cases to add, look for the message
# "WARNING: Would save and unable to match mapping" and check whether the
# pronunciation that is generated automatically is correct.
manual_pronun_mapping = [
]

allowed_l3_headings_when_multiple_etyms = [
  "References", "Further reading"
]

# Make sure there are two trailing newlines
def ensure_two_trailing_nl(text):
  return re.sub(r"\n*$", r"\n\n", text)

def contains_latin(text):
  return re.search(u"[0-9a-zščžáéíóúýàèìòùỳɛě]", text.lower())

def contains_non_cyrillic_non_latin(text):
  # 0300 = grave, 0301 = acute, 0302 = circumflex, 0308 = diaeresis,
  # 0307 = dot-above, 0323 = dot-below
  # We also include basic punctuation as well as IPA chars ɣ ɕ ʑ, which
  # we allow in Cyrillic pronunciation; we also allow ()_/‿, which have
  # significance as phonological characters. FIXME: We allow Latin h as a
  # substitute for ɣ, we should allow it here and not have it trigger
  # contains_latin() by itself.
  return re.sub(ur"[\u0300\u0301\u0302\u0308\u0307\u0323 \-,.?!()_/‿ɣɕʑЀ-ԧꚀ-ꚗ'a-zščžáéíóúýàèìòùỳɛě]", "", text.lower()) != ""

def canonicalize_monosyllabic_pronun(pronun):
  # Do nothing if there are multiple words
  if pronun not in accentless['pre'] and not re.search(r"[\s\-]", pronun):
    return com.add_monosyllabic_stress(pronun)
  else:
    return pronun

def remove_list_duplicates(l):
  newl = []
  for x in l:
    if x not in newl:
      newl.append(x)
  return newl

def get_first_param(t):
  lang = getparam(t, "lang")
  if lang:
    if lang == args.lang:
      return "1"
    else:
      return None
  else:
    if getparam(t, "1") == args.lang:
      return "2"
    else:
      return None

# Get a list of headword pronuns.
def get_headword_pronuns(parsed, pagetitle, pagemsg, expand_text):
  # Get the headword pronunciation(s)
  headword_pronuns = []

  # Append headword to headword_pronuns, possibly with translit.
  # If translit is present, split on commas to handle cases like
  # {{ru-noun form|а́бвера|tr=ábvera, ábvɛra|m-in}}. Don't split regular
  # headwords on commas because sometimes they legitimately have commas
  # in them (idioms, phrases, etc.). When we have translit, check each
  # value against the headword to see if the translit is redundant
  # (e.g. as in {{ru-noun form|а́бвера|tr=ábvera, ábvɛra|m-in}}, where the
  # first is redundant).
  def append_headword(head):
    if head not in headword_pronuns:
      headword_pronuns.append(head)

  for t in parsed.filter_templates():
    check_extra_heads = False
    tname = str(t.name)
    if (tname in ["%s-adj" % args.lang, "%s-adv" % args.lang, "%s-verb" % args.lang] or
        args.lang == "bg" and tname in ["bg-noun", "bg-proper noun"]):
      head = getparam(t, "1") or pagetitle
      append_headword(head)
      check_extra_heads = True
    elif tname in ["%s-phrase" % args.lang]:
      head = getparam(t, "head") or getparam(t, "1") or pagetitle
      append_headword(head)
      check_extra_heads = True
    elif tname == "head" and getparam(t, "1") == args.lang and getparam(t, "2") == "letter":
      pagemsg("WARNING: Skipping page with letter headword")
      return None
    elif tname == "head" and getparam(t, "1") == args.lang:
      head = getparam(t, "head") or pagetitle
      append_headword(head)
      check_extra_heads = True
    elif args.lang != "bg" and tname in ["%s-noun" % args.lang, "%s-proper noun" % args.lang]:
      param1 = getparam(t, "1")
      if "<" in param1:
        parsed_t = blib.parse_text(str(t)).filter_templates()[0]
        blib.set_template_name(parsed_t, "%s-generate-noun-forms" % args.lang)
        blib.remove_param_chain(parsed_t, "adj", "adj")
        blib.remove_param_chain(parsed_t, "dim", "dim")
        blib.remove_param_chain(parsed_t, "m", "m")
        blib.remove_param_chain(parsed_t, "f", "f")
        blib.remove_param_chain(parsed_t, "g", "g")
        blib.remove_param_chain(parsed_t, "lemma", "lemma")
        generate_template = str(parsed_t)
        generate_result = expand_text(generate_template)
        if not generate_result:
          pagemsg("WARNING: Error generating noun forms")
          return None
        result_args = blib.split_generate_args(generate_result)
        lemma = result_args["nom_s"] if "nom_s" in result_args else result_args["nom_p"]
        for head in re.split(",", lemma):
          append_headword(head)
      else:
        append_headword(param1)
        check_extra_heads = True

    if check_extra_heads:
      for i in range(2, 10):
        headn = getparam(t, "head" + str(i))
        if headn:
          append_headword(headn)

  # Canonicalize by removing links and final !, ?
  headword_pronuns = [re.sub("[!?]$", "", blib.remove_links(x)) for x in headword_pronuns]
  for pronun in headword_pronuns:
    if com.remove_accents(pronun) != pagetitle:
      pagemsg("WARNING: Headword pronun %s doesn't match page title, skipping" % pronun)
      return None

  # Check for acronym/non-syllabic.
  for pronun in headword_pronuns:
    if com.is_nonsyllabic(pronun):
      pagemsg("WARNING: Pronunciation is non-syllabic, skipping: %s" % pronun)
      return None
    if re.search("[" + com.uppercase + u"ЀЍ][" + AC + GR + "]?[" + com.uppercase + u"ЀЍ]", pronun):
      pagemsg("WARNING: Pronunciation may be an acronym, please check: %s" % pronun)

  # Canonicalize headword pronuns. If a single monosyllabic word, add accent
  # unless it's in the list of unaccented words.
  headword_pronuns = [canonicalize_monosyllabic_pronun(x) for x in headword_pronuns]

  # Also, if two pronuns differ only in that one has an additional accent on a
  # word, remove the one without the accent.

  def headwords_same_but_first_maybe_lacks_accents(h1, h2):
    if com.remove_accents(h1) == com.remove_accents(h2) and len(h1) < len(h2):
      h1words = re.split(r"([\s\-]+)", h1)
      h2words = re.split(r"([\s\-]+)", h2)
      if len(h1words) == len(h2words):
        for i in range(len(h1words)):
          if not (h1words[i] == h2words[i] or not com.is_accented(h1words[i]) and com.remove_accents(h2words[i]) == h1words[i]):
            return False
      return True
    return False
  def headword_should_be_removed_due_to_unaccent(hword, hwords):
    for h in hwords:
      if hword != h:
        if headwords_same_but_first_maybe_lacks_accents(hword, h):
          pagemsg("Removing headword %s because same as headword %s but lacking an accent" % (hword, h))
          return True
    return False
  headword_pronuns = remove_list_duplicates(headword_pronuns)
  new_headword_pronuns = [x for x in headword_pronuns if not
      headword_should_be_removed_due_to_unaccent(x, headword_pronuns)]
  if len(new_headword_pronuns) <= len(headword_pronuns) - 2:
    pagemsg("WARNING: Removed two or more headword pronuns, check that something didn't go wrong: old=%s, new=%s" % (
      ",".join(headword_pronuns), ",".join(new_headword_pronuns)))
  headword_pronuns = new_headword_pronuns

  if len(headword_pronuns) < 1:
    pagemsg("WARNING: Can't find headword template")
    return None
  headword_pronuns = remove_list_duplicates(headword_pronuns)
  return headword_pronuns

def pronun_matches(hpron, foundpron, pagemsg):
  orighpron = hpron
  origfoundpron = foundpron
  if hpron == foundpron or not foundpron:
    return True
  foundpron = com.remove_grave_accents(foundpron)
  if hpron == foundpron:
    pagemsg("Matching headword pronun %s to found pronun %s after removing grave accents from the latter" %
      (orighpron, origfoundpron))
    return True
  foundpron = foundpron.lower()
  hpron = hpron.lower()
  if hpron == foundpron:
    pagemsg(u"Matching headword pronun %s to found pronun %s after lowercasing (and removing grave accents)" %
      (orighpron, origfoundpron))
    return True

  return False

# Simple class to hold pronunciation found in uk/be-IPA, along with the text
# before and after. Lots of boilerplate to support equality and hashing.
# Based on http://stackoverflow.com/questions/390250/elegant-ways-to-support-equivalence-equality-in-python-classes
class FoundPronun(object):
  """Very basic"""
  def __init__(self, pron, pre, post):
    self.pron = pron
    self.pre = pre
    self.post = post

  def __eq__(self, other):
    """Override the default Equals behavior"""
    if isinstance(other, self.__class__):
      return self.pron == other.pron and self.pre == other.pre and self.post == other.post
    return NotImplemented

  def __ne__(self, other):
    """Define a non-equality test"""
    if isinstance(other, self.__class__):
      return not self.__eq__(other)
    return NotImplemented

  def __hash__(self):
    """Override the default hash behavior (that returns the id or the object)"""
    return hash(tuple(self.pron, self.pre, self.post))

  def __repr__(self):
    return "%s%s%s" % (self.pre and "[%s]" % self.pre or "", self.pron,
        self.post and "[%s]" % self.post or "")

# Match up the stems of headword pronunciations and found pronunciations.
# On entry, HEADWORD_PRONUNS is a list of values extracted from headwords;
# FOUND_PRONUNS is a list of FoundPronun objects, each one listing a
# pronunciation from {{*-IPA}} (which may be empty) along with the text
# before and after the pronunciation on the same line, minus any '* ' at
# the beginning.
#
# If able to do so, return a dictionary of all non-identity matchings, else
# return None. For each headword in the dictionary, the entry is a list of
# tuples of (STEM, FOUNDPRONSTEMS) where STEM is a possible stem of that
# headword and FOUNDPRONSTEMS is a list of the corresponding
# found-pronunciation stems. (Each such stem is actually a FoundPronun object,
# with the pre-text and post-text coming from the corresponding text before
# and after the {{*-IPA}} template where the pronunciation was found.)
# We return a list of stem tuples because there may be multiple stems to
# consider for each headword -- including reduced and dereduced variants
# (e.g. for автазапра́вка with corresponding pronunciation а̀втазапра́вка we
# need to consider both the regular stem автазапарвк- with stemmed
# pronunciation а̀втазапра́вк- and dereduced stem автазапра́вак- with stemmed
# pronunciation а̀втазапра́вак- in order to handle genitive plural автазаправак)
# and adjectival variants. FOUNDPRONSTEMS is a list because there may be
# multiple such pronunciations per headword stem, e.g. Сінгапу́р has two
# corresponding pronunciations Сінгапу́р and Сінґапу́р.
def match_headword_and_found_pronuns(headword_pronuns, found_pronuns, pagemsg,
    expand_text):
  matches = {}
  if not headword_pronuns:
    pagemsg("WARNING: No headword pronuns, possible error")
    # Error finding headword pronunciations, or something
    return None
  if not found_pronuns:
    pagemsg("WARNING: No found pronuns")
    return None
  # How many headword pronuns? If only one, automatically assign all found
  # pronuns to it.
  distinct_hprons = set(headword_pronuns)
  if len(distinct_hprons) == 1:
    hpron = list(distinct_hprons)[0]
    for foundpron in found_pronuns:
      valtoadd = FoundPronun(foundpron.pron or hpron, foundpron.pre, foundpron.post)
      if hpron in matches:
        if valtoadd not in matches[hpron]:
          matches[hpron].append(valtoadd)
      else:
        matches[hpron] = [valtoadd]

  else:
    # Multiple headwords, need to match "the hard way"
    all_match = True
    unmatched_hpron = set()
    hpron_seen = set()
    for hpron in headword_pronuns:
      if hpron in hpron_seen:
        pagemsg("Skipping already-seen headword pronun %s" % hpron)
        continue
      hpron_seen.add(hpron)
      new_found_pronuns = []
      matched = False
      for foundpron in found_pronuns:
        if pronun_matches(hpron, foundpron.pron, pagemsg):
          valtoadd = FoundPronun(foundpron.pron or hpron, foundpron.pre, foundpron.post)
          if hpron in matches:
            if valtoadd not in matches[hpron]:
              matches[hpron].append(valtoadd)
          else:
            matches[hpron] = [valtoadd]
          matched = True
        else:
          new_found_pronuns.append(foundpron)
      found_prons = new_found_pronuns
      if not matched:
        all_match = False
        unmatched_hpron.add(hpron)
    if not all_match:
      pagemsg("WARNING: Unable to match headword pronuns %s against found pronuns %s" %
          (",".join(unmatched_hpron), ",".join(str(x) for x in found_pronuns)))
      return None

  def get_reduced_stem(nom):
    # The stem for reduce_stem() should preserve -й
    stem_for_reduce = re.sub(u"[аяеоёьыі]́?$", "", nom)
    epenthetic_vowel = nom.endswith(AC)
    if re.search(u"[аяеоёьыі]́?$", nom):
      reduced_stem = com.dereduce(stem_for_reduce, epenthetic_vowel)
    else:
      reduced_stem = com.reduce(stem_for_reduce)
    return reduced_stem

  # Apply a function to a list of found pronunciations. Don't include
  # results where the return value from the function is logically false.
  def frob_foundprons(foundprons, fun):
    retval = []
    for foundpron in foundprons:
      newval = None
      funval = fun(foundpron.pron)
      if funval:
        newval = funval
      if newval:
        retval.append(FoundPronun(newval, foundpron.pre, foundpron.post))
    return retval

  # Remove the common case where there's only one found pronunciation and it's
  # the same as the head pronunciation (and there's no pre-text or post-text
  # that we need to propagate).
  matches = dict((hpron,foundprons) for hpron,foundprons in matches.iteritems()
      if not (len(foundprons) == 1 and hpron == foundprons[0].pron and
        not foundprons[0].pre and not foundprons[0].post))
  matches_stems = {}

  for hpron, foundprons in matches.iteritems():
    stems = []
    def append_stem_foundstems(stem, foundpronunstems):
      if stem and foundpronunstems:
        stems.append((stem, foundpronunstems))
    # Do noun stem
    noun_ending_regex = (
      u"[аяеоёьыій]́?$" if args.lang == "be" else
      u"[аяеоьиіїй]́?$" if args.lang == "uk" else
      u"[аяеоьий]́?$"
    )
    append_stem_foundstems(re.sub(noun_ending_regex, "", hpron),
      frob_foundprons(foundprons, lambda x:re.sub(noun_ending_regex, "", x)))
    # Also compute reduced/unreduced stem
    append_stem_foundstems(get_reduced_stem(hpron),
      frob_foundprons(foundprons, get_reduced_stem))
    # Also check for adjectival stem
    if args.lang != "bg": # Adjectives look like nouns in Bulgarian
      adj_ending_regex = (
        u"([ыі]́?|[ая]́?я|[аоя]́?е|[ыі]́?я)$" if args.lang == "be" else
        u"([иії]́?й|[аяеєі]́)$"
      )
      adjstem = re.sub(adj_ending_regex, "", hpron)
      if adjstem != hpron:
        foundpronstems = frob_foundprons(foundprons,
            lambda x:re.sub(adj_ending_regex, "", x))
        append_stem_foundstems(adjstem, foundpronstems)
        pagemsg("Adding adjectival stem mapping %s->%s" % (
          adjstem, ",".join(str(x) for x in foundpronstems)))
        # If adjectival, dereduce with both stressed and unstressed epenthetic
        # vowel
        for epvowel in [False, True]:
          deredstem = com.dereduce(adjstem, epvowel)
          deredfoundpronstems = frob_foundprons(foundpronstems,
              lambda x:com.dereduce(x, epvowel))
          append_stem_foundstems(deredstem, deredfoundpronstems)
          pagemsg("Adding adjectival dereduced stem mapping %s->%s" % (
            deredstem, ",".join(str(x) for x in deredfoundpronstems)))
    # Also check for verbal stem; peel off parts that don't occur in all
    # forms of the verb
    verb_ending_regex = (
      u"(ава́?|ну́?|[аеыіяо]́?)ц(ь|ца)?$" if args.lang == "be" else
      u"(ува́?|ну́?|[аеиіїяо]́?)т[иь](ся)?$" if args.lang == "uk" else
      u"([мая]́?)( с[еи])?$")
    verbstem = re.sub(verb_ending_regex, "", hpron)
    if verbstem != hpron:
      foundpronstems = frob_foundprons(foundprons,
          lambda x:re.sub(verb_ending_regex, "", x))
      append_stem_foundstems(verbstem, foundpronstems)
      pagemsg("Adding verbal stem mapping %s->%s" % (
        verbstem, ",".join(str(x) for x in foundpronstems)))
      iotstem = com.iotate(verbstem)
      iotfoundpronstems = frob_foundprons(foundpronstems,
          lambda x:com.iotate(x))
      append_stem_foundstems(iotstem, iotfoundpronstems)
      pagemsg("Adding verbal iotated stem mapping %s->%s" % (
        iotstem, ",".join(str(x) for x in iotfoundpronstems)))

    matches_stems[hpron] = stems

  # Check to see if the mappings have different numbers of acute accents and
  # warn if so, esp. if one mapping has acute accents and the other doesn't
  for hpron, stem_foundprons in matches_stems.iteritems():
    for stem, foundprons in stem_foundprons:
      stemaccents = stem.count(AC)
      for foundpron in foundprons:
        foundpronaccents = foundpron.pron.count(AC)
        if stemaccents != foundpronaccents:
          pagemsg("WARNING: Mapping %s->%s has different number of acute accents (%s->%s)" %
              (stem, foundpron, stemaccents, foundpronaccents))
          if not stemaccents or not foundpronaccents:
            pagemsg("WARNING: In mapping %s->%s, one has no acute accents and the other has acute accents (%s->%s)" %
                (stem, foundpron, stemaccents, foundpronaccents))

  return matches_stems

def get_lemmas_of_form_page(parsed):
  lemmas = set()
  for t in parsed.filter_templates():
    tname = str(t.name)
    first_param = None
    if (tname in ["inflection of", "comparative of", "superlative of"]):
      first_param = get_first_param(t)
    if first_param:
      lemma = com.remove_accents(blib.remove_links(getparam(t, first_param)))
      lemmas.add(lemma)
  return lemmas

# Cache mapping page titles to a set of the gem= values found on the page.
lemma_gem_cache = {}
# Cache mapping page titles to a map from headwords to pronunciations
# found on the page.
lemma_headword_to_pronun_mapping_cache = {}

# Look up the lemmas of all inflection-of templates in PARSED (the contents
# of an etym section), and for each such lemma, fetch a mapping from
# headword-derived stems to pronunciations as found in the uk/be-IPA templates.
# Return PRONUNMAPPING, a map as described above.
def lookup_pronun_mapping(parsed, pagemsg):
  lemmas = get_lemmas_of_form_page(parsed)
  pron_temp_name = args.lang + "-IPA"
  all_pronunmappings = {}
  for lemma in lemmas:
    # Need to create our own expand_text() with the page title set to the
    # lemma
    def expand_text(t):
      return blib.expand_text(t, lemma, pagemsg, args.verbose)

    if lemma in lemma_headword_to_pronun_mapping_cache:
      cached = True
      pronunmapping = lemma_headword_to_pronun_mapping_cache[lemma]
    else:
      cached = False
      newpage = pywikibot.Page(site, lemma)
      try:
        parsed = blib.parse(newpage)
      except pywikibot.exceptions.InvalidTitle as e:
        pagemsg("WARNING: Invalid title, skipping")
        traceback.print_exc(file=sys.stdout)
        continue

      # Compute headword->pronun mapping
      headwords = get_headword_pronuns(parsed, lemma, pagemsg, expand_text)
      foundpronuns = []

      # Find the pronunciations but also get pre-text and post-text
      for m in re.finditer(r"^(.*)(\{\{%s(?:\|[^}]*)?\}\})(.*)$" % pron_temp_name,
          newpage.text, re.M):
        pretext = m.group(1)
        ipa_temp_text = m.group(2)
        posttext = m.group(3)
        wholeline = m.group(0)
        if not pretext.startswith("* "):
          pagemsg("WARNING: %s doesn't start with '* ': %s" % (pron_temp_name, wholeline))
        pretext = re.sub(r"^\*?\s*", "", pretext) # remove '* ' from beginning
        if pretext or posttext:
          pagemsg("WARNING: pre-text or post-text with %s: %s" % (pron_temp_name, wholeline))
        ipa_t = blib.parse_text(ipa_temp_text).filter_templates()[0]
        assert str(ipa_t.name) == pron_temp_name
        foundpronun = com.add_monosyllabic_stress(getparam(ipa_t, "1"))
        foundpronuns.append(FoundPronun(foundpronun, pretext, posttext))
      pronunmapping = match_headword_and_found_pronuns(headwords, foundpronuns,
          pagemsg, expand_text)
      lemma_headword_to_pronun_mapping_cache[lemma] = pronunmapping

    # The output is HEADWORD->(STEMS_AND_PRONUNS),HEADWORD->(STEMS_AND_PRONUNS)...
    # where STEMS_AND_PRONUNS is STEM:PRONUNS,STEM:PRONUNS,...,
    # where PRONUNS is PRONUN/PRONUN/...
    # where PRONUN may be PRON or [PRE]PRON or PRON[POST] or [PRE]PRON[POST]
    pagemsg("For lemma %s, found pronun mapping %s%s" % (lemma, "None" if
      pronunmapping is None else "(empty)" if not pronunmapping else ",".join(
        "%s->(%s)" % (hpron, ",".join("%s:%s" % (stem, "/".join(str(x) for x in foundprons))
          for stem, foundprons in stem_foundprons))
        for hpron, stem_foundprons in pronunmapping.iteritems()),
      cached and " (cached)" or ""))
    if pronunmapping:
      all_pronunmappings.update(pronunmapping)

  return all_pronunmappings

def process_section(section, indentlevel, headword_pronuns,
    pagetitle, pagemsg, expand_text):
  assert indentlevel in [3, 4]
  notes = []

  was_unable_to_match = False

  parsed = blib.parse_text(section)

  pronunmapping = lookup_pronun_mapping(parsed, pagemsg)

  pron_temp_name = args.lang + "-IPA"
  pronun_lines = []
  bad_char_msgs = []
  # Figure out how many headword variants there are, and if there is more
  # than one, add |ann=y to each one.
  num_annotations = 0
  annotations_set = set()
  for cyr in headword_pronuns:
    annotations_set.add(cyr)
  matched_hpron = set()
  manually_subbed_pronun = False
  # List of pronunciations to insert into comment message; approximately
  # the same as what goes inside {{uk/be-IPA}}, except we don't include the
  # ann= parameter and we do include the pronunciation even if we leave
  # it out in {{uk/be-IPA}} because it's the same as the page title.
  pronuns_for_comment = []
  for pronun in headword_pronuns:
    # Signal from within append_pronun_line() that we encountered badness
    # in the pronunciation and need to skip setting it.
    # HACK! Use an array to avoid problems setting non-local variables.
    bad_pronun_need_to_return = [False]

    orig_pronun = pronun

    def canonicalize_annotation(ann):
       return com.remove_grave_accents(re.sub("[" + GR + u"‿]", "", ann))

    def append_pronun_line(pronun, pre="", post=""):
      if len(annotations_set) > 1:
        # Need an annotation. Check to see whether |ann=y is possible: The
        # original pronunciation is the same as the new one (but we allow
        # possible differences in DOTBELOW, grave accents, etc. because they
        # will be stripped with |ann=y).
        if (canonicalize_annotation(orig_pronun) !=
            canonicalize_annotation(pronun)):
          # Don't include DOTBELOW, grave accents, etc. in the annotation param
          # or they will be shown to the user.
          headword_annparam = "|ann=%s" % canonicalize_annotation(orig_pronun)
        else:
          headword_annparam = "|ann=y"
      else:
        headword_annparam = ""

      # Check for various badnesses in the pronunciation
      if pronun.startswith("-") or pronun.endswith("-"):
        pagemsg("WARNING: Skipping prefix or suffix: %s" % pronun)
        bad_pronun_need_to_return[0] = True
      if "." in pronun:
        pagemsg("WARNING: Pronunciation has dot in it, skipping: %s" % pronun)
        bad_pronun_need_to_return[0] = True
      if com.needs_accents(pronun, split_dash=True):
        for allow_regex in allow_unaccented:
          if re.search(allow_regex, pagetitle):
            pagemsg("Pronunciation lacks accents but pagetitle in allow_unaccented, allowing: %s"
                 % pronun)
            break
        else: # no break
          pagemsg("WARNING: Pronunciation lacks accents, skipping: %s" % pronun)
          bad_pronun_need_to_return[0] = True
      # Check for non-Cyrillic or Latin chars. We set bad_char_msgs, which we
      # pay attention to farther down, just before adding the actual pronun,
      # so we can get other warnings as well. FIXME: Maybe we should do the
      # same with the above badnesses?
      if contains_non_cyrillic_non_latin(pronun):
        bad_char_msgs.append(
            "WARNING: Pronunciation %s to be added contains non-Cyrillic non-Latin chars, skipping" %
              pronun)
      elif contains_latin(pronun):
        bad_char_msgs.append(
            "WARNING: Cyrillic pronunciation %s contains Latin characters, skipping" %
            pronun)

      pronun_for_comment = str(FoundPronun(pronun, pre, post))
      if pronun_for_comment not in pronuns_for_comment:
        pronuns_for_comment.append(pronun_for_comment)

      if (
         com.is_monosyllabic(pronun) and re.sub(AC, "", pronun) == pagetitle or
         re.search(u"ё", pronun) and pronun == pagetitle):
        pronun = "* %s{{%s%s}}%s\n" % (pre, pron_temp_name, headword_annparam,
            post)
      else:
        pronun = "* %s{{%s|%s%s}}%s\n" % (pre, pron_temp_name, pronun, headword_annparam,
            post)
      if pronun not in pronun_lines:
        pronun_lines.append(pronun)

    subbed_pronun = False

    # Check for manual pronunciation mapping
    for regex, subvals in manual_pronun_mapping:
      if re.search(regex, pronun):
        applied_manual_pronun_mappings.add(regex)
        if type(subvals) is not list:
          subvals = [subvals]
        for subval in subvals:
          if type(subval) is tuple:
            subval, pre, post = subval
          else:
            subval, pre, post = (subval, "", "")
          newpronun = re.sub(regex, subval, pronun)
          pagemsg("Replacing headword-based pronunciation %s with %s due to manual_pronun_mapping"
              % (pronun, newpronun))
          append_pronun_line(newpronun, pre, post)
        subbed_pronun = True
        manually_subbed_pronun = True
        break

    # If there is an automatically-derived headword->pronun mapping (e.g.
    # in case of secondary stress or phon=), try to apply it.
    if not subbed_pronun and pronunmapping:
      for hpron, stem_foundprons in pronunmapping.iteritems():
        outerbreak = False
        for stem, foundpronstems in stem_foundprons:
          assert stem
          assert foundpronstems
          if pronun.startswith(stem):
            for foundpronstem in foundpronstems:
              newpronun = re.sub("^" + re.escape(stem), foundpronstem.pron,
                  pronun)
              if newpronun != pronun:
                pagemsg("Replacing headword-based pronunciation %s with %s" %
                    (pronun, newpronun))
              append_pronun_line(newpronun, foundpronstem.pre, foundpronstem.post)
            subbed_pronun = True
            matched_hpron.add(hpron)
            outerbreak = True
            break
        if outerbreak:
          break

    # Otherwise, use headword pronun unchanged.
    append_pronun_line(pronun)

    # Skip if badness in pronunciation
    if bad_pronun_need_to_return[0]:
      return None

  if pronunmapping and not manually_subbed_pronun:
    for hpron, stem_foundprons in pronunmapping.iteritems():
      if hpron not in matched_hpron:
        pagemsg("WARNING: Unable to match mapping %s->(%s) in non-lemma form(s)"
          % (hpron, ",".join("%s:%s" % (stem, "/".join(str(x) for x in foundprons))
            for stem, foundprons in stem_foundprons)))
        was_unable_to_match = True

  for t in parsed.filter_templates():
    tname = str(t.name)
    if tname in ["%s-IPA-manual" % args.lang]:
      pagemsg("WARNING: Found %s template, skipping" % tname)
      return None
  if (re.search(r"[Aa]bbreviation", section) and not
      re.search("==Abbreviations==", section)):
    pagemsg("WARNING: Found the word 'abbreviation', please check")
  if (re.search(r"[Aa]cronym", section) and not
      re.search("==Acronyms==", section)):
    pagemsg("WARNING: Found the word 'acronym', please check")
  if (re.search(r"[Ii]nitialism", section) and not
      re.search("==Initialisms==", section)):
    pagemsg("WARNING: Found the word 'initialism', please check")

  def canonicalize_pronun(pron, paramname):
    newpron = re.sub(u"ё́", u"ё", pron)
    newpron = re.sub(AC + "+", AC, newpron)
    ournotes = []
    if newpron != pron:
      ournotes.append("remove extra accents from %s= (%s)" % (paramname, pron_temp_name))
      pron = newpron
    # We want to go word-by-word and check to see if the headword word is
    # the same as the uk/be-IPA word but has additional accents in it, and
    # if so copy the headword word to the uk/be-IPA word. One way to do that
    # is to check that the uk/be-IPA word has no accents and that the headword
    # word minus accents is the same as the uk/be-IPA word.
    if not bad_char_msgs and len(headword_pronuns) == 1:
      hwords = re.split(r"([\s\-]+)", headword_pronuns[0])
      pronwords = re.split(r"([\s\-]+)", pron)
      changed = False
      if len(hwords) == len(pronwords):
        for i in range(len(hwords)):
          hword = hwords[i]
          pronword = pronwords[i]
          if (len(hword) > len(pronword) and not com.is_accented(pronword) and
              com.remove_accents(hword) == pronword):
            changed = True
            pronwords[i] = hword
      if changed:
        pron = "".join(pronwords)
        ournotes.append("copy accents from headword to %s= (%s)" % (
          paramname, pron_temp_name))
    return pron, ournotes

  parsed = blib.parse_text(section)
  for t in parsed.filter_templates():
    if str(t.name) == pron_temp_name:
      origt = str(t)
      arg1 = getparam(t, "1") or pagetitle
      newarg1, their_notes = canonicalize_pronun(arg1, "1")
      if arg1 != newarg1:
        t.add("1", newarg1)
        arg1 = newarg1
      if com.is_monosyllabic(arg1) and re.sub(AC, "", arg1) == pagetitle:
        notes.append("remove 1= because monosyllabic and same as pagetitle modulo accents (%s)" %
            pron_temp_name)
        rmparam(t, "1")
      elif re.search(u"ё", arg1) and arg1 == pagetitle:
        notes.append(u"remove 1= because same as pagetitle and has ё (%s)" %
            pron_temp_name)
        rmparam(t, "1")
      else:
        notes.extend(their_notes)
      newt = str(t)
      if newt != origt:
        pagemsg("Replaced %s with %s" % (origt, newt))
  section = str(parsed)

  overrode_existing_pronun = False
  if args.override_pronun:
    pronun_line_re = r"^(\* .*\{\{%s(?:\|([^}]*))?\}\}.*)\n" % pron_temp_name
    for m in re.finditer(pronun_line_re, section, re.M):
      overrode_existing_pronun = True
      pagemsg("WARNING: Removing pronunciation due to --override-pronun: %s" %
          m.group(1))
    section = re.sub(pronun_line_re, "", section, 0, re.M)

  foundpronuns = []
  for m in re.finditer(r"(\{\{%s(?:\|([^}]*))?\}\})" % pron_temp_name, section):
    template_text = m.group(1)
    pagemsg("Already found pronunciation template: %s" % template_text)
    template = blib.parse_text(template_text).filter_templates()[0]
    foundpronun = getparam(template, "1") or pagetitle
    foundpronun = canonicalize_monosyllabic_pronun(foundpronun)
    foundpronuns.append(foundpronun)
  if foundpronuns:
    joined_foundpronuns = ",".join(foundpronuns)
    joined_headword_pronuns = ",".join(headword_pronuns)
    if len(foundpronuns) < len(headword_pronuns):
      pagemsg("WARNING: Fewer existing pronunciations (%s) than headword-derived pronunciations (%s): existing %s, headword-derived %s" % (
        len(foundpronuns), len(headword_pronuns),
        joined_foundpronuns, joined_headword_pronuns))
    headword_pronuns_no_grave = [com.remove_grave_accents(x) for x in headword_pronuns]
    foundpronuns_no_grave = [com.remove_grave_accents(x) for x in foundpronuns]
    if set(foundpronuns_no_grave) != set(headword_pronuns_no_grave):
      pagemsg("WARNING: Existing pronunciation template (w/o grave accent) has different pronunciation %s from headword-derived pronunciation %s" %
            (joined_foundpronuns, joined_headword_pronuns))
    elif set(foundpronuns) != set(headword_pronuns):
      pagemsg("WARNING: Existing pronunciation template has different pronunciation %s from headword-derived pronunciation %s, but only in grave accents" %
            (joined_foundpronuns, joined_headword_pronuns))

    return section, notes, was_unable_to_match

  pronunsection = "%sPronunciation%s\n%s\n" % ("="*indentlevel, "="*indentlevel,
      "".join(pronun_lines))

  if bad_char_msgs:
    for badmsg in bad_char_msgs:
      pagemsg(badmsg)
      return None

  origsection = section
  # If pronunciation section already present, insert pronun into it; this
  # could happen when audio but not IPA is present, or when we deleted the
  # pronunciation because of --override-pronun
  if re.search(r"^===+Pronunciation===+$", section, re.M):
    pagemsg("Found pronunciation section without %s or IPA" % pron_temp_name)
    section = re.sub(r"^(===+Pronunciation===+)\n", r"\1\n%s" %
        "".join(pronun_lines), section, 1, re.M)
  else:
    # Otherwise, skip past any ===Etymology=== or ===Alternative forms===
    # sections at the beginning. This requires us to split up the subsections,
    # find the right subsection to insert before, and then rejoin.
    subsections = re.split("(^===.*?===\n)", section, 0, re.M)

    insert_before = 1
    while True:
      if insert_before >= len(subsections):
        pagemsg("WARNING: Malformatted headers, no level-3/4 POS header")
        return None
      if ("===Alternative forms===" not in subsections[insert_before] and
          "===Etymology===" not in subsections[insert_before]):
        break
      insert_before += 2
    subsections[insert_before] = re.sub(r"(^===)", r"%s\1" % pronunsection, subsections[insert_before], 1, re.M)
    section = "".join(subsections)

  # Make sure there's a blank line before an initial header (even if there
  # wasn't one before).
  section = re.sub("^===", "\n===", section, 1)

  if section == origsection:
    pagemsg("WARNING: Something wrong, couldn't sub in pronunciation section")
    return None

  if overrode_existing_pronun:
    notes.append("override pronunciation with %s" % ",".join(pronuns_for_comment))
  else:
    notes.append("add pronunciation %s" % ",".join(pronuns_for_comment))

  return section, notes, was_unable_to_match

def process_page_text(index, text, pagetitle):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  pron_temp_name = args.lang + "-IPA"
  foundlang = False
  was_unable_to_match = False
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)
  orig_text = text
  for j in range(2, len(sections), 2):
    if sections[j-1] == "==%s==\n" % langname:
      if foundlang:
        pagemsg("WARNING: Found multiple %s sections" % langname)
        return None
      foundlang = True

      need_l3_pronun = False
      if "===Pronunciation 1===" in sections[j]:
        pagemsg("WARNING: Found ===Pronunciation 1===, should convert page to multiple etymologies")
        return None
      if "===Etymology 1===" in sections[j]:

        # If multiple etymologies, things are more complicated. We may have to
        # process each section individually. We fetch the headwords from each
        # section to see whether the etymologies should be in split or
        # combined form. If they should be in split form, we remove any
        # combined pronunciation and add pronunciations to each section if
        # not already present. If they should be in combined form, we
        # remove pronunciations from individual sections (PARTLY IMPLEMENTED)
        # and add a combined pronunciation at the top.

        etymsections = re.split("(^ *=== *Etymology +[0-9]+ *=== *\n)", sections[j], 0, re.M)
        # Make sure there are multiple etymologies, otherwise page is malformed
        pagemsg("Found multiple etymologies (%s)" % (len(etymsections)//2))
        if len(etymsections) < 5:
          pagemsg("WARNING: Misformatted page with multiple etymologies (too few etymologies, skipping)")
          return None

        # Check for misnumbered etymology sections
        # FIXME, this should be a separate script
        expected_etym_num = 0
        l3split = re.split(r"^(===[^=\n].*===\n)", sections[j], 0, re.M)
        seen_etym_1 = False
        for k in range(1, len(l3split), 2):
          if not seen_etym_1 and l3split[k] != "===Etymology 1===\n":
            continue
          seen_etym_1 = True
          expected_etym_num += 1
          m = re.search(r"^===(.*)===\n$", l3split[k])
          if not m:
            pagemsg("WARNING: Bad L3 header with multiple etymologies: %s" % l3split[k].replace("\n", ""))
            break
          header = m.group(1)
          if (header != "Etymology %s" % expected_etym_num and
              header not in allowed_l3_headings_when_multiple_etyms):
            pagemsg("WARNING: Misformatted page with multiple etymologies, expected ===Etymology %s=== but found %s" % (
              expected_etym_num, l3split[k].replace("\n", "")))
            break

        # Check if all per-etym-section headwords are the same
        etymparsed2 = blib.parse_text(etymsections[2])
        etym_headword_pronuns = {}
        # Fetch the headword pronuns of the ===Etymology 1=== section.
        # We don't check for None here so that an error in an individual
        # section doesn't cause us to bow out entirely; instead, we treat
        # any comparison with None as False so we will always end up with
        # per-section pronunciations.
        etym_headword_pronuns[2] = get_headword_pronuns(etymparsed2, pagetitle, pagemsg, expand_text)
        need_per_section_pronuns = False
        for k in range(4, len(etymsections), 2):
          etymparsed = blib.parse_text(etymsections[k])
          # Fetch the headword pronuns of the ===Etymology N=== section.
          # We don't check for None here; see above.
          etym_headword_pronuns[k] = get_headword_pronuns(etymparsed, pagetitle, pagemsg, expand_text)
          # Treat any comparison with None as False.
          if not etym_headword_pronuns[2] or not etym_headword_pronuns[k] or set(etym_headword_pronuns[k]) != set(etym_headword_pronuns[2]):
            pagemsg("WARNING: Etym section %s pronuns %s different from etym section 1 pronuns %s" % (
              k//2, ",".join(etym_headword_pronuns[k] or ["none"]), ",".join(etym_headword_pronuns[2] or ["none"])))
            need_per_section_pronuns = True
        numpronunsecs = len(re.findall("^===Pronunciation===$", etymsections[0], re.M))
        if numpronunsecs > 1:
          pagemsg("WARNING: Multiple ===Pronunciation=== sections in preamble to multiple etymologies, needs to be fixed")
          return None

        if need_per_section_pronuns:
          pagemsg("Multiple etymologies, split pronunciations needed")
        else:
          pagemsg("Multiple etymologies, combined pronunciation possible")

        # If need split pronunciations and there's a combined pronunciation,
        # delete it if possible.
        if need_per_section_pronuns and numpronunsecs == 1:
          pagemsg("Multiple etymologies, converting combined pronunciation to split pronunciation (deleting combined pronun)")
          # Remove existing pronunciation section; but make sure it's safe
          # to do so (must have nothing but uk/be-IPA templates in it, and the
          # pronunciations in them must match what's expected)
          m = re.search(r"(^===Pronunciation===\n)(.*?)(^==|\Z)", etymsections[0], re.M | re.S)
          if not m:
            pagemsg("WARNING: Can't find ===Pronunciation=== section when it should be there, logic error?")
            return None
          if not re.search(r"^(\* \{\{%s(?:\|([^}]*))?\}\}\n)*$" % pron_temp_name, m.group(2)):
            pagemsg("WARNING: Pronunciation section to be removed contains extra stuff (e.g. manual IPA or audio), can't remove: <%s>\n" % (
              m.group(1) + m.group(2)))
            return None
          foundpronuns = []
          for m in re.finditer(r"(\{\{%s(?:\|([^}]*))?\}\})" % pron_temp_name, m.group(2)):
            # FIXME, not right, should do what we do above with foundpronuns
            # where we work with the actual parsed template
            foundpronuns.append(m.group(2) or pagetitle)
          # FIXME, this may be wrong with translit
          foundpronuns = remove_list_duplicates([canonicalize_monosyllabic_pronun(x) for x in foundpronuns])
          if foundpronuns:
            joined_foundpronuns = ",".join(foundpronuns)
            # Combine headword pronuns while preserving order. To do this,
            # we sort by numbered etymology sections and then flatten.
            combined_headword_pronuns = remove_list_duplicates([y for k,v in sorted(etym_headword_pronuns.iteritems(), key=lambda x:x[0]) for y in (v or [])])
            joined_headword_pronuns = ",".join(combined_headword_pronuns)
            if not (set(foundpronuns) <= set(combined_headword_pronuns)):
              pagemsg("WARNING: When trying to delete pronunciation section, existing pronunciation %s not subset of headword-derived pronunciation %s, unable to delete" %
                    (joined_foundpronuns, joined_headword_pronuns))
              return None
          etymsections[0] = re.sub(r"(^===Pronunciation===\n)(.*?)(\Z|^==|^\[\[|^--)", r"\3", etymsections[0], 1, re.M | re.S)
          sections[j] = "".join(etymsections)
          text = "".join(sections)
          notes.append("remove combined pronun section")
          pagemsg("Removed pronunciation section because combined pronunciation with multiple etymologies needs to be split")

        # If need combined pronunciations, check for split pronunciations and
        # remove them. As a special case, if there's only one split
        # pronunciation, just move the whole section to the top. We do this
        # so we move audio, homophones, etc. This situation will frequently
        # happen when a script adds a non-lemma form to an existing page
        # without split etymologies, because it wraps everything in an
        # "Etymology 1" section.
        # FIXME: When we move the whole section to the top, it could be
        # incorrect to do so if the uk/be-IPA isn't just the headword, e.g. if
        # it has a strange spelling, or phon= or gem=, etc. We should probably
        # check for this.
        if not need_per_section_pronuns:
          # Check for a single pronunciation section that we can move
          num_secs_with_pronun = 0
          first_sec_with_pronun = 0
          for k in range(2, len(etymsections), 2):
            if "===Pronunciation===" in etymsections[k]:
              num_secs_with_pronun += 1
              if not first_sec_with_pronun:
                first_sec_with_pronun = k
          if num_secs_with_pronun == 1:
            # Section ends with another section start, end of text, a wikilink
            # or category link, or section divider. (Normally there should
            # always be another section following.)
            m = re.search(r"(^===+Pronunciation===+\n.*?)(\Z|^==|^\[\[|^--)",
                etymsections[first_sec_with_pronun], re.M | re.S)
            if not m:
              pagemsg("WARNING: Can't find ====Pronunciation==== section when it should be there, logic error?")
            else:
              # Set indentation of Pronunciation to 3
              pronunsec = re.sub(r"===+Pronunciation===+",
                  "===Pronunciation===", m.group(1))
              etymsections[first_sec_with_pronun] = re.sub(
                  r"^(===+Pronunciation===+\n.*?)(\Z|^==|^\[\[|^--)", r"\2",
                  etymsections[first_sec_with_pronun], 1, re.M | re.S)
              etymsections[0] = ensure_two_trailing_nl(etymsections[0])
              etymsections[0] += pronunsec
              sections[j] = "".join(etymsections)
              text = "".join(sections)
              notes.append("move split pronun section to top to make combined")
              pagemsg("Moved split pronun section for ===Etymology %s=== to top" % (k//2))
          elif num_secs_with_pronun > 1:
            pagemsg("WARNING: need combined pronunciation section, but there are multiple split pronunciation sections, code to delete them not implemented; delete manually)")
              # FIXME: Implement me

        # Now add the per-section or combined pronunciation
        if need_per_section_pronuns:
          for k in range(2, len(etymsections), 2):
            # Skip processing if pronuns are None.
            if not etym_headword_pronuns[k]:
              continue
            result = process_section(etymsections[k], 4,
                etym_headword_pronuns[k], pagetitle,
                pagemsg, expand_text)
            if result is None:
              continue
            etymsections[k], etymsection_notes, etymsection_unable_to_match = result
            notes.extend(etymsection_notes)
            was_unable_to_match = was_unable_to_match or etymsection_unable_to_match
          sections[j] = "".join(etymsections)
          text = "".join(sections)
        else:
          need_l3_pronun = True

      else:
        need_l3_pronun = True

      if need_l3_pronun:
        # Get the headword pronunciations for the whole page.
        # NOTE: Perhaps when we've already computed per-section headword
        # pronunciations, as with multiple etymologies, we should combine
        # them rather than checking the whole page. This will make a
        # difference if there are headwords outside of the etymology sections,
        # but that shouldn't happen and is a malformed page if so.
        # NOTE NOTE: If we combine headword pronunciations with multiple
        # etymologies, we need to preserve the order as found on the page.
        headword_pronuns = get_headword_pronuns(blib.parse_text(text), pagetitle, pagemsg, expand_text)
        # If error, skip page.
        if headword_pronuns is None:
          return None

        # Process the section
        result = process_section(sections[j], 3, headword_pronuns,
            pagetitle, pagemsg, expand_text)
        if result is None:
          continue
        sections[j], section_notes, section_unable_to_match = result
        notes.extend(section_notes)
        was_unable_to_match = was_unable_to_match or section_unable_to_match
        text = "".join(sections)

  if not foundlang:
    pagemsg("WARNING: Can't find %s section" % langname)
    return None

  return text, notes, was_unable_to_match

def process_page(page, index, parsed=None):
  pagetitle = str(page.title())

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping")
    return

  for skip_regex in skip_pages:
    if re.search(skip_regex, pagetitle):
      pagemsg("WARNING: Skipping because page in skip_pages matching %s" %
          skip_regex)
      return

  if not page.exists():
    pagemsg("WARNING: Page doesn't exist")
    return

  text = str(page.text)
  result = process_page_text(index, text, pagetitle)
  if result is None:
    return

  newtext, notes, was_unable_to_match = result

  if newtext != text:
    assert notes
    if was_unable_to_match:
      pagemsg("WARNING: Would save and unable to match mapping")

  # Eliminate sequences of 3 or more newlines, which may come from
  # ensure_two_trailing_nl(). Add comment if none, in case of existing page
  # with extra newlines.
  newnewtext = re.sub(r"\n\n\n+", r"\n\n", newtext)
  if newnewtext != newtext and not notes:
    notes = ["eliminate sequences of 3 or more newlines"]
  newtext = newnewtext

  return newtext, notes

def process_lemma(index, pagetitle, forms):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  page = pywikibot.Page(site, pagetitle)
  parsed = blib.parse(page)
  for t in parsed.filter_templates():
    tname = str(t.name)
    tempcall = None
    if tname == "%s-conj" % args.lang:
      tempcall = re.sub(r"^\{\{%s-conj" % args.lang, "{{%s-generate-verb-forms" % args.lang,
          str(t))
    elif tname == "%s-ndecl" % args.lang:
      tempcall = re.sub(r"^\{\{%s-ndecl" % args.lang, "{{%s-generate-noun-forms" % args.lang,
          str(t))
    elif tname == "%s-adecl" % args.lang:
      tempcall = re.sub(r"^\{\{%s-adecl" % args.lang, "{{%s-generate-adj-forms" % args.lang,
          str(t))
    if tempcall:
      result = expand_text(tempcall)
      if not result:
        pagemsg("WARNING: Error generating forms, skipping")
        continue
      result_args = blib.split_generate_args(result)

      for form in forms:
        if form in result_args:
          for formpagename in re.split(",", result_args[form]):
            formpagename = com.remove_accents(formpagename)
            formpage = pywikibot.Page(site, formpagename)
            if not formpage.exists():
              pagemsg("WARNING: Form page %s doesn't exist, skipping" % formpagename)
            elif formpagename == pagetitle:
              pagemsg("WARNING: Skipping dictionary form")
            else:
              process_page(formpage, index)

def read_pages(filename, start, end):
  for i, line in blib.iter_items_from_file(filename, start, end):
    m = re.search(r"^\* Page ([0-9]+) \[\[(.*?)\]\]: ", line)
    if m:
      page = m.group(2)
    else:
      m = re.search(r"^Page ([0-9]+) (.*?): ", line)
      if m:
        page = m.group(2)
      else:
        page = line
    yield i, page

parser = blib.create_argparser("Add pronunciation sections to Ukrainian, Belarusian or Bulgarian Wiktionary entries", include_pagefile=True)
parser.add_argument('--lemma-file', help="File containing lemmas to process, one per line; non-lemma forms will be done")
parser.add_argument('--lemmas', help="List of comma-separated lemmas to process; non-lemma forms will be done")
parser.add_argument('--lang', help="Language (uk, be, bg)", choices=['uk', 'be', 'bg'], required=True)
parser.add_argument("--forms", help="Form codes of non-lemma forms to process in conjunction with --lemmas and --lemma-file.")
parser.add_argument('--override-pronun', action="store_true", help="Override existing pronunciations")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.lang == 'uk':
  langname = 'Ukrainian'
  com = uklib
elif args.lang == 'be':
  langname = 'Belarusian'
  com = belib
elif args.lang == 'bg':
  langname = 'Bulgarian'
  com = bglib
else:
  raise ValueError("Internal error: Unrecognized --lang %s" % args.lang)

if args.lang == 'bg':
  form_aliases = {
    "pres": [
      "pres_1sg", "pres_2sg", "pres_3sg", "pres_1pl", "pres_2pl", "pres_3pl"
    ],
    "impf": [
      "impf_1sg", "impf_2sg", "impf_3sg", "impf_1pl", "impf_2pl", "impf_3pl"
    ],
    "aor": [
      "aor_1sg", "aor_2sg", "aor_3sg", "aor_1pl", "aor_2pl", "aor_3pl"
    ],
    "impv": ["impv_sg", "impv_pl"],
    "prap": [
      "prap_ind_m_sg", "prap_def_sub_m_sg", "prap_def_obj_m_sg",
      "prap_ind_f_sg", "prap_def_f_sg", "prap_ind_n_sg", "prap_def_n_sg",
      "prap_ind_pl", "prap_def_pl",
    ],
    "paap": [
      "paap_ind_m_sg", "paap_def_sub_m_sg", "paap_def_obj_m_sg",
      "paap_ind_f_sg", "paap_def_f_sg", "paap_ind_n_sg", "paap_def_n_sg",
      "paap_ind_pl", "paap_def_pl",
    ],
    "paip": [
      "paip_m_sg", "paip_f_sg", "paip_n_sg", "paip_pl",
    ],
    "ppp": [
      "ppp_ind_m_sg", "ppp_def_sub_m_sg", "ppp_def_obj_m_sg",
      "ppp_ind_f_sg", "ppp_def_f_sg", "ppp_ind_n_sg", "ppp_def_n_sg",
      "ppp_ind_pl", "ppp_def_pl",
    ],
    "vn": [
      "vn_ind_sg", "vn_def_sg", "vn_ind_pl", "vn_def_pl",
    ],
    "part": [
      "prap", "paap", "paip", "ppp", "advp",
    ],
    "all-verb": ["pres", "impf", "aor", "impv", "part", "vn"],
    "sg": ["ind_sg", "def_sub_sg", "def_obj_sg", "voc_sg", "acc_sg", "gen_sg", "dat_sg"],
    "pl": ["voc_pl", "acc_pl", "gen_pl", "dat_pl", "ind_pl", "def_pl", "count"],
    "all-noun": ["sg", "pl"],
    "adj-sg": [
      "ind_m_sg", "def_sub_m_sg", "def_obj_m_sg", "ind_f_sg", "def_f_sg",
      "ind_n_sg", "def_n_sg", "voc_m_sg"
    ],
    "adj-pl": ["ind_pl", "def_pl"],
    "all-adj": ["adj-sg", "adj-pl"],
  }
else:
  form_aliases = {
    "pres": [
      "pres_1sg", "pres_2sg", "pres_3sg", "pres_1pl", "pres_2pl", "pres_3pl"
    ],
    "futr": [
      "futr_1sg", "futr_2sg", "futr_3sg", "futr_1pl", "futr_2pl", "futr_3pl"
    ],
    "impr": ["impr_sg", "impr_pl"],
    "past": ["past_m", "past_f", "past_n", "past_pl"],
    "part": [
      "pres_actv_part", "past_pasv_part",
      "pres_adv_part", "past_adv_part",
    ],
    "all-verb": ["pres", "futr", "impr", "past", "part"],
    "sg": ["nom_s", "gen_s", "dat_s", "acc_s", "ins_s", "loc_s", "voc_s"],
    "pl": ["nom_p", "gen_p", "dat_p", "acc_p", "ins_p", "loc_p", "voc_p", "count"],
    "all-noun": ["sg", "pl"],
    "long": [
      "nom_m", "nom_f", "nom_n", "nom_p", "nom_mp", "nom_fp",
      "gen_m", "gen_f", "gen_p",
      "dat_m", "dat_f", "dat_p",
      "acc_m_an", "acc_m_in", "acc_f", "acc_n", "acc_p_an", "acc_p_in",
      "acc_mp_an", "acc_mp_in", "acc_fp_an", "acc_fp_in", "acc_mp", "acc_fp",
      "ins_m", "ins_f", "ins_p",
      "loc_m", "loc_f", "loc_p",
    ],
    "short": args.lang == 'uk' and ["short"] or ["short_m", "short_f", "short_n", "short_p"],
    "all-adj": ["long", "short"],
    "all": ["all-verb", "all-noun", "all-adj"]
  }

def parse_form_aliases(forms):
  retval = []
  def parse_one_form(form):
    if form in form_aliases:
      for f in form_aliases[form]:
        parse_one_form(f)
    else:
      if form not in retval:
        retval.append(form)
  for form in re.split(",", forms):
    parse_one_form(form)
  return retval

if args.lemma_file or args.lemmas:
  forms = parse_form_aliases(args.forms)

  if args.lemma_file:
    lemmas = read_pages(args.lemma_file, start, end)
  else:
    lemmas = blib.iter_items(re.split(",", args.lemmas.decode("utf-8")), start, end)
  for i, lemma in lemmas:
    process_lemma(i, com.remove_accents(lemma), forms)

else:
  blib.do_pagefile_cats_refs(args, start, end, process_page,
      default_cats=[langname + " lemmas", langname + " non-lemma forms"], edit=True)

def subval_to_string(subval):
  if type(subval) is tuple:
    pron, pre, post = subval
    return str(FoundPronun(pron, pre, post))
  else:
    return subval

for regex, subvals in manual_pronun_mapping:
  if regex not in applied_manual_pronun_mappings:
    msg("WARNING: Unapplied manual_pronun_mapping %s->%s" % (regex,
      ",".join(subval_to_string(x) for x in subvals) if type(subvals) is list
      else subval_to_string(subvals)))

blib.elapsed_time()

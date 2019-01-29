#!/usr/bin/env python
#coding: utf-8

#    find_russian_need_vowels.py is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Despite its name, this is actually a script to auto-accent Russian text
# by looking up unaccented multisyllabic words in the dictionary and fetching
# the accented headwords, and if there's only one, using it in place of the
# original unaccented word. We're somewhat smarter than this, e.g. we first
# try looking up the whole phrase before partitioning it into individual
# words.
#
# FIXME:
#
# 1. (DONE AS PART OF SMARTER WORD SPLITTING) Handle '''FOO''', matched up
#    against blank tr, TR or '''TR'''. Cf. '''спасти''' in 23865 спасти.
# 2. (DONE) Handle multiword expressions *inside* of find_accented so we
#    can handle e.g. the multiword linked expressions in 24195 стан, such
#    as [[нотный стан]] and [[передвижной полевой стан]].
# 3. (DONE) Handle single-word two-part links [[FOO|BAR]].
# 4. Consider implementing support for [[FOO BAR]] [[BAZ]]. To do this
#    we need to keep [[FOO BAR]] together when word-splitting. We can
#    do this by splitting on the expression we want to keep together,
#    with a capturing split, something like "(\[\[.*?\]\]|[^ ,.!?\-]+)".
#    It's tricky to handle treating ''' as punctuation when doing this,
#    and even trickier if there is manual translit; probably in the latter
#    case we just want to refuse to do it.
# 5. (DONE) When splitting on spaces, don't split on hyphens at first, but
#    then split on hyphens the second time around.
# 6. (DONE) Implement a cache in find_accented_2().
# 7. (DONE, NO, ACCENTED TEXT CAN'T BE PUT INTO WIKIPEDIA PAGE LINKS)
#    Should probably skip {{wikipedia|lang=ru|...}} links. First check
#    whether accented text can even be put into the page link.
# 8. (DONE) Skip {{temp|head}}.
# 9. (DONE) Don't try to accent multisyllable particles that should be
#    accentless (либо, нибудь, надо, обо, ото, перед, передо, подо, предо,
#    через).
# 10. (DONE) Message "changed from ... in more than just accents": Handle
#    grave accent on е and и, handle case where accented text ends with extra
#    ! or ?.
# 11. (DONE) Turn off splitting of templates on translit with comma in it.
# 12. (DONE) When doing word splitting and looking up individual words,
#    if the lookup result has a comma in translit, chop off everything
#    after the comma and issue a warning. Occurs e.g. in 6661 детектив,
#    with {{l|ru|частный детектив}}. (FIXME: Even better would be to
#    duplicate the entire translit.)
# 13. (DONE) When fetching the result of ru-noun+, if there are multiple
#    lemmas, combine the ones with the same Russian by separating the translits
#    with a comma. Occurs e.g. in 6810 динамика with {{l|ru|термодинамика}}.
# 14. If we repeat this script, we should handle words that occur directly
#    after a stressed monosyllabic preposition and not auto-acent them.
#    The list of such prepositions is без, близ, во, да, до, за, из, ко,
#    меж, на, над, не, ни, об, от, по, под, пред, при, про, со, у. I don't
#    think multisyllabic unstressed prepositions can steal accent from a
#    following word; need to ask Anatoli/Wikitiki89 about this.
# 15. FIXME! There may data loss in a case like
#    {{lang|ru|{{l|ru|это|Это}} клёвее.}}, which may mistakenly get replaced
#    with {{l|ru|это|Это}} (formerly found on the [[клёвее]] page). NEED TO
#    CHECK WHETHER THIS ERROR STILL HAPPENS.

import re, codecs

import blib, pywikibot
from blib import msg, getparam, addparam
import rulib as ru

site = pywikibot.Site()
semi_verbose = False # Set by --semi-verbose or --verbose

AC = u"\u0301" # acute =  ́
GR = u"\u0300" # grave =  ̀

# List of accentless multisyllabic words.
accentless_multisyllable_lemma = [u"надо", u"обо", u"ото",
  u"перед", u"передо", u"подо", u"предо", u"через"]
accentless_multisyllable = [u"либо", u"нибудь"] + accentless_multisyllable_lemma
ru_lemma_templates = ["ru-noun", "ru-proper noun", "ru-verb", "ru-adj",
  "ru-adv", "ru-phrase"]
ru_head_templates = ru_lemma_templates + ["ru-noun form"]
ru_lemma_poses = ["circumfix", "conjunction", "determiner", "interfix",
  "interjection", "letter", "numeral", "cardinal number", "particle",
  "predicative", "prefix", "preposition", "prepositional phrase", "pronoun"]
# FIXME! List all the quote-* and cite-* templates
link_expandable_templates = ["ux", "uxi", "quote"]

monosyllabic_prepositions = [u"без", u"близ", u"во", u"да", u"до", u"за",
    u"из", u"ко", u"меж", u"на", u"над", u"не", u"ни", u"о", u"об", u"от",
    u"по", u"под", u"пред", u"при", u"про", u"со", u"у"]

monosyllabic_accented_prepositions = [
    prep + AC for prep in monosyllabic_prepositions
]

# Information found during lookup of a page. Value is None if the page
# doesn't exist. Value is the string "redirect" if page is a redirect.
# Otherwise, value is a tuple (HEADS, SAW_LEMMA, INFLECTIONS_OF, ADJ_FORMS);
# see fetch_page_from_cache().
accented_cache = {}
num_cache_lookups = 0
num_cache_hits = 0
global_disable_cache = False

def output_stats(pagemsg):
  if global_disable_cache:
    return
  pagemsg("Cache size = %s" % len(accented_cache))
  pagemsg("Cache lookups = %s, hits = %s, %0.2f%% hit rate" % (
    num_cache_lookups, num_cache_hits,
    float(num_cache_hits)*100/num_cache_lookups if num_cache_lookups else 0.0))

def split_ru_tr(form):
  if "//" in form:
    rutr = re.split("//", form)
    assert len(rutr) == 2
    ru, tr = rutr
    return (ru, tr)
  else:
    return (form, "")

adj_endings_first_letter = {
  u"о": ["hard", "sib-acc", "velar"],
  u"е": ["soft", "sib-unacc", "ts"],
  u"а": ["hard", "velar", "sib-acc", "sib-unacc", "ts"],
  u"я": ["soft"],
  u"ы": ["hard", "ts"],
  u"и": ["soft", "velar", "sib-acc", "sib-unacc"],
  u"у": ["hard", "velar", "sib-acc", "sib-unacc", "ts"],
  u"ю": ["soft"],
}

# For a possible adjective form, return the lemmas that it might belong to.
def get_adj_form_lemmas(form):
  if re.search(u"(ое|ее|ая|яя|ые|ие|ой|ей|ых|их|ым|им|ую|юю|ою|ею|ом|ем)$", form):
    base = form[:-2]
    types = adj_endings_first_letter[form[-2]]
  elif re.search(u"(ого|его|ому|ему|ыми|ими)$", form):
    base = form[:-3]
    types = adj_endings_first_letter[form[-3]]
  else:
    return []
  if not base:
    return []
  lemmas = []
  if base[-1] == u"ц":
    if "ts" in types:
      lemmas.append(base + u"ый")
      if not form.endswith(u"ой"):
        lemmas.append(base + u"ой")
  elif base[-1] in u"шжчщ":
    if "sib-unacc" in types:
      lemmas.append(base + u"ий")
    if "sib-acc" in types and not form.endswith(u"ой"):
      lemmas.append(base + u"ой")
  elif base[-1] in u"кгх":
    if "velar" in types:
      lemmas.append(base + u"ий")
      if not form.endswith(u"ой"):
        lemmas.append(base + u"ой")
  elif "hard" in types:
    lemmas.append(base + u"ый")
    if not form.endswith(u"ой"):
      lemmas.append(base + u"ой")
  elif "soft" in types:
    lemmas.append(base + u"ий")
    # no end-accented soft adjectives
  return lemmas

# Fetch cached information on a page, or fetch it from the page and cache it.
# In either case, return the page information. Return value is a tuple
# (CACHED, INFO), where CACHED indicates whether the returned info was
# cached and INFO is either None (page doesn't exist), "redirect"
# (page is a redirect) or a tuple as follows:
#   (HEADS, SAW_LEMMA, INFLECTIONS_OF, ADJ_FORMS)
#
# (1) HEADS is all heads found on the page (each of which is (RU, TR)),
# (2) SAW_LEMMA is True if we saw any lemma templates on the page (not
#     including e.g. {{ru-noun form}} or {{head|ru|verb form}})
# (3) INFLECTIONS_OF is all lemmas of which this entry is an inflection,
# (4) ADJ_FORMS is all adjective forms of any adjective lemmas found on the
#     page (each of which is (RU, TR)).
def fetch_page_from_cache(pagename, pagemsg, expand_text):
  if semi_verbose:
    pagemsg("find_accented: Finding heads on page %s" % pagename)

  cached_redirect = False
  global num_cache_lookups
  num_cache_lookups += 1
  if pagename in accented_cache:
    global num_cache_hits
    num_cache_hits += 1
    result = accented_cache[pagename]
    if result is None:
      if semi_verbose:
        pagemsg("find_accented: Page %s doesn't exist (cached)" % pagename)
    elif result == "redirect":
      if semi_verbose:
        pagemsg("find_accented: Page %s is redirect (cached)" % pagename)
    return True, result
  else:
    cached = False
    page = pywikibot.Page(site, pagename)
    try:
      if not page.exists():
        if semi_verbose:
          pagemsg("find_accented: Page %s doesn't exist" % pagename)
        if not global_disable_cache:
          accented_cache[pagename] = None
        return False, None
    except Exception as e:
      pagemsg("WARNING: Error checking page existence: %s" % unicode(e))
      if not global_disable_cache:
        accented_cache[pagename] = None
      return False, None

    # Page exists, is it a redirect?
    if re.match("#redirect", page.text, re.I):
      if not global_disable_cache:
        accented_cache[pagename] = "redirect"
      pagemsg("find_accented: Page %s is redirect" % pagename)
      return False, "redirect"

    # Page exists and is not a redirect, find the info
    heads = set()
    def add(val, tr):
      val_to_add = blib.remove_links(val)
      if val_to_add:
        heads.add((val_to_add, tr))
    saw_lemma = False
    inflections_of = set()
    adj_forms = set()
    for t in blib.parse(page).filter_templates():
      tname = unicode(t.name)
      check_addl_heads = False
      if tname in ru_head_templates:
        if tname in ru_lemma_templates:
          saw_lemma = True
        check_addl_heads = True
        if getparam(t, "1"):
          add(getparam(t, "1"), getparam(t, "tr"))
        elif getparam(t, "head"):
          add(getparam(t, "head"), getparam(t, "tr"))
        else:
          add(pagename, "")
      elif tname == "head" and getparam(t, "1") == "ru":
        if getparam(t, "2") in ru_lemma_poses:
          saw_lemma = True
        check_addl_heads = True
        if getparam(t, "head"):
          add(getparam(t, "head"), getparam(t, "tr"))
        else:
          add(pagename, "")
      elif tname in ["ru-noun+", "ru-proper noun+"]:
        saw_lemma = True
        lemma = ru.fetch_noun_lemma(t, expand_text)
        lemmas = re.split(",", lemma)
        lemmas = [split_ru_tr(lemma) for lemma in lemmas]
        # Group lemmas by Russian, to group multiple translits
        lemmas = ru.group_translits(lemmas, pagemsg, expand_text)
        for val, tr in lemmas:
          add(val, tr)
      elif tname == "inflection of" and getparam(t, "lang") == "ru":
        inflections_of.add(getparam(t, "1"))
      if check_addl_heads:
        for i in xrange(2, 10):
          headn = getparam(t, "head" + str(i))
          if headn:
            add(headn, getparam(t, "tr" + str(i)))
      elif tname == "ru-decl-adj":
        result = expand_text(re.sub(r"^\{\{ru-decl-adj", "{{ru-generate-adj-forms", unicode(t)))
        if not result:
          pagemsg("WARNING: Error expanding template %s" % unicode(t))
        else:
          args = ru.split_generate_args(result)
          for value in args.itervalues():
            adj_forms.add(value)

    cacheval = (heads, saw_lemma, inflections_of, adj_forms)
    if not global_disable_cache:
      accented_cache[pagename] = cacheval
    return False, cacheval

# Look up a single term (which may be multi-word). If the page exists, retrieve
# and return the headword(s) and lemma(s) (the term may itself be a lemma, or
# it may be the non-lemma form of some lemma). If there are any problems,
# return the term unchanged. A problem is any of the following:
# -- page doesn't exist or is a redirect
# -- multiple distinct headwords
# -- multiple distinct lemmas
# -- term is both a lemma and non-lemma
# The return value is (newterm, newterm_tr, lemma) where missing
# transliteration should be returned as "", and LEMMA should be None is no
# lemma is available or True if the term itself is a lemma, else a string.
def lookup_term_for_accents(term, termtr, verbose, pagemsg):
  if term in accentless_multisyllable:
    pagemsg("Not accenting unaccented multisyllabic particle %s" % term)
    if term in accentless_multisyllable_lemma:
      return term, termtr, True
    else:
      return term, termtr, None
  # This can happen if e.g. we're passed "[[FOO|BAR]] BAZ"; we will reject it,
  # but it will then be word-split and handled correctly ("[[FOO|BAR]]" is
  # special-cased in find_accented_1()).
  if "|" in term:
    #pagemsg("Can't handle links with vertical bars: %s" % term)
    return term, termtr, None
  # This can happen if e.g. we're passed "[[FOO]] [[BAR]]"; we will reject it,
  # but it will then be word-split and handled correctly ("[[FOO]]" is
  # special-cased in find_accented_1()).
  if "[" in term or "]" in term:
    #pagemsg("Can't handle stray bracket in %s" % term)
    return term, termtr, None
  if "<" in term or ">" in term:
    pagemsg("Can't handle stray < or >: %s" % term)
    return term, termtr, None

  already_accented = False

  if AC in term or u"ё" in term:
    already_accented = True
    pagemsg(u"Term has accent or ё, not replacing accents: %s" % term)
  if ru.is_monosyllabic(term):
    already_accented = True
    pagemsg("Term is monosyllabic, no need for accents: %s" % term)

  pagename = ru.remove_accents(term)
  # We can't use expand_text() from find_accented_1() because it has a
  # different value for PAGENAME, and the proper value is important in
  # expanding ru-noun+ and ru-proper noun+.
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagename, pagemsg, semi_verbose)

  # Look up the page
  if semi_verbose:
    pagemsg("find_accented: Finding heads on page %s" % pagename)

  cached, cache_result = fetch_page_from_cache(pagename, pagemsg, expand_text)
  if cache_result is None or cache_result == "redirect":
    heads = set()
    saw_lemma = False
    inflections_of = set()
    adj_forms = set()
  else:
    heads, saw_lemma, inflections_of, adj_forms = cache_result

  # Look up any adjectives of which the page may be a form
  adj_lemmas = get_adj_form_lemmas(pagename)
  for adj_lemma in adj_lemmas:
    adj_cached, adj_cache_result = fetch_page_from_cache(adj_lemma, pagemsg,
      expand_text)
    if adj_cache_result is not None and adj_cache_result != "redirect":
      _, _, _, this_adj_forms = adj_cache_result
      for adj_form in this_adj_forms:
        adj_form_ru, adj_form_tr = split_ru_tr(adj_form)
        if ru.remove_accents(adj_form_ru) == pagename:
          heads.add((adj_form_ru, adj_form_tr))
          inflections_of.add(adj_lemma)

  # We have the heads
  cached_msg = " (cached)" if cached else ""
  if len(heads) == 0:
    if cache_result is not None and cache_result != "redirect":
      pagemsg("WARNING: Can't find any heads: %s%s" % (pagename, cached_msg))
    return term, termtr, None
  if len(heads) > 1:
    pagemsg("WARNING: Found multiple heads for %s%s: %s" % (pagename, cached_msg, ",".join("%s%s" % (ru, "//%s" % tr if tr else "") for ru, tr in heads)))
    return term, termtr, None
  newterm, newtr = list(heads)[0]
  if semi_verbose:
    pagemsg("find_accented: Found head %s%s%s" % (newterm, "//%s" % newtr if newtr else "", cached_msg))
  if re.search("[!?]$", newterm) and not re.search("[!?]$", term):
    newterm_wo_punc = re.sub("[!?]$", "", newterm)
    if ru.remove_accents(newterm_wo_punc) == ru.remove_accents(term):
      pagemsg("Removing punctuation from %s when matching against %s" % (
        newterm, term))
      newterm = newterm_wo_punc
  if ru.remove_accents(newterm) != ru.remove_accents(term):
    pagemsg("WARNING: Accented term %s differs from %s in more than just accents%s" % (
      newterm, term, cached_msg))

  if already_accented:
    newterm = term
    newtr = termtr
  if len(inflections_of) == 1 and not saw_lemma:
    # Not a lemma and inflection of one lemma
    lemma = list(inflections_of)[0]
    return newterm, newtr, lemma
  elif len(inflections_of) == 0 and saw_lemma:
    # A lemma and not a non-lemma form
    return newterm, newtr, True
  # Else, either (a) both lemma and non-lemma, (b) non-lemma of multiple
  # lemmas, or (c) neither lemma nor non-lemma.
  if len(inflections_of) > 0 and saw_lemma:
    pagemsg("WARNING: Found lemma and inflections of one or more lemmas for %s%s: head(s) %s, lemma(s) of which this term is an inflection %s" % (
      pagename, cached_msg,
      ",".join("%s%s" % (ru, "//%s" % tr if tr else "") for ru, tr in heads),
      ",".join(inflections_of)))
  elif len(inflections_of) > 1:
    pagemsg("WARNING: Found inflections of multiple lemmas for %s%s: head(s) %s, lemmas of which this term is an inflection %s" % (
      pagename, cached_msg,
      ",".join("%s%s" % (ru, "//%s" % tr if tr else "") for ru, tr in heads),
      ",".join(inflections_of)))
  return newterm, newtr, None

# After the words in TERM with translit TERMTR have been split into words
# WORDS and TRWORDS (which should be an empty list if TERMTR is empty), with
# alternating separators in the even-numbered words, find accents for each
# individual word and then rejoin the result.
def find_accented_split_words(term, termtr, words, trwords, verbose, pagetitle,
    pagemsg, expand_text, origt, add_brackets):
  newterm = term
  newtr = termtr
  # Check for unbalanced brackets.
  unbalanced = False
  for i in xrange(1, len(words), 2):
    word = words[i]
    if word.count("[") != word.count("]"):
      pagemsg("WARNING: Unbalanced brackets in word #%s %s: %s" %
          (i//2, word, "".join(words)))
      unbalanced = True
      break
  if not unbalanced:
    newwords = []
    newtrwords = []
    # If we end up with any words with manual translit (either because
    # translit was already supplied by the existing template and we
    # preserve the translit for a given word, or because we encounter
    # manual translit when looking up a word), we will need to manually
    # transliterate all remaining words. Note, even when the existing
    # template supplies manual translit, we may need to manually
    # translit some words, because the lookup of those words may
    # (in fact, usually will) return a result without manual translit.
    sawtr = False
    # Go through each word and separator.
    for i in xrange(len(words)):
      word = words[i]
      trword = trwords[i] if trwords else ""
      # If it's a non-blank word (not a separator), look it up.
      if word and i % 2 == 1:
        if i > 1 and words[i - 2] in monosyllabic_accented_prepositions:
          # If it's a word and preceded by a stressed monosyllabic
          # preposition (e.g. до́ смерти), leave it alone.
          pagemsg("Not accenting term %s%s preceded by accented preposition %s" %
              (word, "//" + trword if trword else "", words[i - 2]))
          ru = word
          tr = trword
          # FIXME! Bracket term as necessary.
        else:
          # Otherwise, actually look it up.
          ru, tr = find_accented(word, trword, verbose, pagetitle, pagemsg,
            expand_text, origt, add_brackets)
        if tr and "," in tr:
          chopped_tr = re.sub(",.*", "", tr)
          pagemsg("WARNING: Comma in translit <%s>, chopping off text after the comma to <%s>" % (
            tr, chopped_tr))
          tr = chopped_tr
        newwords.append(ru)
        newtrwords.append(tr)
        # If we saw a manual translit word, note it (see above).
        if tr:
          sawtr = True
      else:
        # Else, a separator or blank word. Just copy it. If it has
        # translit, copy that as well, else copy the separator/blank word
        # directly as the translit (all the separator tokens should
        # pass through translit unchanged). Only flag the need for
        # manual translit expansion if there's an existing manual
        # translit of the separator that's different from the
        # separator itself, i.e. different from what auto-translit
        # would produce. (FIXME: It's arguably an error if the
        # manual translit of a separator is different from the
        # separator itself. We output a warning but maybe we should
        # override the manual translit entirely.)
        newwords.append(word)
        newtrwords.append(trword or word)
        if trword and word != trword:
          pagemsg("WARNING: Separator <%s> at index %s has manual translit <%s> that's different from it: %s" % (
            word, i, trword, origt))
          sawtr = True
    if sawtr:
      newertrwords = []
      got_error = False
      for ru, tr in zip(newwords, newtrwords):
        if tr:
          pass
        elif not ru:
          tr = ""
        else:
          tr = expand_text("{{xlit|ru|%s}}" % ru)
          if not tr:
            got_error = True
            pagemsg("WARNING: Got error during transliteration")
            break
        newertrwords.append(tr)
      if not got_error:
        newterm = "".join(newwords)
        newtr = "".join(newertrwords)
    else:
      newterm = "".join(newwords)
      newtr = ""
  return newterm, newtr

def bracket_term_with_lemma(term, lemma, pagetitle):
  if lemma is True:
    if ru.remove_accents(term) == pagetitle:
      return "'''%s'''" % term
    else:
      return "[[%s]]" % term
  elif lemma:
    if lemma == pagetitle:
      return "'''%s'''" % term
    else:
      return "[[%s|%s]]" % (lemma, term)
  else:
    if ru.remove_accents(term) == pagetitle:
      return "'''%s'''" % term
    else:
      return term

# Look up a term (and associated manual translit) and try to add accents.
# The basic algorithm is that we first look up the whole term and then
# split on words and recursively look up each word individually.
# We are currently able to handle some bracketed expressions but not all:
#
# (1) If we're passed in [[FOO]] or [[FOO BAR]], we handle it as a special
#     case by recursively looking up the text inside the link.
# (2) If we're passed in [[FOO|BAR]] or [[FOO BAR|BAZ BAT]], we handle it as
#     another special case by recursively looking up the text on the right
#     side of the vertical bar.
# (3) If we're passed in [[FOO]] [[BAR]], [[FOO]] [[BAR|BAZ]] or
#     [[FOO|BAR]] [[BAZ|BAT]], special cases (1) and (2) won't apply. We then
#     will reject it (i.e. leave it unchanged) during the first lookup but
#     then succeed during the recursive (word-split) version, because we
#     will recursively be able to handle the individual parts by cases
#     (1) and (2).
# (4) If we're passed in [[FOO BAR]] [[BAZ]], or any other expression with
#     a space inside of a link that isn't the entire term, we can't currently
#     handle it. Word splitting will leave unbalanced "words" [[FOO and BAR]],
#     which we will trigger a rejection of the whole expression (i.e. it will
#     be left unchanged).
def find_accented_1(term, termtr, verbose, pagetitle, pagemsg, expand_text,
    origt, add_brackets):
  # (1) Handle plain [[FOO]] or [[FOO BAR]].
  m = re.search(r"^\[\[([^\[\]\|]*)\]\]$", term)
  if m:
    newterm, newtr = find_accented(m.group(1), termtr, verbose, pagetitle,
      pagemsg, expand_text, origt, add_brackets)
    if "[" not in newterm:
      return "[[%s]]" % newterm, newtr
    if re.search(r"^\[\[([^\[\]]*)\]\]$", newterm):
      # If entire term is already bracketed, just return it.
      if "|" in newterm:
        pagemsg("WARNING: Already bracketed term %s referencing non-lemma, replacing with lemma reference %s" %
          (term, newterm))
      return newterm, newtr
    # Interior words in term were bracketed; remove the bracketed links.
    return "[[%s]]" % blib.remove_links(newterm), newtr

  # (2) Handle [[FOO|BAR]] or [[FOO BAR|BAZ BAT]].
  m = re.search(r"^\[\[([^\[\]\|]*)\|([^\[\]\|]*)\]\]$", term)
  if m:
    newterm, newtr = find_accented(m.group(2), termtr, verbose, pagetitle,
      pagemsg, expand_text, origt, False)
    return "[[%s|%s]]" % (m.group(1), newterm), newtr

  # (3) Handle '''FOO''' or '''FOO BAR'''.
  m = re.search(r"^'''([^'\n]+)'''$", term)
  if m:
    newterm, newtr = find_accented(m.group(1), termtr, verbose, pagetitle,
      pagemsg, expand_text, origt, False)
    return "'''%s'''" % newterm, newtr

  # (4) Otherwise, look up the whole term.
  newterm, newtr, lemma = lookup_term_for_accents(term, termtr, verbose,
    pagemsg)

  # (5) If we couldn't match the whole term, split into individual words
  #     and try looking up each one.
  if newterm == term and newtr == termtr:
    # If the whole term is/has a lemma, don't add brackets to inner terms
    # because we will bracket the whole term.
    inner_add_brackets = add_brackets
    if lemma:
      inner_add_brackets = False
    words = re.split(r"('''.*?'''|''[^'\n]*?''|\[\[.*?\]\]|[^ ,.?!]+)", term)
    trwords = (re.split(r"('''.*?'''|''[^'\n]*?''|\[\[.*?\]\]|[^ ,.?!]+)", termtr)
      if termtr else [])
    if trwords and len(words) != len(trwords):
      pagemsg("WARNING: %s Cyrillic words but different number %s translit words: %s//%s" % (len(words), len(trwords), term, termtr))
    elif (len(words) == 3 and not words[0] and not words[2] and
        words[1][0] not in "'[]"):
      # Just a single word, not surrounded by brackets or '''...''' or ''...''.
      if term.startswith("-") or term.endswith("-"):
        # Don't separate a prefix or suffix into component parts; might
        # not be the same word.
        pass
      else:
        # Only one word, and we already looked it up; don't duplicate work.
        # But split on hyphens the second time around.
        words = re.split(r"([^-]+)", term)
        trwords = re.split(r"([^-]+)", termtr) if termtr else []
        if trwords and len(words) != len(trwords):
          pagemsg("WARNING: %s Cyrillic words but different number %s translit words: %s//%s" % (len(words), len(trwords), term, termtr))
          pass
        elif (len(words) == 3 and not words[0] and not words[2] and
            words[1][0] not in "'[]"):
          # Only one word, and we already looked it up; don't duplicate work
          # or get stuck in infinite loop.
          pass
        else:
          newterm, newtr = find_accented_split_words(term, termtr, words,
            trwords, verbose, pagetitle, pagemsg, expand_text, origt,
            inner_add_brackets)
    else:
      newterm, newtr = find_accented_split_words(term, termtr, words, trwords,
        verbose, pagetitle, pagemsg, expand_text, origt, inner_add_brackets)

  if add_brackets:
    newterm = bracket_term_with_lemma(newterm, lemma, pagetitle)

  return newterm, newtr

# Outer wrapper, equivalent to find_accented_1() except outputs extra
# log messages if --semi-verbose.
def find_accented(term, termtr, verbose, pagetitle, pagemsg, expand_text,
  origt, add_brackets):
  if semi_verbose:
    pagemsg("find_accented: Call with term %s%s" % (term, "//%s" % termtr if termtr else ""))
  term, termtr = find_accented_1(term, termtr, verbose, pagetitle, pagemsg,
    expand_text, origt, add_brackets)
  if semi_verbose:
    pagemsg("find_accented: Return %s%s" % (term, "//%s" % termtr if termtr else ""))
  return term, termtr

def join_changelog_notes(notes):
  accented_words = []
  other_notes = []
  for note in notes:
    m = re.search("^auto-accent (.*)$", note)
    if m:
      accented_words.append(m.group(1))
    else:
      other_notes.append(note)
  if accented_words:
    notes = ["auto-accent %s" % ",".join(accented_words)]
  else:
    notes = []
  notes.extend(other_notes)
  return "; ".join(notes)

def check_need_accent(text):
  for word in re.split(" +", text):
    word = blib.remove_links(word)
    if AC in word or u"ё" in word:
      continue
    if not ru.is_monosyllabic(word):
      return True
  return False

def normalize_text(text):
  return ru.remove_accents(blib.remove_links(text)).replace("'''", "")

def process_template(pagetitle, index, template, ruparam, trparam, output_line,
    find_accents, verbose):
  origt = unicode(template)
  saveparam = ruparam
  def pagemsg(text):
    msg("Page %s %s: %s" % (index, pagetitle, text))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, semi_verbose)
  if semi_verbose:
    pagemsg("Processing template: %s" % unicode(template))
  if unicode(template.name) == "head":
    # Skip {{head}}. We don't want to mess with headwords.
    return False
  if isinstance(ruparam, list):
    ruparam, saveparam = ruparam
  if ruparam == "page title":
    val = pagetitle
  else:
    val = getparam(template, ruparam)
  valtr = getparam(template, trparam) if trparam else ""
  changed = False
  if find_accents:
    newval, newtr = find_accented(val, valtr, verbose, pagetitle, pagemsg,
      expand_text, origt, unicode(template.name) in link_expandable_templates)
    if newval != val or newtr != valtr:
      if normalize_text(newval) != normalize_text(val):
        pagemsg("WARNING: Accented page %s changed from %s in more than just accents/links/boldface, not changing" % (newval, val))
      else:
        changed = True
        addparam(template, saveparam, newval)
        if newtr:
          if not trparam:
            pagemsg("WARNING: Unable to change translit to %s because no translit param available (Cyrillic param %s): %s" %
                (newtr, saveparam, origt))
          elif unicode(template.name) in ["ru-ux"]:
            pagemsg("WARNING: Not changing or adding translit param %s=%s to ru-ux: origt=%s" % (
              trparam, newtr, origt))
          else:
            if valtr and valtr != newtr:
              pagemsg("WARNING: Changed translit param %s from %s to %s: origt=%s" %
                  (trparam, valtr, newtr, origt))
            if not valtr:
              pagemsg("NOTE: Added translit param %s=%s to template: origt=%s" %
                  (trparam, newtr, origt))
            addparam(template, trparam, newtr)
        elif valtr:
          pagemsg("WARNING: Template has translit %s but lookup result has none, leaving translit alone: origt=%s" %
              (valtr, origt))
        if check_need_accent(newval):
          output_line("Need accents (changed)")
        else:
          output_line("Found accents")
  if not changed and check_need_accent(val):
    output_line("Need accents")
  if changed:
    pagemsg("Replaced %s with %s" % (origt, unicode(template)))
  return ["auto-accent %s%s" % (newval, "//%s" % newtr if newtr else "")] if changed else False

def find_russian_need_vowels(find_accents, cattype, direcfile, save,
    verbose, startFrom, upTo):
  if direcfile:
    processing_lines = []
    for line in codecs.open(direcfile, "r", encoding="utf-8"):
      line = line.strip()
      m = re.match(r"^(Page [^ ]+ )(.*?)(: .*?:) Processing: (\{\{.*?\}\})( <- \{\{.*?\}\} \(\{\{.*?\}\}\))$",
          line)
      if m:
        processing_lines.append(m.groups())

    for current, index in blib.iter_pages(processing_lines, startFrom, upTo,
        # key is the page name
        key = lambda x:x[1]):

      pagenum, pagename, tempname, repltext, rest = current

      def pagemsg(text):
        msg("Page %s(%s) %s: %s" % (pagenum, index, pagetitle, text))
      def check_template_for_missing_accent(pagetitle, index, template,
          templang, ruparam, trparam):
        def output_line(directive):
          msg("* %s[[%s]]%s %s: <nowiki>%s%s</nowiki>" % (pagenum, pagename,
              tempname, directive, unicode(template), rest))
        return process_template(pagetitle, index, template, ruparam, trparam,
            output_line, find_accents, verbose)

      blib.process_links(save, verbose, "ru", "Russian", "pagetext", None,
          None, check_template_for_missing_accent,
          join_actions=join_changelog_notes, split_templates=None,
          pages_to_do=[(pagename, repltext)], quiet=True)
      if index % 100 == 0:
        output_stats(pagemsg)
  else:
    def check_template_for_missing_accent(pagetitle, index, template, templang,
        ruparam, trparam):
      def pagemsg(text):
        msg("Page %s %s: %s" % (index, pagetitle, text))
      def output_line(directive):
        pagemsg("%s: %s" % (directive, unicode(template)))
      result = process_template(pagetitle, index, template, ruparam, trparam,
          output_line, find_accents, verbose)
      if index % 100 == 0:
        output_stats(pagemsg)
      return result

    blib.process_links(save, verbose, "ru", "Russian", cattype, startFrom,
        upTo, check_template_for_missing_accent,
        join_actions=join_changelog_notes, split_templates=None)

pa = blib.init_argparser("Find Russian terms needing accents")
pa.add_argument("--cattype", default="vocab",
    help="Categories to examine ('vocab', 'borrowed', 'translation')")
pa.add_argument("--file",
    help="File containing output from parse_log_file.py")
pa.add_argument("--semi-verbose", action="store_true",
    help="More info but not as much as --verbose")
pa.add_argument("--find-accents", action="store_true",
    help="Look up the accents in existing pages")
pa.add_argument("--no-cache", action="store_true",
    help="Disable caching head lookup results")

params = pa.parse_args()
semi_verbose = params.semi_verbose or params.verbose
global_disable_cache = params.no_cache
startFrom, upTo = blib.parse_start_end(params.start, params.end)

find_russian_need_vowels(params.find_accents, params.cattype,
    params.file, params.save, params.verbose, startFrom, upTo)

blib.elapsed_time()

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# This script adds accents, links and boldface to Russian text inside of templates like {{l|ru|...}}, {{m|ru|...}},
# {{ux|ru|...}}, etc. This is done by looking up words in the dictionary and adding information if it's unambiguous
# (e.g. we don't add accents to a term if it has multiple possible accentuations, and we don't add links to a term if
# it corresponds to multiple possible lemmas). We're actually somewhat smarter than this, e.g. we first try looking up
# the whole phrase, then partition into linked blocks of words and individual non-linked words and look them up, and
# then break up linked blocks of words into single words and look them up, and finally break individual words on
# hyphens and look up the components.
#
# Note:
#
# (1) Only acute accents are added (grave accents should not be present
#     in headwords, links, or anywhere else except pronunciations).
# (2) Links are of the form [[TERM]] if the term is a lemma, otherwise
#     [[LEMMA|TERM]], where in both cases TERM should have accents but LEMMA
#     not. Links are only added to templates that contain example text (e.g.
#     not including {{l}} or {{m}}, which are themselves links to a page
#     consisting of the entire text), and only to templates that allow such
#     links (which is most templates with a language parameter, but doesn't
#     include {{w}} or {{wikipedia}}).
# (3) Boldface consists of the form '''TERM''', and is used in place of a
#     link if the link would be to the page itself on which the term occurs.
#
# GENERAL COMMENTS ON THE CODE:
#
# (1) We use a cache to avoid multiple page lookups of the same term, because
#     page lookups are expensive (the server only allows about 6 of them per
#     second). This results in dramatic speedups; the overall hit rate for
#     the entire run is > 87%.
# (2) Numerous functions take and/or return params TERM (Cyrillic text
#     referring to a term looked up or to be looked up) and corresponding
#     manual transliteration TERMTR. TERMTR is a non-blank string only if
#     the term has an irregular transliteration (e.g. bártɛr for ба́ртер),
#     and is otherwise a blank string, i.e. "".
# (3) Numerous functions take a param PAGEMSG, which is a single-argument
#     function that outputs a message to stdout, prefixed by the index and
#     name of the page on which the term occurs, in a form like this:
#
#     Page 72 абажур: find_accented: Call with term дежу́рный
#
#     The PAGEMSG function itself adds the text up through the first colon
#     and following space. The calling function should generally include its
#     name in the message, as in the example above, output by find_accented().
#     Many messages are output only if --semi-verbose or --verbose is
#     specified, and some functions accordingly take a VERBOSE parameter
#     (FIXME, convert to a global variable, as with 'semi_verbose').
#
# FIXME:
#
# 1. (DONE AS PART OF SMARTER WORD SPLITTING) Handle '''FOO''', matched up
#    against blank tr, TR or '''TR'''. Cf. '''спасти''' in 23865 спасти.
# 2. (DONE) Handle multiword expressions *inside* of find_accented so we
#    can handle e.g. the multiword linked expressions in 24195 стан, such
#    as [[нотный стан]] and [[передвижной полевой стан]].
# 3. (DONE) Handle single-word two-part links [[FOO|BAR]].
# 4. (DONE?) Consider implementing support for [[FOO BAR]] [[BAZ]]. To do this
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
# 14. (DONE) If we repeat this script, we should handle words that occur
#    directly after a stressed monosyllabic preposition and not auto-accent
#    them. The list of such prepositions is без, близ, во, да, до, за, из, ко,
#    меж, на, над, не, ни, об, от, по, под, пред, при, про, со, у. I don't
#    think multisyllabic unstressed prepositions can steal accent from a
#    following word; need to ask Anatoli/Wikitiki89 about this.
# 15. FIXME! There may data loss in a case like
#    {{lang|ru|{{l|ru|это|Это}} клёвее.}}, which may mistakenly get replaced
#    with {{l|ru|это|Это}} (formerly found on the [[клёвее]] page). NEED TO
#    CHECK WHETHER THIS ERROR STILL HAPPENS.
# 16. (DONE) Add links of the form [[LEMMA|FORM]] and '''FORM'''.
# 17. (DONE) Add links also for adjectives where we don't generate pages for
#     the non-lemma forms.
# 18. (DONE) Don't auto-accent templates inside of a #* line.
# 19. (DONE) Use subst= in ux/uxi/quote/usex.
# 20. (DONE) Avoid creating excessive translit with genitive adj forms in
#     -ого/-его. See 305 абы for an example.
# 21. (DONE) Handle capitalized forms at beginning of line.
# 22. (DONE) Treat single-letter words as lowercase equivalents even when
#     capitalized, to avoid them being treated as letters.
# 23. (DONE) In 2297 баланс, is inserting '''...''' inside of brackets.
# 24. (DONE) Don't include parens or stray brackets in words.
# 25. Don't include sequences of two '' in words.
# 26. (DONE) Add support for short forms of adjectives (esp. participles).
# 27. (DONE) Add support for overriding lemma/inflection lookup for certain
#     common words where lookup fails due to lemma + non-lemma on same page
#     (e.g. бы́ло, как, пять).
# 28. (DONE) If already accented, use that to filter heads, e.g. 4370 валить
#     with ку́чу (noun only, not кучу́ verb).
# 29. (DONE) If subst= already present, don't augment it in ux/uxi/usex/quote;
#     or check if existing subst= handles all translit, and only augment if
#     not.
# 30. (DONE) Instead of chopping off stuff after comma, replace with slash.
# 31. (DONE) Бог has subst='''Бог'''/Бох.
# 32. (WON'T DO) Normalize forms lacking ё if page has ru-adj-alt-ё or similar.
# 33. (DONE) Don't auto-accent cases like alt1=галер(е́я) on page галёрка, where
#     we would try to convert it to гале́р(е́я).
# 34. Implement auto-accenting of pre-reform spellings.

# Implementing auto-accenting of pre-reform spellings:
#
# If we encounter a word that looks pre-reform, either because it ends in -ъ,
# or has ѣ or і or ѳ or ѵ in it, or has раз/роз/из/воз directly followed by an
# unvoiced obstruent, we can programmatically generate the corresponding modern
# spelling, look that up for accents and lemma, and try to slide the old letters
# back in. The way to do that with the accents is to count how many vowels from
# the left the accent is on, and put it on the same-nth vowel in the pre-reform
# spelling. This assumes that the number of vowels is the same between pre-reform
# and corresponding modern spelling; we should check this. The way to put the
# old letters back in the lemma is to find the maximum prefix (ignoring accent marks)
# that matches between the lemma and the modern-spelled form, and take the
# corresponding number of letters from the pre-reform spelling of the form and put
# them at the beginning of the lemma. Then make any systemic adjustments at the end
# (convert и + vowel (including й) to і; add ъ onto the end of words that end in a
# consonant that isn't ь, ъ or й; convert -еть in verbs to -ѣть; may have to
# special-case some lemmas; convert -ее in comparatives [but apparently not in neuter
# singulars] to -ѣе). There will need to be some special-casing here and there; we
# might be able to short-circuit this by creating the appropriate inflected forms
# in a few cases, e.g. сѣсть, лѣзть. We'll have to do some additional work in the
# code that infers adjective forms, since -аго/-яго is a possible genitive, and some
# of the endings have an extra -ъ on them, and there's an extra fem/neut plural -ыя/-ія.

import re, codecs

import blib, pywikibot
from blib import msg, getparam, addparam
import rulib
import ruheadlib
import ru_reverse_translit

site = pywikibot.Site()
semi_verbose = False # Set by --semi-verbose or --verbose

AC = u"\u0301" # acute =  ́
GR = u"\u0300" # grave =  ̀

# List of accentless multisyllabic words that are lemmas.
accentless_multisyllable_lemma = [u"надо", u"обо", u"ото",
  u"перед", u"передо", u"подо", u"предо", u"через"]
# List of all accentless multisyllabic words.
accentless_multisyllable = [u"либо", u"нибудь"] + accentless_multisyllable_lemma
# List of templates with a subst= parameter that can be used in place of
# manual transliteration.
templates_with_subst = ["ux", "uxi", "quote", "usex",
  "quote-book", "quote-hansard", "quote-journal", "quote-newsgroup",
  "quote-song", "quote-us-patent", "quote-video", "quote-web",
  "quote-wikipedia"]
# List of templates for which we can add bracketed links to terms.
# FIXME: Add support for subst= to Q at least.
link_expandable_templates = templates_with_subst + ["Q"]

# List of monosyllabic prepositions.
monosyllabic_prepositions = [u"без", u"близ", u"во", u"да", u"до", u"за",
    u"из", u"ко", u"меж", u"на", u"над", u"не", u"ни", u"о", u"об", u"от",
    u"по", u"под", u"пред", u"при", u"про", u"со", u"у"]
# Derived list of accented equivalents of above, for use with expressions
# like до́ смерти, where the word following an accented monosyllabic
# preposition should remain unaccented.
monosyllabic_accented_prepositions = [
    prep + AC for prep in monosyllabic_prepositions
]
# For these words, ignore the capitalized variant even when the word is
# capitalized, because we almost always want the lowercase equivalent.
# This applies to all the common single-letter words that may appear at the
# beginning of a sentence (not including [[б]] and [[ж]]), and also to
# вы (where Вы is an alternative letter-case form) and по (where По is a
# proper name, either the Po river or Edgar Allan Poe).
ignore_capitalized_variant_words = [u"я", u"в", u"с", u"к", u"о", u"а", u"у", u"и",
  u"вы", u"по"]

# Regex range of Cyrillic characters.
cyrillic_char_range = u"Ѐ-џҊ-ԧꚀ-ꚗ"
# Regex for a word ending in a possibly-accented Cyrillic char.
ends_in_cyrillic_re = r"[%s][" % cyrillic_char_range + AC + GR + "]?$"
# Regex for a word beginning in a Cyrillic char.
begins_in_cyrillic_re = r"^[%s]" % cyrillic_char_range

# List of possible stem categories of adjectives where the first letter of
# the ending is as specified. For example, the entry for u"ы" means that any
# ending found that starts in ы (e.g. -ый, -ым, -ыми, -ых) can occur only in
# hard-stem adjectives or ц-stem adjectives. This is used to derive the
# corresponding lemma, in this case by adding -ий if the stem ends in ц and
# -ый otherwise. The possible categories are:
#
# "hard": Hard-stem adjective ending in -ый or -ой where the last stem
#         consonant is not a velar, hushing sound or ц.
# "soft": Soft-stem adjective ending in -ий where the last stem consonant is
#         not a velar, hushing sound or ц.
# "velar": Velar-stem adjective ending in -ий where the last stem consonant is
#          a velar (к, г or х).
# "hush-unacc": Hushing-stem unaccented-ending adjective ending in -ий where
#               the last stem consonant is a hushing consonant (ш, ж, ч or щ).
# "hush-acc": Hushing-stem accented-ending adjective ending in -ой where
#             the last stem consonant is a hushing consonant (ш, ж, ч or щ).
# "ts": Ц-stem adjective ending in -ий or -ой where the last stem consonant
#       is ц.
# "poss": Possessive-stem adjective ending in -ий where the last stem consonant
#         can be anything (handled specially, and identified specially by an
#         ending beginning with -ь).
#
# Note that there is also special handling for short forms of participles in
# -нный and -мый. Otherwise we don't currently recognize short adjective forms,
# because (a) the most common adjectives already have short non-lemma forms
# created, and (b) it would greatly increase the number of lookups as we'd
# have to do adjective lookup for essentially every term (since any term ending
# in a consonant or in -а, -я, -о, -е, -ы or -и can potentially be a short
# form of an adjective).
adj_endings_first_letter = {
  u"о": ["hard", "hush-acc", "velar"],
  u"е": ["soft", "hush-unacc", "ts"],
  u"а": ["hard", "velar", "hush-acc", "hush-unacc", "ts"],
  u"я": ["soft"],
  u"ы": ["hard", "ts"],
  u"и": ["soft", "velar", "hush-acc", "hush-unacc"],
  u"у": ["hard", "velar", "hush-acc", "hush-unacc", "ts"],
  u"ю": ["soft"],
}

# Check if a piece of text is missing one or more accents. The algorithm is
# to split on words and check for multisyllabic words that lack both an
# acute accent and a ё.
def check_need_accent(text):
  for word in re.split(" +", text):
    word = blib.remove_links(word)
    if AC in word or u"ё" in word:
      continue
    if not rulib.is_monosyllabic(word):
      return True
  return False

# Return whether two Russian terms (which may be multi-word) match. We allow
# a mismatch in accents for monosyllabic words, otherwise the words must match
# exactly including accents.
def terms_match(ru1, ru2):
  words1 = re.split(" +", ru1)
  words2 = re.split(" +", ru2)
  if len(words1) != len(words2):
    return False
  for word1, word2 in zip(words1, words2):
    if rulib.is_monosyllabic(word1):
      if rulib.remove_accents(word1) != rulib.remove_accents(word2):
        return False
    else:
      if word1 != word2:
        return False
  return True

# For a possible adjective form, return the lemmas that it might belong to.
def get_adj_form_lemmas(form):
  if re.search(u"(ье|ья|ьи|ью)$", form):
    bases = [form[:-2]]
    types = ["poss"]
  elif re.search(u"(ьей|ьих|ьим|ьею|ьем)$", form):
    bases = [form[:-3]]
    types = ["poss"]
  elif re.search(u"(ьего|ьему|ьими)$", form):
    bases = [form[:-4]]
    types = ["poss"]
  elif re.search(u"(ое|ее|ая|яя|ые|ие|ой|ей|ых|их|ым|им|ую|юю|ою|ею|ом|ем)$", form):
    bases = [form[:-2]]
    types = adj_endings_first_letter[form[-2]]
  elif re.search(u"(ого|его|ому|ему|ыми|ими)$", form):
    bases = [form[:-3]]
    types = adj_endings_first_letter[form[-3]]
  # For the moment, only do short participles, not all short adjectives.
  elif re.search(u"[ёеая]н$", form):
    bases = [form, form + u"н"]
    types = ["hard"]
  elif re.search(u"[еая]н[аоы]$", form):
    base1 = form[:-1]
    base2 = re.sub(u"ен$", u"ён", base1)
    bases = [base1 + u"н"]
    if base2 != base1:
      bases.extend([base2 + u"н"])
    types = ["hard"]
  elif re.search(u"[еи]м$", form):
    bases = form
    types = ["hard"]
  elif re.search(u"[еи]м[аоы]$", form):
    bases = [form[:-1]]
    types = ["hard"]
  else:
    return []
  lemmas = []
  for base in bases:
    if not base:
      continue
    if "poss" in types:
      lemmas.append(base + u"ий")
    elif base[-1] == u"ц":
      if "ts" in types:
        lemmas.append(base + u"ый")
        if not form.endswith(u"ой"):
          lemmas.append(base + u"ой")
    elif base[-1] in u"шжчщ":
      if "hush-unacc" in types:
        lemmas.append(base + u"ий")
      if "hush-acc" in types and not form.endswith(u"ой"):
        lemmas.append(base + u"ой")
    elif base[-1] in u"кгх":
      if "velar" in types:
        lemmas.append(base + u"ий")
        if not form.endswith(u"ой"):
          lemmas.append(base + u"ой")
    else:
      if "hard" in types:
        lemmas.append(base + u"ый")
        if not form.endswith(u"ой"):
          lemmas.append(base + u"ой")
      if "soft" in types:
        lemmas.append(base + u"ий")
    # no end-accented soft adjectives
  return lemmas

# Look up a single term (which may be multi-word), consisting of a Cyrillic
# TERM and corresponding manual translit TERMTR (which will be a blank string
# if there is no manual translit). If the page exists, retrieve and return the
# headword(s) and lemma(s) (the term may itself be a lemma, or it may be the
# non-lemma form of some lemma). If there are any problems, return the term
# unchanged. A problem is any of the following:
#
# -- page doesn't exist or is a redirect
# -- multiple distinct headwords
# -- multiple distinct lemmas
# -- term is both a lemma and non-lemma
#
# The return value is (NEWTERM, NEWTERM_TR, LEMMA) where missing
# transliteration is returned as "", and LEMMA is None if no lemma is available
# or True if the term itself is a lemma, else a string.
#
# The argument are TERM and TERMTR as described above; VERBOSE and PAGEMSG
# as described in the comments at the top of the file; and EXPECT_CAP.
#
# EXPECT_CAP is True if we expect the first letter of the term to be
# capitalized even if the term is properly lowercase. If this is the case, and
# the term is capitalized and can't be found, we look up the lowercase
# equivalent of the term. For example, if the term is Время and EXPECT_CAP is
# True, we will first look up Время (which doesn't exist) and then время (which
# does exist as a lemma with accentuation вре́мя), and we will return Вре́мя as
# the accented term and время as the lemma, with the result that the bare term
# Время will be replaced with [[время|Вре́мя]]. Note also that we special-case
# a few common words where the capitalized equivalent is also a term but is
# rare, and we don't want that capitalized term to be used. Examples are
# single-word terms such as я, и, о, etc. (the corresponding capitalized term
# is a letter term) as well as вы (Вы is an alternative-case form) and по
# (По is a river in Italy and an English surname Poe). In such cases, we ignore
# the capitalized variant; otherwise, for example, the frequent occurrences of
# Я and Вы at the beginning of a sentence would be wrongly linked as [[Я]] and
# [[Вы]] instead of the correct [[я|Я]] and [[вы|Вы]].
def lookup_term_for_accents(term, termtr, verbose, pagemsg, expect_cap):
  # Blank terms should never happen; if they do, they will cause errors in
  # the capitalization frobbing below, so special-case them.
  if not term:
    pagemsg("WARNING: lookup_term_for_accents: Passed in blank term, shouldn't happen")
    return term, termtr, None

  # Special-case accentless multisyllables; don't try adding an accent.
  if term in accentless_multisyllable:
    pagemsg("lookup_term_for_accents: Not accenting unaccented multisyllabic particle %s" % term)
    if term in accentless_multisyllable_lemma:
      return term, termtr, True
    else:
      return term, termtr, None

  # Skip terms with links or HTML in them. The caller will then split on
  # words and linked blocks and call us again on the individual components.
  if "|" in term:
    pagemsg("lookup_term_for_accents: Can't handle links with vertical bars: %s" % term)
    return term, termtr, None
  if "[" in term or "]" in term:
    pagemsg("lookup_term_for_accents: Can't handle stray bracket in %s" % term)
    return term, termtr, None
  if "<" in term or ">" in term:
    pagemsg("lookup_term_for_accents: Can't handle stray < or >: %s" % term)
    return term, termtr, None

  # Check for special-case capitalized words like Я and По, which we always
  # treat as capitalized variants of properly lowercase words, ignoring the
  # fact that the capitalized term it itself a lemma, as described in the
  # comment to this function.
  real_pagename = rulib.remove_accents(term)
  decapitalized_pagename = real_pagename[0].lower() + real_pagename[1:]
  if decapitalized_pagename in ignore_capitalized_variant_words:
    if real_pagename == decapitalized_pagename:
      return term, termtr, True
    else:
      return term, termtr, decapitalized_pagename

  # Pages to consider: If EXPECT_CAP, both the pagename (i.e. the term minus
  # any accents) and its lowercase equivalent, otherwise just the pagename.
  # See the comment to this function.
  if expect_cap:
    pagenames_to_consider = [real_pagename, decapitalized_pagename]
  else:
    pagenames_to_consider = [real_pagename]

  # Loop over pages to consider (see preceding comment).
  for pagename in pagenames_to_consider:
    if pagename == real_pagename:
      maybe_decap_term = term
    else:
      maybe_decap_term = term[0].lower() + term[1:]

    # First look up the page.
    if semi_verbose:
      pagemsg("lookup_term_for_accents: Finding heads on page %s" % pagename)

    cached, cache_result = ruheadlib.lookup_heads_and_inflections(pagename, pagemsg)
    if cache_result is None or cache_result in ["redirect", "no-russian"]:
      heads = set()
      inflections_of = set()
      adj_forms = set()
    else:
      heads, inflections_of, adj_forms = cache_result

    # Then look up any adjectives of which the page may be a form. We do this
    # specially because we currently create pages for non-lemma forms of
    # nouns, verbs, pronouns and numerals, but not for non-short forms of
    # regular adjectives: This would blow up the number of non-lemma pages
    # even more than currently, and in general, non-short adjective forms
    # are relatively easy to recognize and convert to the corresponding lemma
    # (because the endings are relatively long and are usually unambiguous,
    # e.g. -ых is only an adjective ending and any form ending in -ых is
    # probably an adjective form), while this is less the case for nouns and
    # verbs (as well as short adjective forms), due to (a) the shortness of
    # the endings, (b) the complexities of accentuation and inflection, and
    # (c) the frequent homophony between inflections of different lemmas and
    # between lemmas and non-lemam forms.
    adj_lemmas = get_adj_form_lemmas(pagename)
    for adj_lemma in adj_lemmas:
      adj_cached, adj_cache_result = ruheadlib.lookup_heads_and_inflections(adj_lemma, pagemsg)
      if adj_cache_result is not None and (
          adj_cache_result not in ["redirect", "no-russian"]):
        _, _, this_adj_forms = adj_cache_result
        for adj_form_one_or_more in this_adj_forms:
          # Each "form" is actually one or more forms separated by commas.
          # In some cases we have e.g. ла́зерная,ла́зерная//lázɛrnaja, which
          # we want to convert to ru="ла́зерная", tr="lázernaja, lázɛrnaja".
          split_adj_forms = re.split(",", adj_form_one_or_more)
          split_adj_forms = [ruheadlib.split_ru_tr(adj_form, pagemsg) for adj_form in split_adj_forms]
          # Group lemmas by Russian, to group multiple translits.
          split_adj_forms = rulib.group_translits(split_adj_forms, pagemsg, semi_verbose)
          for adj_form_ru, adj_form_tr in split_adj_forms:
            if rulib.remove_accents(adj_form_ru) == pagename:
              this_head_entry = (adj_form_ru, adj_form_tr, False)
              heads.add(this_head_entry)
              inflections_of.add((frozenset({this_head_entry}), adj_lemma))
          # FIXME! If has accents, check that accents match adj form.
          # This is tricky in the context of capitalization.

    # ------- At this point we have the heads and lemmas of the term. -------

    # First, if the term was already accented, filter heads and inflections
    # to only those with the same accentuation. The accent is often enough
    # to disambiguate lemmas from non-lemmas and forms of different lemmas.
    if AC in maybe_decap_term: # don't check for ё in case of multiword exprs.
      heads = set((ru, tr, is_lemma) for ru, tr, is_lemma in heads
          if terms_match(ru, maybe_decap_term))
      new_inflections_of = set()
      for h, l in inflections_of:
        h = frozenset((ru, tr, is_lemma) for ru, tr, is_lemma in h
            if terms_match(ru, maybe_decap_term))
        if h:
          new_inflections_of.add((h, l))
      inflections_of = new_inflections_of

    # Check if the term might be a lemma.
    saw_lemma = any(is_lemma for ru, tr, is_lemma in heads)

    def stringize_heads(heads):
      return ",".join("%s%s%s" % (
        ru, "//%s" % tr if tr else "", "[lemma]" if is_lemma else "")
        for ru, tr, is_lemma in heads)

    def stringize_inflections_of(inflections_of):
      return "; ".join("%s:%s" % (stringize_heads(heads), lemma)
          for heads, lemma in inflections_of)

    cached_msg = (
      " (cached)" if cached is True else
      " (manual override)" if cached == "manual-override" else
      "")

    if len(heads) == 0:
      # We couldn't find any headword templates. If the page exists and isn't
      # a redirect, this shouldn't normally happen, so issue a warning.
      if cache_result is not None and (
          cache_result not in ["redirect", "no-russian"]):
        pagemsg("WARNING: lookup_term_for_accents: Can't find any heads: %s%s" % (pagename, cached_msg))
      # We might have a sentence-initial capitalized word; continue checking
      # the non-capitalized equivalent.
      continue

    # This is a signal in the case of multiple heads that are the same except
    # some are lemmas and some are non-lemmas. In this case we need to return
    # None as the lemma but otherwise proceed as normal, esp. in handling
    # capitalized vs. non-capitalized variants.
    need_none_lemma = False

    if len(heads) > 1:
      # If multiple heads, check again but this time ignore the is_lemma flag.
      # We may have a case like восьмо́й, both a lemma and an inflection of
      # восьма́я. In this case we can still accent but not add brackets.
      heads_ignoring_lemma = set((ru, tr) for ru, tr, is_lemma in heads)
      if len(heads_ignoring_lemma) == 1:
        pagemsg("lookup_term_for_accents: Found multiple heads for %s%s but all match except some are lemmas and some non-lemmas: %s" % (
          pagename, cached_msg, stringize_heads(heads)))
        newterm, newtr = list(heads_ignoring_lemma)[0]
        need_none_lemma = True
      else:
        pagemsg("WARNING: lookup_term_for_accents: Found multiple heads for %s%s: %s" % (pagename, cached_msg, stringize_heads(heads)))
        return term, termtr, None
    else:
      newterm, newtr, is_lemma = list(heads)[0]

    if pagename != real_pagename:
      # We were asked to consider a capitalized word, decided to look up the
      # non-capitalized equivalent and found a match. We need to transfer the
      # accents and translit to the capitalized equivalent.
      if not newterm:
        pagemsg("WARNING: Something wrong! Found blank head when looking up %s" % pagename)
        return term, termtr, None
      # In order to combine the accents on the canonical lowercase term with
      # the capitalized unaccented term we actually have, we need to combine
      # the first letter of the capitalized term with the remainder of the
      # canonical lowercase term. To do this correctly, we need to first
      # decompose composed accented characters (i.e. where a single Unicode
      # character consists of both a letter and an accent), then combine,
      # then recompose. (In practice, this isn't really necessary for Cyrillic,
      # because the only precomposed accented Cyrillic Unicode characters that
      # might cause problems are grave ѐЀѝЍ, which shouldn't normally occur
      # anyway; but it's definitely needed for Latin translit, because all
      # simple vowels have precomposed acute-accented variants.)
      newterm = rulib.decompose_acute_grave(newterm)
      real_pagename_decomposed = rulib.decompose_acute_grave(real_pagename)
      newterm = rulib.recompose(real_pagename_decomposed[0] + newterm[1:])
      if newtr:
        # Do the same decompose/recompose rigmarole as above, but it's more
        # necessary (because acute/grave over Latin latters is normally
        # composed), and trickier because of я ё ю -> ja jo ju.
        newtr = rulib.decompose_acute_grave(newtr)
        real_pagename_first_letter_translit = rulib.xlit_text(
            real_pagename_decomposed[0], pagemsg, semi_verbose)
        if not real_pagename_first_letter_translit:
          pagemsg("WARNING: Error from translit of %s" % real_pagename_decomposed[0])
          return term, termtr, None
        # A single Russian character might translit to 1 or 2 Latin chars,
        # so make sure to take chop off the same number of Latin chars from
        # the left side of the lowercased accented translit.
        newtr = rulib.recompose(real_pagename_first_letter_translit +
          newtr[len(real_pagename_first_letter_translit):])

    if semi_verbose:
      pagemsg("lookup_term_for_accents: Found head %s%s%s" % (newterm, "//%s" % newtr if newtr else "", cached_msg))

    # In some cases, the accented headword ends in a ? or ! that isn't
    # present in the page title. If the term we want to accent doesn't end
    # in ? or ! but the accented headword does, chop off the ? or !.
    if re.search("[!?]$", newterm) and not re.search("[!?]$", term):
      newterm_wo_punc = re.sub("[!?]$", "", newterm)
      if rulib.remove_accents(newterm_wo_punc) == rulib.remove_accents(term):
        pagemsg("lookup_term_for_accents: Removing punctuation from %s when matching against %s" % (
          newterm, term))
        newterm = newterm_wo_punc

    # Signal to return the passed-in term rather than the accented equivalent
    # we looked up. We do this, for example, if the term is already accented,
    # because the already-present accentuation might be correct and the
    # looked-up accentuation wrong. For example, a term might be in either
    # accent class a or b but the dictionary entry lists only class a (this
    # used to be the case, e.g., for блокпост). In such a case, if we're passed
    # in блокпосты́, we would look it up and wrongly conclude that the accented
    # form should be блокпо́сты. To guard against this, we don't change
    # already-accented words, but we still look them up to find the lemma so
    # we can bracket the term appropriately.
    keep_existing = False

    if rulib.remove_accents(newterm) != rulib.remove_accents(term):
      # Occasionally, the headword term differs from the page title in more
      # than just accents. This occurs most commonly in the manual-override
      # entries such as кому-л -> кому́-либо, so don't warn in that case, but
      # otherwise do so.
      if u"ё" in newterm and (rulib.remove_accents(newterm.replace(u"ё", u"е")) ==
          rulib.remove_accents(term)):
        # Allow mismatch in ё vs. е because we handle ru-*-alt-ё templates
        # in lookup_heads_and_inflections.
        pass
      elif cached != "manual-override":
        pagemsg("WARNING: lookup_term_for_accents: Accented term %s differs from %s in more than just accents%s" % (
          newterm, term, cached_msg))
      if "&#" in newterm:
        # We have a hack in terms like груз 200 to avoid the numbers being
        # interpreted as footnote symbols, where we replace the last 0 with
        # "&#48;". But we don't want this going into links/usexes/etc.
        keep_existing = True
    else:
      if AC in term or u"ё" in term:
        keep_existing = True
        pagemsg(u"lookup_term_for_accents: Term has accent or ё, not replacing accents: %s" % term)
      if rulib.is_monosyllabic(term):
        keep_existing = True
        pagemsg("lookup_term_for_accents: Term is monosyllabic, no need for accents: %s" % term)

    if keep_existing:
      newterm = term
      # The term might already be accented but fail to include an irregular
      # translit.
      if newtr and termtr and newtr != termtr:
        pagemsg("WARNING: Existing translit %s//%s and new translit %s//%s don't agree, not changing translit%s" % (
          term, termtr, newterm, newtr, cached_msg))
      newtr = termtr or newtr

    if need_none_lemma:
      # See comment above about this flag.
      return newterm, newtr, None

    if len(inflections_of) == 1 and not saw_lemma:
      # Not a lemma and inflection of one lemma
      _, lemma = list(inflections_of)[0]
      return newterm, newtr, lemma
    elif len(inflections_of) == 0 and saw_lemma:
      # A lemma and not a non-lemma form
      if pagename != real_pagename:
        # real_pagename is uppercase and pagename (the lemma we looked up)
        # is lowercase, hence not the same as the returned accented term,
        # and a two-part bracket like [[ты|Ты]] is necessary.
        return newterm, newtr, pagename
      else:
        return newterm, newtr, True

    # Else, either (a) both lemma and non-lemma, (b) non-lemma of multiple
    # lemmas, or (c) neither lemma nor non-lemma.
    if len(inflections_of) > 0 and saw_lemma:
      # (a) both lemma and non-lemma.
      pagemsg("WARNING: lookup_term_for_accents: Found lemma and inflections of one or more lemmas for %s%s: head(s) %s, lemma(s) of which this term is an inflection %s" % (
        pagename, cached_msg, stringize_heads(heads),
        stringize_inflections_of(inflections_of)))
      return newterm, newtr, None
    elif len(inflections_of) > 1:
      # (b) both lemma and non-lemma.
      pagemsg("WARNING: lookup_term_for_accents: Found inflections of multiple lemmas for %s%s: head(s) %s, lemmas of which this term is an inflection %s" % (
        pagename, cached_msg, stringize_heads(heads),
        stringize_inflections_of(inflections_of)))
    else:
      # (c) neither lemma nor non-lemma.
      pass
    return newterm, newtr, None

  # We couldn't find any existing pages with heads.
  return term, termtr, None

# After the words in TERM with translit TERMTR have been split into words
# WORDS and TRWORDS (which should be an empty list if TERMTR is empty), with
# alternating separators in the even-numbered words, find accents for each
# individual word and then rejoin the result.
def find_accented_split_words(term, termtr, words, trwords, verbose, pagetitle,
    pagemsg, template, add_brackets, expect_cap):
  newterm = term
  newtr = termtr
  # Check for unbalanced brackets.
  unbalanced = False
  substs = []
  for i in range(1, len(words), 2):
    word = words[i]
    if word.count("[") != word.count("]"):
      pagemsg("WARNING: find_accented_split_words: Unbalanced brackets in word #%s %s: %s" %
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
    for i in range(len(words)):
      word = words[i]
      trword = trwords[i] if trwords else ""
      # If it's a non-blank word (not a separator), look it up.
      if word and i % 2 == 1:
        if i >= 2 and blib.remove_links(words[i - 2]) in monosyllabic_accented_prepositions:
          # If it's a word and preceded by a stressed monosyllabic
          # preposition (e.g. до́ смерти), leave it alone.
          pagemsg("find_accented_split_words: Not accenting term %s%s preceded by accented preposition %s" %
              (word, "//" + trword if trword else "", words[i - 2]))
          ru = word
          tr = trword
          # FIXME! Bracket term as necessary.
        elif (i >= 2 and words[i - 1] in ["(", ")", "[", "]"] and
            re.search(ends_in_cyrillic_re, words[i - 2])):
          # If it's a word and followed by paren/bracket + Cyrillic (with no
          # spaces) or preceded likewise, don't auto-accent it because we're
          # likely dealing with a case like галер(ея) on page галёрка, which
          # should be accented as галере́я but in which case we would otherwise
          # accent гале́р and ея́ as words.
          pagemsg("find_accented_split_words: Not accenting partial-word term %s%s in %s%s%s" %
              (word, "//" + trword if trword else "", words[i - 2],
               words[i - 1], word))
          ru = word
          tr = trword
        elif (i <= len(words) - 3 and words[i + 1] in ["(", ")", "[", "]"] and
            re.search(begins_in_cyrillic_re, words[i + 2])):
          # See preceding case.
          pagemsg("find_accented_split_words: Not accenting partial-word term %s%s in %s%s%s" %
              (word, "//" + trword if trword else "", word, words[i + 1],
               words[i + 2]))
          ru = word
          tr = trword
        else:
          # Otherwise, actually look it up.
          ru, tr, this_substs = find_accented(word, trword, verbose, pagetitle,
            pagemsg, template, add_brackets,
            # We expect the first char to be capitalized if either
            # (1) We expect the first char of the entire word sequence to
            #     be capitalized and we're processing the first word, or
            # (2) Preceding the word is a sequence of non-word chars ending in
            #     a period/slash/exclamation point plus a space or two spaces
            #     or is > (the end of an HTML tag, possibly <br/> or <br>),
            #     and what precedes that isn't a single-capital-letter word
            #     (this extra condition is to handle e.g. "П. И. Чайковский",
            #     where the capitalized word is should not be looked up
            #     lowercase).
            expect_cap and i == 1 or (
              re.search(u"(> *|“|\"|[/.…!:—}]  ?)$", words[i - 1]) and
              not (i >= 2 and len(words[i - 2]) == 1 and words[i - 2].isupper())
            ))
        if "," in tr:
          pagemsg("find_accented_split_words: Comma in translit <%s>, replacing with slash" % tr)
          tr = re.sub(", *", "/", tr)
        newwords.append(ru)
        newtrwords.append(tr)
        # If we saw a manual translit word, note it (see above).
        if tr:
          if not trwords:
            if this_substs:
              for this_subst in this_substs:
                if this_subst not in substs:
                  substs.append(this_subst)
            else:
              bare_ru = blib.remove_links(ru)
              # Strip boldface from subst
              m = re.search(r"^'''(.*)'''$", bare_ru)
              if m:
                bare_ru = m.group(1)
              m = re.search(r"^'''(.*)'''$", tr)
              if m:
                tr = m.group(1)
              subst_ru = ru_reverse_translit.reverse_translit(tr,
                  cyrillic=bare_ru)
              if bare_ru != subst_ru:
                newsubst = "%s//%s" % (bare_ru, subst_ru)
                if newsubst not in substs:
                  substs.append(newsubst)
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
          pagemsg("WARNING: find_accented_split_words: Separator <%s> at index %s has manual translit <%s> that's different from it: %s" % (
            word, i, trword, str(template)))
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
          tr = rulib.xlit_text(ru, pagemsg, semi_verbose)
          if not tr:
            got_error = True
            pagemsg("WARNING: find_accented_split_words: Got error during transliteration")
            break
        newertrwords.append(tr)
      if not got_error:
        newterm = "".join(newwords)
        newtr = "".join(newertrwords)
    else:
      newterm = "".join(newwords)
      newtr = ""
  return newterm, newtr, substs

# Add either a bracketed link or boldface to a term, depending on whether
# the page it occurs on is the same as the term's lemma. The arguments are
# TERM and manual translit TR (a blank string if no manual translit is needed);
# the term's LEMMA (which is True if the term is itself a lemma, and None if
# no lemma can be identified, e.g. because the term is both a lemma and a
# non-lemma form of some other lemma, or because the term is a non-lemma form
# of multiple lemmas); and PAGETITLE, the unaccented title of the page on
# which the term occurs.
def bracket_term_with_lemma(term, tr, lemma, pagetitle):
  if rulib.remove_accents(term) == pagetitle or lemma == pagetitle:
    return "'''%s'''" % term, tr and "'''%s'''" % tr or ""
  if lemma is True:
    return "[[%s]]" % term, tr
  elif lemma:
    return "[[%s|%s]]" % (lemma, term), tr
  else:
    return term, tr

# Look up a term (and associated manual translit) and try to add accents.
# The basic algorithm is that we first look up the whole term and then
# split on words and recursively look up each word individually.
def find_accented_1(term, termtr, verbose, pagetitle, pagemsg, template,
    add_brackets, expect_cap):
  # (1) Handle plain [[FOO]] or [[FOO BAR]].
  m = re.search(r"^\[\[([^\[\]\|]*)\]\]$", term)
  if m:
    # We want to convert [[FOO]] to [[BAZ|FOO]] if necessary (i.e. it's
    # a non-lemma). Do this by requesting bracketing, but only of the
    # whole clause. Then we check if the returned term is bracketed, and
    # return it whole if so; otherwise, remove any surrounding boldface
    # and bracket.
    newterm, newtr, substs = find_accented(re.sub("#Russian$", "", m.group(1)),
      termtr, verbose, pagetitle, pagemsg, template, "outer", expect_cap)
    if re.search(r"^\[\[([^\[\]]*)\]\]$", newterm):
      # If term is already bracketed, just return it.
      if "|" in newterm:
        pagemsg("WARNING: find_accented_1: Already bracketed term %s referencing non-lemma, replacing with lemma reference %s" %
          (term, newterm))
      return newterm, newtr, substs
    m = re.search(r"^'''(.*)'''$", newterm)
    if m:
      # Also strip boldface from translit, if possible.
      if newtr:
        mm = re.search(r"^'''(.*)'''$", newtr)
        if not mm:
          pagemsg("WARNING: find_accented_1: Boldfaced term %s but not corresponding translit %s" % (
            newterm, newtr))
        else:
          newtr = mm.group(1)
      return "[[%s]]" % m.group(1), newtr, substs
    return "[[%s]]" % newterm, newtr, substs

  # (2) Handle [[FOO|BAR]] or [[FOO BAR|BAZ BAT]].
  m = re.search(r"^\[\[([^\[\]\|]*)\|([^\[\]\|]*)\]\]$", term)
  if m:
    newterm, newtr, substs = find_accented(m.group(2), termtr, verbose,
      pagetitle, pagemsg, template, False, expect_cap)
    newlemma = re.sub("#Russian$", "", m.group(1))
    if rulib.remove_accents(newterm) == newlemma:
      pagemsg("find_accented_1: Redundant vertical-bar bracket, simplifying: %s" % term)
      return "[[%s]]" % newterm, newtr, substs
    else:
      return "[[%s|%s]]" % (newlemma, newterm), newtr, substs

  # (3) Handle '''FOO''' or '''FOO BAR'''.
  m = re.search(r"^'''([^'\n]+)'''$", term)
  if m:
    # Also strip boldface from translit, if possible.
    if termtr:
      mm = re.search(r"^'''(.*)'''$", termtr)
      if not mm:
        pagemsg("WARNING: find_accented_1: Boldfaced term %s but not corresponding translit %s" % (
          term, termtr))
      else:
        termtr = mm.group(1)
    newterm, newtr, substs = find_accented(m.group(1), termtr, verbose,
      pagetitle, pagemsg, template, False, expect_cap)
    return "'''%s'''" % newterm, newtr and "'''%s'''" % newtr or "", substs

  # (4) Check for and ignore template as entire string (filter_templates()
  #     will recursively process the template).
  if re.search(r"^\{\{.*\}\}$", term):
    pagemsg("find_accented_1: Ignoring template call embedded in argument: %s" % term)
    return term, termtr, []

  # (5) Otherwise, look up the whole term.
  newterm, newtr, lemma = lookup_term_for_accents(term, termtr, verbose,
    pagemsg, expect_cap)
  substs = []

  # (5) If we couldn't match the whole term, split into individual words
  #     and try looking up each one.
  if newterm == term and newtr == termtr:
    # If the whole term is/has a lemma, don't add brackets to inner terms
    # because we will bracket the whole term. Also don't add brackets to
    # inner terms if explicitly requested to only bracket the entire term
    # (used when processing bare [[FOO]] or [[FOO BAR]], which we will
    # convert to [[BAZ|FOO]] or [[BAZ BAT|FOO BAR]] if necessary).
    inner_add_brackets = (
        False if lemma or add_brackets == "outer" else add_brackets)
    split_regex = ur"('''.*?'''|\[\[.*?\]\]|[^()\[\]{} \u00A0\n—,.…?!:;/\"«»„“”<>]+)"
    words = re.split(split_regex, term)
    trwords = (re.split(split_regex, termtr)
      if termtr else [])
    if trwords and len(words) != len(trwords):
      pagemsg("WARNING: find_accented_1: %s Cyrillic words but different number %s translit words: %s//%s" % (len(words), len(trwords), term, termtr))
    elif len(words) == 3 and not words[0] and not words[2]:
      # Just a single word.
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
          pagemsg("WARNING: find_accented_1: %s Cyrillic words but different number %s translit words: %s//%s" % (len(words), len(trwords), term, termtr))
          pass
        elif len(words) == 3 and not words[0] and not words[2]:
          # Only one word, and we already looked it up; don't duplicate work
          # or get stuck in infinite loop.
          pass
        else:
          newterm, newtr, substs = find_accented_split_words(term, termtr,
            words, trwords, verbose, pagetitle, pagemsg, template,
            inner_add_brackets, expect_cap)
    else:
      newterm, newtr, substs = find_accented_split_words(term, termtr, words,
        trwords, verbose, pagetitle, pagemsg, template, inner_add_brackets,
        expect_cap)

  if add_brackets:
    newterm, newtr = bracket_term_with_lemma(newterm, newtr, lemma, pagetitle)

  return newterm, newtr, substs

# Outer wrapper, equivalent to find_accented_1() except outputs extra
# log messages if --semi-verbose.
def find_accented(term, termtr, verbose, pagetitle, pagemsg, template,
    add_brackets, expect_cap):
  if semi_verbose:
    pagemsg("find_accented: Call with term %s%s" % (term, "//%s" % termtr if termtr else ""))
  term, termtr, substs = find_accented_1(term, termtr, verbose, pagetitle,
    pagemsg, template, add_brackets, expect_cap)
  if semi_verbose:
    pagemsg("find_accented: Return %s%s%s" % (
      term, "//%s" % termtr if termtr else "",
      ", subst=" + ",".join(substs) if substs else ""))
  return term, termtr, substs

# Group "auto-accent foo" msgs.
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
    notes = ["auto-accent %s" % "; ".join(accented_words)]
  else:
    notes = []
  notes.extend(other_notes)
  return "; ".join(notes)

# Apply a subst= param to Cyrillic text.
def apply_substs(ru, substs, pagemsg):
  substs = re.split(",", substs)
  for subst in substs:
    if "//" in subst:
      delim = "//"
    else:
      delim = "/"
    split_subst = re.split(delim, subst)
    if len(split_subst) != 2:
      pagemsg("WARNING: Bad subst %s" % subst)
    else:
      fro, to = split_subst
      # Our (feeble) attempt at mapping Lua regexes to Python ones.
      # Doesn't much matter because Lua regexes rarely occur in subst=
      # expressions.
      fro = re.sub("%(.)", r"\\\1", fro)
      to = re.sub("%(.)", r"\\\1", to)
      ru = re.sub(fro, to, ru)
  return ru

# Process a template, optionally adding accents/links/boldface (if
# FIND_ACCENTS is True) and replacing the appropriate param and translit
# param.
def process_template(pagetitle, index, pagetext, template, ruparam, trparam,
    output_line, find_accents, accent_hidden, verbose):
  origt = str(template)
  saveparam = ruparam
  def pagemsg(text):
    msg("Page %s %s: %s" % (index, pagetitle, text))
  if semi_verbose:
    pagemsg("process_template: Processing template: %s" % origt)
  if str(template.name) == "head":
    # Skip {{head}}. We don't want to mess with headwords.
    return False
  if not accent_hidden and re.search("^#\*:* *%s" % re.escape(origt),
      str(pagetext), re.M):
    if semi_verbose:
      pagemsg("process_template: Skipping template because hidden by #*: %s" % origt)
      return False
  if isinstance(ruparam, list):
    ruparam, saveparam = ruparam
  if ruparam == "page title":
    val = pagetitle
  else:
    val = getparam(template, ruparam)
  valtr = getparam(template, trparam) if trparam else ""
  if find_accents:
    newval, newtr, substs = find_accented(val, valtr, verbose, pagetitle,
      pagemsg, template, str(template.name) in link_expandable_templates,
      True)
    if newval != val or newtr != valtr:
      if ruheadlib.normalize_text(newval) != ruheadlib.normalize_text(val):
        pagemsg("WARNING: process_template: Accented page %s changed from %s in more than just accents/links/boldface" % (newval, val))
        # Formerly we refused to change anything but now we are normalizing
        # e.g. кого-л to кого́-либо
      addparam(template, saveparam, newval)
      if newtr:
        if not trparam:
          pagemsg("WARNING: process_template: Unable to change translit to %s because no translit param available (Cyrillic param %s): %s" %
              (newtr, saveparam, origt))
        elif str(template.name) in templates_with_subst and substs:
          subst_param = ",".join(substs)
          if valtr:
            if newtr == valtr:
              pagemsg("process_template: Replacing tr=%s with subst=%s with the same effect" % (
                valtr, subst_param))
            else:
              pagemsg("WARNING: process_template: Replacing non-equivalent translit param %s (not = new %s) with subst=%s: origt=%s" %
                  (valtr, newtr, subst_param, origt))
            rmparam(template, trparam)
            addparam(template, "subst", subst_param)
          else:
            cursubst_param = getparam(template, "subst")
            if cursubst_param:
              # We have both an existing subst= and a new one. First check if
              # the effect of applying the existing subst= is the same as the
              # effect of applying the new subst=. If so, do nothing; the
              # actual substs might be different so we don't want to try to
              # combine them.
              curtr = rulib.xlit_text(apply_substs(val, cursubst_param, pagemsg),
                pagemsg, semi_verbose)
              if curtr == newtr:
                pagemsg("NOTE: process_template: Not adding subst=%s because already existing subst=%s has same effect" % (
                  ",".join(substs), cursubst_param))
              else:
                # New subst= will actually do something; combine with existing
                # but try to filter out duplicates. This may not work
                # perfectly so issue a warning.
                cursubsts = re.split(",", cursubst_param)
                normalized_substs = [
                    cursubst if "//" in cursubst else
                    cursubst.replace("/", "//") for cursubst in cursubsts]
                for subst in substs:
                  if subst not in normalized_substs:
                    normalized_substs.append(subst)
                new_subst_param = ",".join(normalized_substs)
                pagemsg("WARNING: process_template: New tr %s not same as existing tr (from subst=) %s; combined existing subst=%s with new subst=%s to form subst=%s: origt=%s" % (
                  newtr, curtr, cursubst_param, ",".join(substs), new_subst_param, origt))
                addparam(template, "subst", new_subst_param)
            else:
              normalized_substs = substs
              new_subst_param = ",".join(normalized_substs)
              pagemsg("NOTE: process_template: Added subst=%s to origt=%s" % (
                new_subst_param, origt))
              addparam(template, "subst", new_subst_param)
        else:
          if valtr and valtr != newtr:
            pagemsg("WARNING: process_template: Changed translit param %s from %s to %s: origt=%s" %
                (trparam, valtr, newtr, origt))
          if not valtr:
            pagemsg("NOTE: process_template: Added translit param %s=%s to template: origt=%s" %
                (trparam, newtr, origt))
          addparam(template, trparam, newtr)
      elif valtr:
        pagemsg("WARNING: process_template: Template has translit %s but lookup result has none, leaving translit alone: origt=%s" %
            (valtr, origt))
      if check_need_accent(newval):
        output_line("Need accents (changed)")
      else:
        output_line("Found accents")
  changed = str(template) != origt
  if not changed and check_need_accent(val):
    output_line("Need accents")
  if changed:
    pagemsg("process_template: Replaced %s with %s" % (origt, str(template)))
  return ["auto-accent %s%s%s" % (newval, "//%s" % newtr if newtr else "",
    ", subst=" + ",".join(substs) if substs else "")] if changed else False

# Main function to implement the whole script.
def auto_accent_auto_bracket_russian(find_accents, accent_hidden, cattype, direcfile,
    save, verbose, startFrom, upTo):
  if direcfile:
    processing_lines = []
    for index, line in blib.iter_items_from_file(direcfile, startFrom, upTo):
      m = re.match(r"^(Page [^ ]+ )(.*?)(: .*?:) Processing: (\{\{.*?\}\})( <- \{\{.*?\}\} \(\{\{.*?\}\}\))$",
          line)
      if not m:
        msg("Line %s: WARNING: Unable to parse line: %s" % (index, line))
        continue
      pagenum, pagetitle, tempname, repltext, rest = m.groups()

      def pagemsg(text):
        msg("Page %s(%s) %s: %s" % (pagenum, index, pagetitle, text))
      def check_template_for_missing_accent(pagetitle, index, pagetext,
          template, templang, ruparam, trparam):
        def output_line(directive):
          msg("* %s[[%s]]%s %s: <nowiki>%s%s</nowiki>" % (pagenum, pagetitle,
              tempname, directive, str(template), rest))
        return process_template(pagetitle, index, pagetext, template, ruparam,
            trparam, output_line, find_accents, accent_hidden, verbose)

      blib.process_links(save, verbose, "ru", "Russian", "pagetext", None,
          None, check_template_for_missing_accent,
          join_actions=join_changelog_notes, split_templates=None,
          pages_to_do=[(pagetitle, repltext)], quiet=True)
      if index % 100 == 0:
        ruheadlib.output_stats(pagemsg)
  else:
    def check_template_for_missing_accent(pagetitle, index, pagetext, template,
        templang, ruparam, trparam):
      def pagemsg(text):
        msg("Page %s %s: %s" % (index, pagetitle, text))
      def output_line(directive):
        pagemsg("%s: %s" % (directive, str(template)))
      result = process_template(pagetitle, index, pagetext, template, ruparam,
          trparam, output_line, find_accents, accent_hidden, verbose)
      if index % 100 == 0:
        ruheadlib.output_stats(pagemsg)
      return result

    blib.process_links(save, verbose, "ru", "Russian", cattype, startFrom,
        upTo, check_template_for_missing_accent,
        join_actions=join_changelog_notes, split_templates=None)

pa = blib.create_argparser("Auto-accent and auto-bracket Russian terms")
pa.add_argument("--cattype", default="vocab",
    help="Categories to examine ('vocab', 'borrowed', 'translation')")
pa.add_argument("--file",
    help="File containing output from parse_log_file.py")
pa.add_argument("--semi-verbose", action="store_true",
    help="More info but not as much as --verbose")
pa.add_argument("--find-accents", action="store_true",
    help="Look up the accents in existing pages")
pa.add_argument("--accent-hidden", action="store_true",
    help="Also add accents and brackets to hidden qutoes")
pa.add_argument("--no-cache", action="store_true",
    help="Disable caching head lookup results")

params = pa.parse_args()
semi_verbose = params.semi_verbose or params.verbose
global_disable_cache = params.no_cache
startFrom, upTo = blib.parse_start_end(params.start, params.end)

auto_accent_auto_bracket_russian(params.find_accents, params.accent_hidden,
    params.cattype, params.file, params.save, params.verbose, startFrom, upTo)

blib.elapsed_time()

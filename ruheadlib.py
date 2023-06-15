#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, codecs

import blib, pywikibot
from blib import msg, getparam, addparam, site
import rulib

# List of Russian templates referring to lemmas.
ru_lemma_templates = ["ru-noun", "ru-proper noun", "ru-verb", "ru-verb-cform",
  "ru-adj", "ru-adv", "ru-phrase", "ru-proverb", "ru-diacritical mark"]
# List of Russian templates referring to heads of any sort.
ru_head_templates = ru_lemma_templates + ["ru-noun form", "ru-comparative"]
# List of parts of speech referring to Russian lemmas (for use with
# {{head|ru|...}}).
ru_lemma_poses = ["adjective", "adverb", "circumfix", "conjunction",
  "determiner", "idiom", "interfix", "interjection", "letter", "noun",
  "numeral", "cardinal number", "particle", "phrase", "predicative",
  "prefix", "preposition", "prepositional phrase", "pronoun", "proper noun",
  "proverb", "suffix", "verb"]
# Non-Russian-specified templates speciying inflections of a lemma.
inflection_templates = ["inflection of", "comparative of", "superlative of"]
# Alt-ё templates for specifying terms spelled with е in place of ё.
alt_yo_templates = [u"ru-noun-alt-ё", u"ru-verb-alt-ё", u"ru-adj-alt-ё",
  u"ru-proper noun-alt-ё", u"ru-pos-alt-ё"]

# Cache of information found during page lookup of a term, to avoid duplicative
# page lookups (which are expensive as the server only allows about 6 of them
# per second). Value is None if the page doesn't exist. Value is the string
# "redirect" if page is a redirect. Value is the string "no-russian" if page
# has only non-Russian sections. Otherwise, value is a tuple (HEADS,
# SAW_LEMMA, INFLECTIONS_OF, ADJ_FORMS); see lookup_heads_and_inflections().
#
# Every 100 pages we output stats on cache size, #lookups and hit rate; see
# output_stats(). The hit rate is around # 40% near the beginning but increases
# over time, reaching > 87% at the end.
accented_cache = {}
num_cache_lookups = 0
num_cache_hits = 0
global_disable_cache = False

semi_verbose = False # Set by --semi-verbose or --verbose

# Terms where we manually specify the corresponding lemma and accented form,
# ignoring certain infrequent alternative uses that rarely apply but would
# prevent link expansion. The key is the unaccented term, while the value
# is a two-element list [ACCENTED_FORM, LEMMA], where ACCENTED_FORM is the
# equivalent accented form that we replace the term with (this can also be
# used to expand abbreviations, like кто-л -> кто́-либо), and LEMMA is the
# unaccented lemma that this term belongs to, or True if the term is itself
# a lemma.
manually_specified_inflections = {
  # Also a particle meaning "nearly"
  u"было": [u"бы́ло", u"быть"],
  # Also genitive plural of ка́ка
  u"как": [u"как", True],
  # Also genitive plural of та́ка
  u"так": [u"так", True],
  # Also genitive plural of ту́та
  u"тут": [u"тут", True],
  # Also 2nd singular imperative of тереть
  u"три": [u"три", True],
  # Also 2nd singular imperative of пя́тить
  u"пять": [u"пять", True],
  # Also dated present adverbial participle of длить
  u"для": [u"для", True],
  # Also listed as inflection of быть
  u"нет": [u"нет", True],
  # Also an interjection
  u"это": [u"э́то", u"этот"],
  # Abbrevations of -либо
  u"кто-л": [u"кто́-либо", True],
  u"кого-л": [u"кого́-либо", u"кто-либо"],
  u"кому-л": [u"кому́-либо", u"кто-либо"],
  u"кем-л": [u"ке́м-либо", u"кто-либо"],
  u"ком-л": [u"ко́м-либо", u"кто-либо"],
  u"что-л": [u"что́-либо", True],
  u"чего-л": [u"чего́-либо", u"что-либо"],
  u"чему-л": [u"чему́-либо", u"что-либо"],
  u"чем-л": [u"че́м-либо", u"что-либо"],
  u"чём-л": [u"чём-либо", u"что-либо"],
  u"чей-л": [u"че́й-либо", True],
  u"чьё-л": [u"чьё-либо", u"чеи-либо"],
  u"чья-л": [u"чья́-либо", u"чеи-либо"],
  u"чьи-л": [u"чьи́-либо", u"чеи-либо"],
  u"чьего-л": [u"чьего́-либо", u"чеи-либо"],
  u"чьей-л": [u"чье́й-либо", u"чеи-либо"],
  u"чьих-л": [u"чьи́х-либо", u"чеи-либо"],
  u"чьему-л": [u"чьему́-либо", u"чеи-либо"],
  u"чьим-л": [u"чьи́м-либо", u"чеи-либо"],
  u"чью-л": [u"чью́-либо", u"чеи-либо"],
  u"чьею-л": [u"чье́ю-либо", u"чеи-либо"],
  u"чьими-л": [u"чьи́ми-либо", u"чеи-либо"],
  u"чьём-л": [u"чьём-либо", u"чеи-либо"],
  u"куда-л": [u"куда́-либо", True],
  u"какой-л": [u"како́й-либо", True],
  u"какое-л": [u"како́е-либо", u"какой-либо"],
  u"какая-л": [u"кака́я-либо", u"какой-либо"],
  u"какие-л": [u"каки́е-либо", u"какой-либо"],
  u"какого-л": [u"како́го-либо", u"какой-либо"],
  u"каких-л": [u"каки́х-либо", u"какой-либо"],
  u"какому-л": [u"како́му-либо", u"какой-либо"],
  u"каким-л": [u"каки́м-либо", u"какой-либо"],
  u"какую-л": [u"каку́ю-либо", u"какой-либо"],
  u"какою-л": [u"како́ю-либо", u"какой-либо"],
  u"какими-л": [u"каки́ми-либо", u"какой-либо"],
  u"каком-л": [u"како́м-либо", u"какой-либо"],
}

terms_to_ignore = {
  u"бела", # On page белый, we have old short genitive бе́ла; if we don't ignore
           # the page, we get a translit from the term бел
  u"белу", # On page свет, we have old short dative бе́лу; if we don't ignore
           # the page, we get a translit from the term бел
  u"и.о.", # Otherwise we get и.о́.
}

# Given Cyrillic and translit, remove any accents if the text consists of a
# single monosyllabic word. We don't remove accents where there are multiple
# words, because of cases like ни́ за што and до́ смерти where the accent is
# important.
def remove_monosyllabic_accents(ru, tr):
  return rulib.remove_monosyllabic_accents(ru), rulib.remove_tr_monosyllabic_accents(tr)

# Normalize a piece of text by removing accents, links and boldface.
def normalize_text(text):
  return rulib.remove_accents(blib.remove_links(text)).replace("'''", "")

# Split a form with optional translit appended (which may be either a bare
# Cyrillic term or something of the form CYRILLIC//TR), returning the
# Cyrillic and translit (which will be a blank string if not specified or if
# redundant).
def split_ru_tr(form, pagemsg):
  if "//" in form:
    rutr = re.split("//", form)
    assert len(rutr) == 2
    ru, tr = rutr
    # Check to see if manual translit is same as auto-translit; if so,
    # don't specify manual translit. This is important especially in the
    # output of {{ru-generate-adj-forms}}, which includes entries likes
    # gen_m=а́йнского//ájnskovo even though the normal auto-translit of
    # а́йнского is ájnskovo.
    autotr = rulib.xlit_text(ru, pagemsg, semi_verbose)
    if tr == autotr:
      return (ru, "")
    else:
      return (ru, tr)
  else:
    return (form, "")

# Output stats on cache size, #lookups and hit rate. (The hit rate is around
# 40% near the beginning but increases over time, reaching > 87% at the end.)
def output_stats(pagemsg):
  if global_disable_cache:
    return
  pagemsg("Cache size = %s" % len(accented_cache))
  pagemsg("Cache lookups = %s, hits = %s, %0.2f%% hit rate" % (
    num_cache_lookups, num_cache_hits,
    float(num_cache_hits)*100/num_cache_lookups if num_cache_lookups else 0.0))

# Fetch cached information on a page, or fetch it from the page and cache it.
# In either case, return the page information. Return value is a tuple
# (CACHED, INFO), where CACHED is either False (we looked up the value on the
# page), True (it was already cached), or "manual-override" (the value comes
# from manually_specified_inflections), and INFO is either None (page doesn't
# exist), "redirect" (page is a redirect), "no-russian" (page isn't a redirect
# but has no Russian section) or a tuple as follows:
#   (HEADS, INFLECTIONS_OF, ADJ_FORMS)
#
# (1) HEADS is a set of all heads found on the page, each of which is
#     (RU, TR, IS_LEMMA).
# (2) INFLECTIONS_OF is a set of (HEADS, LEMMA) for each lemma of which this
#     entry is an inflection, listing the heads in the same subsection as the
#     {{inflection of|...}} call. HEADS is a set exactly like (1) above.
# (3) ADJ_FORMS is a set of all adjective forms of any adjective lemmas found
#     on the page (each of which is (RU, TR)).
def lookup_heads_and_inflections(pagename, pagemsg):
  if semi_verbose:
    pagemsg("lookup_heads_and_inflections: Finding heads on page %s" % pagename)

  # Use our own expand_text() rather than passing it from the caller,
  # which may have a different value for PAGENAME; the proper value is
  # important in expanding certain templates e.g. ru-generate-adj-forms.
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagename, pagemsg, semi_verbose)

  if pagename in terms_to_ignore:
    pagemsg("lookup_heads_and_inflections: Ignoring term because in terms_to_ignore: %s" % pagename)
    return "manual-override", None

  if pagename in manually_specified_inflections:
    accented, lemma = manually_specified_inflections[pagename]
    if lemma is True:
      return "manual-override", ({(accented, "", True)}, set(), set())
    else:
      return "manual-override", ({(accented, "", False)},
          {(frozenset({(accented, "", False)}), lemma)}, set())

  global num_cache_lookups
  num_cache_lookups += 1
  if pagename in accented_cache:
    global num_cache_hits
    num_cache_hits += 1
    result = accented_cache[pagename]
    if result is None:
      if semi_verbose:
        pagemsg("lookup_heads_and_inflections: Page %s doesn't exist (cached)" % pagename)
    elif result == "redirect":
      if semi_verbose:
        pagemsg("lookup_heads_and_inflections: Page %s is redirect (cached)" % pagename)
    elif result == "no-russian":
      if semi_verbose:
        pagemsg("lookup_heads_and_inflections: Page %s has no Russian section (cached)" % pagename)
    return True, result
  elif "\n" in pagename:
      pagemsg("WARNING: lookup_heads_and_inflections: Bad pagename (has newline in it): %s" % pagename)
      if not global_disable_cache:
        accented_cache[pagename] = None
      return False, None
  else:
    cached = False
    page = pywikibot.Page(site, pagename)
    try:
      if not page.exists():
        if semi_verbose:
          pagemsg("lookup_heads_and_inflections: Page %s doesn't exist" % pagename)
        if not global_disable_cache:
          accented_cache[pagename] = None
        return False, None
    except Exception as e:
      pagemsg("WARNING: lookup_heads_and_inflections: Error checking page existence: %s" % unicode(e))
      if not global_disable_cache:
        accented_cache[pagename] = None
      return False, None

    # Page exists, is it a redirect?
    if re.match("#redirect", page.text, re.I):
      if not global_disable_cache:
        accented_cache[pagename] = "redirect"
      pagemsg("lookup_heads_and_inflections: Page %s is redirect" % pagename)
      return False, "redirect"

    # Page exists and is not a redirect, find the info
    heads = set()
    inflections_of = set()
    adj_forms = set()

    foundrussian = False
    sections = re.split("(^==[^=]*==\n)", unicode(page.text), 0, re.M)

    for j in range(2, len(sections), 2):
      if sections[j-1] == "==Russian==\n":
        if foundrussian:
          pagemsg("WARNING: lookup_heads_and_inflections: Found multiple Russian sections")
          break
        foundrussian = True

        subsections = re.split("(^===+[^=\n]+===+\n)", sections[j], 0, re.M)
        for k in range(2, len(subsections), 2):
          parsed = blib.parse_text(subsections[k])
          this_heads = set()
          def add(val, tr, is_lemma):
            val_to_add = blib.remove_links(val)
            # Remove monosyllabic accents to correctly handle the case of
            # рад, which has some heads with an accent and some without.
            val_to_add, tr = remove_monosyllabic_accents(val_to_add, tr)
            this_heads.add((val_to_add, tr, is_lemma))
          for t in parsed.filter_templates():
            tname = unicode(t.name)
            check_addl_heads = False
            if tname in ru_head_templates:
              is_lemma = tname in ru_lemma_templates
              check_addl_heads = True
              if getparam(t, "1"):
                add(getparam(t, "1"), getparam(t, "tr"), is_lemma)
              elif getparam(t, "head"):
                add(getparam(t, "head"), getparam(t, "tr"), is_lemma)
              else:
                add(pagename, "", is_lemma)
            elif tname == "head" and getparam(t, "1") == "ru":
              is_lemma = getparam(t, "2") in ru_lemma_poses
              check_addl_heads = True
              if getparam(t, "head"):
                add(getparam(t, "head"), getparam(t, "tr"), is_lemma)
              else:
                add(pagename, "", is_lemma)
            elif tname in ["ru-noun+", "ru-proper noun+"]:
              is_lemma = True
              lemma = rulib.fetch_noun_lemma(t, expand_text)
              lemmas = re.split(",", lemma)
              lemmas = [split_ru_tr(lemma, pagemsg) for lemma in lemmas]
              # Group lemmas by Russian, to group multiple translits
              lemmas = rulib.group_translits(lemmas, pagemsg, semi_verbose)
              for val, tr in lemmas:
                add(val, tr, is_lemma)
            elif (tname == "ru-participle of" or
                tname in inflection_templates and getparam(t, "lang") == "ru"):
              inflections_of.add((frozenset(this_heads),
                normalize_text(getparam(t, "1"))))
            if check_addl_heads:
              for i in range(2, 10):
                headn = getparam(t, "head" + str(i))
                if headn:
                  add(headn, getparam(t, "tr" + str(i)), is_lemma)
            elif tname == "ru-decl-adj":
              result = expand_text(re.sub(r"^\{\{ru-decl-adj", "{{ru-generate-adj-forms", unicode(t)))
              if not result:
                pagemsg("WARNING: lookup_heads_and_inflections: Error expanding template %s, page %s" %
                  (unicode(t), pagename))
              else:
                args = blib.split_generate_args(result)
                for value in args.itervalues():
                  adj_forms.add(value)
          heads.update(this_heads)

    # Page exists, is it a redirect?
    if not foundrussian:
      if not global_disable_cache:
        accented_cache[pagename] = "no-russian"
      pagemsg("lookup_heads_and_inflections: Page %s has no Russian section" % pagename)
      return False, "no-russian"

    saw_lemma = any(is_lemma for ru, tr, is_lemma in heads)
    if not saw_lemma and not inflections_of:
      # If no lemmas or inflections found, check for alt-ё templates.
      # If the term is a non-ё variant of a single term with ё, look up
      # and return the heads and inflections on that page.
      parsed = blib.parse_text(unicode(page.text))
      yo_pages = set()
      for t in parsed.filter_templates():
        if unicode(t.name) in alt_yo_templates:
          yo_pages.add(getparam(t, "1"))
      if len(yo_pages) > 1:
        pagemsg(u"WARNING: lookup_heads_and_inflections: Found multiple alt-ё templates for different lemmas: %s" %
          ",".join(yo_pages))
      elif len(yo_pages) == 0:
        pagemsg("WARNING: lookup_heads_and_inflections: Found no lemmas or inflections of lemmas for %s" % pagename)
      else:
        yoful_page = list(yo_pages)[0]
        pagemsg("lookup_heads_and_inflections: Redirecting from %s to %s" %
          (pagename, yoful_page))
        return lookup_heads_and_inflections(yoful_page, pagemsg)

    cacheval = (heads, inflections_of, adj_forms)
    if not global_disable_cache:
      accented_cache[pagename] = cacheval
    return False, cacheval

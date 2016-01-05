#!/usr/bin/env python
#coding: utf-8

#    create_ru_inflections.py is free software: you can redistribute it and/or modify
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

# FIXME:
#
# 1. (NOT DONE, INSTEAD HANDLED IN ADDPRON,PY) Add pronunciation. For nouns
#    and verbs with unstressed -я in the ending (3rd plural verb, dat/ins/pre
#    plural noun), we need to add a dot-under. Otherwise we use the form
#    itself. With multiple etymologies, we need to do more. If there's a
#    combined pronunciation, we need to check if all the forms under all the
#    etymologies are the same. If so, do nothing, else, we need to delete the
#    combined pronunciation and add pronunciations individually to each
#    section. If there are already split pronunciations, we just add a
#    pronunciation to the individual section. It might make sense to do this
#    in addpron.py.
# 2. (DONE) Currently we check to see if the manual translit matches and
#    if not we don't see the inflection as already present. Probably instead
#    we should issue a warning when this happens.
# 2a. (DONE) We need to check if there are multiple forms with the
#    same Cyrillic but different translit, and combine the manual translits.
# 3. When grouping participles with nouns/adjectives, don't do it if
#    participle is adverbial.
# 4. Need more special-casing of participles, e.g. head is 'participle',
#    name of POS is "Participle", defn uses 'ru-participle of'.
# 5. (DONE) Need to group short adjectives with adverbs (cf. агресси́вно
#    "aggressively" and also "aggressive (short n s)"). When doing this,
#    may need to take into account manual translit (адеква́тно with
#    tr=adɛkvátno, both an adverb and short adjective).
# 6. (NOT DONE, INSTEAD HANDLED IN ADDPRON.PY) When wrapping a single-etymology
#    entry to create multiple etymologies, consider moving the pronunciation
#    to the top above the etymologies.
# 7. (DONE) When a given form value has multiple forms and they are the same
#    except for accents, we should combine them into a single entry with
#    multiple heads, cf. бе́дный with short plural бедны́,бе́дны. Cf. also
#    глубо́кий with short neuter singular глубоко́,глубо́ко, an existing entry
#    with both forms already there (and in addition an adverb глубоко́, put
#    into its own etymology section). Verify that we correctly note the
#    already-existing entry and do nothing. This means we may need to
#    deal with the heads being out of order. (We can use template_head_matches()
#    separately on each head to match, which will also allow us to handle
#    the case where for some reason there are three existing heads and we
#    want to match two; and will allow us to issue a warning when we want to
#    match two heads and can only match one. Example where such a warning
#    should be issued: красно.)
# 8. (DONE) When comparing params, we should allow the param to have a
#    missing accent relative to the expected value (cf.
#    {{inflection of|lang=ru|апатичный|...}} vs. expected value апати́чный).
# 9. (DONE) When comparing params, if we're checking the value of head= or
#    1= and it's missing, we should substitute the pagetitle (e.g. expected
#    short form бе́л, actual template {{head|ru|adjective form}}, similarly
#    with бла́г, which also has a noun form entry).
# 10. (DONE) When creating a POS form (as we usually are), check for a POS
#    entry with the same head and issue a warning if so (e.g. short adj
#    neuter sg бесконе́чно, with an ru-adj entry already present).
# 11. (DONE) Need to group short adjectives with predicatives
#    (head|ru|predicative).
# 12. (DONE) Need to group adjectives with participle forms
#    (head|ru|participle form), cf. используемы.
# 13. (DONE) Handle redirects, e.g. чёрен redirect to чёрный.
# 14. (DONE) Only process inflection templates under the right part of speech,
#    to avoid the issue with преданный, which has one adjectival inflection
#    as an adjective and a different one as a participle.
# 15. (DONE) Also combine dictionary forms with the same Russian but different
#    translit, so скучный works correctly.
# 16. (DONE) When doing future, skip periphrastic future.
# 17. (DONE) Always skip inflections that would go on the lemma page to handle
#     e.g. accusative inanimate masculine and plural, and accusative neuter.
# 18. (DONE) One-syllable noun forms end up accented, but the existing forms
#     might be unaccented. We probably want to (a) de-accent monosyllabic forms,
#     (b) when comparing forms in compare_param(), allow accented monosyllabic
#     to compare to unaccented monosyllabic. This may be important for
#     adjectives and verbs as well.
# 19. (DONE) Warn if existing head or inflection has multiple accents (взя́ло́).
# 20. (DONE) Remove blank params from existing form codes when comparing.
# 21. (DONE) Add support for genders.
# 22. (DONE) Compute and output total time.
# 23. (DONE) Add ability to specify lemmas to process (for short adjs, lemmas
#     will be missing accents and will have е in place of ё).
# 24. (DONE) It might be problematic to update the gender to have -p in it
#     because some of the existing definitions might be singular, particularly
#     in nouns where genitive singular and nominative plural are often the same.
#     This suggests that we should remove -p from the gender (alternatively
#     we'd have to parse all the definitions to see if any are singular).
#     Similar issues exist in adjectives (e.g. -ым dat pl and m/n ins sg);
#     gender issues also exist in adjectives, since e.g. many forms are
#     shared between masculine and neuter. This suggests we shouldn't specify
#     gender at all for adjectives except maybe short forms. (NOTE: Per
#     Anatoli's request we don't include gender for short adjectives either.)
# 25. (DONE) In compare_param(), allow for links in the param, which e.g. may
#     be [[выходить#Etymology 1|выходи́ть]].
# 26. (DONE) Anatoli wants adjective forms to not show gender in the headword,
#     and verb forms to have "gender" (actually aspect) shown in the definition
#     line instead of the headword.
# 27. (DONE) Remove gender from verb headwords.
# 28. (DONE) Don't include head=/1= if same as pagename.

import pywikibot, re, sys, codecs, argparse, time
import traceback

import blib
from blib import getparam, rmparam, msg, site
from collections import OrderedDict

import rulib as ru

verbose = True

# Make sure there are two trailing newlines
def ensure_two_trailing_nl(text):
  return re.sub(r"\n*$", r"\n\n", text)

# Given an ru-noun+ or ru-proper noun+ template, fetch the lemma, which
# is of the form of one or more terms separted by commas, where each
# term is either a Cyrillic word or words, or a combination CYRILLIC/LATIN
# with manual transliteration. May return None if an error occurred
# in template expansion.
def fetch_noun_lemma(t, expand_text):
  if unicode(t.name) == "ru-noun+":
    generate_template = re.sub(r"^\{\{ru-noun\+",
        "{{ru-generate-noun-forms", unicode(t))
  else:
    generate_template = re.sub(r"^\{\{ru-proper noun\+",
        "{{ru-generate-noun-forms|ndef=sg", unicode(t))
  generate_result = expand_text(generate_template)
  if not generate_result:
    return None
  args = ru.split_generate_args(generate_result)
  return args["nom_sg"] if "nom_sg" in args else args["nom_pl"]

# Return True if LEMMA (the output of fetch_noun_lemma()) matches the
# specified Cyrillic term RU, with possible manual transliteration TR
# (may be empty). Issue a warning if Cyrillic matches but not translit.
# FIXME: If either the lemma specifies manual translit or TR is given,
# we should consider transliterating the other one in case of redundant
# manual translit.
def lemma_matches(lemma, ru, tr, pagemsg):
  for lem in re.split(",", lemma):
    if "//" in lem:
      lemru, lemtr = re.split("//", lem, 1)
    else:
      lemru, lemtr = lem, ""
    if ru == lemru:
      trmatches = not tr and not lemtr or tr == lemtr
      if not trmatches:
        pagemsg("WARNING: Value %s matches lemma %s of ru-(proper )noun+, but translit %s doesn't match %s" % (
          ru, lemru, tr, lemtr))
      else:
        return True
  return False

# Create or insert a section describing a given inflection of a given lemma.
# INFLECTIONS is the list of tuples of (INFL, INFLTR), i.e. accented
# inflectional form (e.g. the plural, feminine, verbal noun, participle,
# etc.) and associated manual transliteration (or None); LEMMA is the
# accented lemma (e.g. the singular, masculine or dictionary form of a
# verb); and LEMMATR is the associated manual transliterations (if any).
# POS is the part of speech of the word (capitalized, e.g. "Noun"). Only
# save the changed page if SAVE is true. INDEX is the numeric index of
# the lemma page, for ID purposes and to aid restarting. INFLTYPE is e.g.
# "adj form nom_m", and is used in messages; both POS and INFLTYPE are
# used in special-case code that is appropriate to only certain inflectional
# types. LEMMATYPE is e.g. "infinitive" or "masculine singular" and is
# used in messages.
#
# INFLTEMP is the headword template for the inflected-word entry (e.g.
# "head|ru|verb form" or "ru-noun form"; we special-case "head|" headword
# templates). INFLTEMP_PARAM is a parameter or parameters to add to the
# created INFLTEMP template, and should be either empty or of the form
# "|foo=bar" (or e.g. "|foo=bar|baz=bat" for more than one parameter).
#
# DEFTEMP is the definitional template that points to the base form (e.g.
# "inflection of" or "past passive participle of"). DEFTEMP_PARAM is a
# parameter or parameters to add to the created DEFTEMP template, similar
# to INFLTEMP_PARAM; or (if DEFTEMP is "inflection of") it should be a list
# of inflection codes (e.g. ['2', 's', 'pres', 'ind']). DEFTEMP_NEEDS_LANG
# indicates whether the definition template specified by DEFTEMP needs to
# have a 'lang' parameter with value 'ru'.
#
# GENDER should be a list of genders to use in adding or updating gender
# (assumed to be parameter g= in INFLTEMP if it's a "head|" headword template,
# else parameter 2=, and g2=, g3= for additional genders). If no genders
# are relevant, supply an empty list. (NOTE: This is special-cased for verbs,
# and inserts the "gender" [actually the aspect, perfective/imperfective]
# into the definition line.)
#
# If ENTRYTEXT is given, this is the text to use for the entry, starting
# directly after the "==Etymology==" line, which is assumed to be necessary.
# If not given, this text is synthesized from the other parameters.
#
# IS_LEMMA_TEMPLATE is a function that is passed one argument, a template,
# and should indicate if it's a lemma template (e.g. 'ru-adj' for adjectives).
# This is used to issue warnings in case of non-lemma forms where there's
# a corresponding lemma (NOTE, this situation could be legitimate for nouns).
def create_inflection_entry(save, index, inflections, lemma, lemmatr,
    pos, infltype, lemmatype, infltemp, infltemp_param, deftemp,
    deftemp_param, gender, deftemp_needs_lang=True, entrytext=None,
    is_lemma_template=None):

  # Did we insert an entry or find an existing one? If not, we need to
  # add a new one. If we break out of the loop through subsections of the
  # Russian section, we also don't need an entry; but we have this flag
  # because in some cases we need to continue checking subsections after
  # we've inserted an entry, to delete duplicate ones.
  need_new_entry = True

  # Remove any links that may esp. appear in the lemma, since the
  # accented version of the lemma as it appears in the lemma's headword
  # template often has links in it when the form is multiword.
  lemma = blib.remove_links(lemma)
  inflections = [(blib.remove_links(infl), infltr) for infl, infltr in inflections]

  joined_infls = ",".join(infl for infl, infltr in inflections)
  joined_infls_with_tr = ",".join("%s (%s)" % (infl, infltr) if infltr else "%s" % infl for infl, infltr in inflections)

  # Fetch pagename, create pagemsg() fn to output msg with page name included
  pagenames = set(ru.remove_accents(infl) for infl, infltr in inflections)
  # If multiple inflections, they should have the same pagename minus accents
  assert len(pagenames) == 1
  pagename = list(pagenames)[0]

  def pagemsg(text, simple=False):
    if simple:
      msg("Page %s %s: %s" % (index, pagename, text))
    else:
      msg("Page %s %s: %s: %s %s, %s %s%s" % (index, pagename, text, infltype,
        joined_infls_with_tr, lemmatype, lemma, " (%s)" % lemmatr if lemmatr else ""))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagename, pagemsg, verbose)

  is_participle = "participle" in infltype
  is_adj_form = "adjective form" in infltype
  is_noun_form = "noun form" in infltype
  is_verb_form = "verb form" in infltype
  is_short_adj_form = "adjective form short" in infltype
  is_noun_or_adj = "noun" in infltype or "adjective" in infltype
  is_noun_adj_plural = is_noun_or_adj and ("_p" in infltype or "_mp" in infltype)
  generic_infltype = (re.sub(" form.*", " form", infltype) if " form" in infltype
      else "participle" if is_participle else infltype)

  deftemp_uses_inflection_of = deftemp == "inflection of"
  infltemp_is_head = infltemp.startswith("head|")
  first_gender_param = "g" if infltemp_is_head else "2"

  for infl, infltr in inflections:
    if infl == "-":
      pagemsg("Not creating %s entry - for %s %s%s" % (
        infltype, lemmatype, lemma, " (%s)" % lemmatr if lemmatr else ""))
      return

  # Prepare to create page
  pagemsg("Creating entry")
  page = pywikibot.Page(site, pagename)

  # Check whether parameter PARAM of template T matches VALUE.
  def compare_param(t, param, value, valuetr):
    value = ru.remove_monosyllabic_accents(value)
    paramval = ru.remove_monosyllabic_accents(blib.remove_links(getparam(t, param)))
    if ru.is_multi_stressed(paramval):
      pagemsg("WARNING: Param %s=%s has multiple accents: %s" % (
        param, paramval, unicode(t)))
    if ru.is_multi_stressed(value):
      pagemsg("WARNING: Value %s to compare to param %s=%s has multiple accents" % (
        value, param, paramval))
    # If checking the first param, substitute page name if missing.
    if not paramval and param in ["1", "head"]:
      paramval = pagename
    # Allow cases where the parameter says e.g. апатичный (missing an accent)
    # and the value compared to is e.g. апати́чный (with an accent).
    if ru.is_unaccented(paramval) and ru.remove_accents(value) == paramval:
      matches = True
    # Allow cases that differ only in grave accents (typically if one of the
    # values has a grave accent and the other doesn't).
    elif re.sub(ru.GR, "", paramval) == re.sub(ru.GR, "", value):
      matches = True
    else:
      matches = paramval == value
    # Now, if there's a match, check the translit
    if matches:
      if param in ["1", "head"]:
        trparam = "tr"
      elif param.startswith("head"):
        trparam = re.sub("^head", "tr", param)
      else:
        assert not valuetr, "Translit cannot be specified with a non-head parameter"
        return True
      trparamval = getparam(t, trparam)
      if not valuetr and not trparamval:
        return True
      if valuetr == trparamval:
        return True
      pagemsg("WARNING: Value %s matches param %s=%s, but translit %s doesn't match param %s=%s: %s" % (
        value, param, paramval, valuetr, trparam, trparamval, unicode(t)))
      return False
    return False

  # True if any head in the template matches FORM with translit FORMTR.
  # Knows how to deal with ru-noun+ and ru-proper noun+.
  def template_head_matches_one_form(t, form, formtr):
    if unicode(t.name) in ["ru-noun+", "ru-proper noun+"]:
      lemma = fetch_noun_lemma(t, expand_text)
      if lemma is None:
        pagemsg("WARNING: Error generating noun forms")
        return False
      else:
        return lemma_matches(lemma, form, formtr, pagemsg)
    # Look at all heads
    firstparam = "head" if unicode(t.name) == "head" else "1"
    if compare_param(t, firstparam, form, formtr):
      return True
    i = 2
    while True:
      param = "head" + str(i)
      if not getparam(t, param):
        return False
      if compare_param(t, param, form, formtr):
        return True
      i += 1

  # True if the heads in the template match all the inflections in INFLECTIONS,
  # a list of (FORM, FORMTR) tuples. Warn if some but not all match.
  # Knows how to deal with ru-noun+ and ru-proper noun+.
  def template_head_matches(t, inflections):
    some_match = False
    all_match = True
    for infl, infltr in inflections:
      if template_head_matches_one_form(t, infl, infltr):
        some_match = True
      else:
        all_match = False
    if some_match and not all_match:
      pagemsg("WARNING: Some but not all inflections %s match template: %s" %
          (joined_infls_with_tr, unicode(t)))
    return all_match

  # Prepare parts of new entry to insert
  if entrytext:
    entrytextl4 = re.sub("^==(.*?)==$", r"===\1===", entrytext, 0, re.M)
    newsection = "==Russian==\n\n===Etymology===\n" + entrytext
  else:
    # Synthesize new entry. Some of the parts here besides 'entrytext',
    # 'entrytextl4' and 'newsection' are used down below when creating
    # verb parts and participles; these parts don't exist when 'entrytext'
    # was passed in, but that isn't a problem because it isn't passed in
    # when creating verb parts or participles.

    # 1. Get the head=/1= and head2=,head3= etc. headword params.
    headparams = []
    headno = 0
    if len(inflections) == 1 and inflections[0][0] == pagename and not inflections[0][1]:
      # Don't add head=/1= params if there's only one inflection that's the
      # same as the pagename and there's no translit.
      pass
    else:
      for infl, infltr in inflections:
        headno += 1
        if headno == 1:
          headparams.append("|%s%s%s" % ("head=" if infltemp_is_head else "",
            infl, "|tr=%s" % infltr if infltr else ""))
        else:
          headparams.append("|head%s=%s%s" % (headno, infl,
            "|tr=%s" % infltr if infltr else ""))

    # 2. Get the g=/2= and g2=,g3= etc. headword params.
    genderparams = []
    genderno = 0
    for g in gender:
      genderno += 1
      if genderno == 1:
        genderparams.append("|g=%s" % g if infltemp_is_head else "|%s" % g)
      else:
        genderparams.append("|g%s=%s" % (genderno, g))

    # 3. Synthesize headword template.
    new_headword_template = "{{%s%s%s%s}}" % (infltemp, "".join(headparams),
        "".join(genderparams), infltemp_param)

    # 4. Synthesize definition template.
    new_defn_template = "{{%s%s|%s%s%s}}" % (
      deftemp, "|lang=ru" if deftemp_needs_lang else "",
      lemma, "|tr=%s" % lemmatr if lemmatr else "",
      deftemp_param if isinstance(deftemp_param, basestring) else "||" + "|".join(deftemp_param))

    # 5. Synthesize part of speech body and section text as a whole.
    newposbody = """%s

# %s
""" % (new_headword_template, new_defn_template)
    newpos = "===%s===\n" % pos + newposbody
    newposl4 = "====%s====\n" % pos + newposbody
    entrytext = "\n" + newpos
    entrytextl4 = "\n" + newposl4
    newsection = "==Russian==\n" + entrytext

  comment = None
  notes = []

  try:
    existing_text = page.text
  except pywikibot.exceptions.InvalidTitle as e:
    pagemsg("WARNING: Invalid title, skipping")
    traceback.print_exc(file=sys.stdout)
    return

  if not page.exists():
    # Page doesn't exist. Create it.
    pagemsg("Creating page")
    comment = "Create page for Russian %s %s of %s, pos=%s" % (
        infltype, joined_infls, lemma, pos)
    page.text = newsection
    if verbose:
      pagemsg("New text is [[%s]]" % page.text)
  else: # Page does exist
    # Split off interwiki links at end
    m = re.match(r"^(.*?\n)(\n*(\[\[[a-z0-9_\-]+:[^\]]+\]\]\n*)*)$",
        page.text, re.S)
    if m:
      pagebody = m.group(1)
      pagetail = m.group(2)
    else:
      pagebody = page.text
      pagetail = ""

    # Split into sections
    splitsections = re.split("(^==[^=\n]+==\n)", pagebody, 0, re.M)
    # Extract off pagehead and recombine section headers with following text
    pagehead = splitsections[0]
    sections = []
    for i in xrange(1, len(splitsections)):
      if (i % 2) == 1:
        sections.append("")
      sections[-1] += splitsections[i]

    # Go through each section in turn, looking for existing Russian section
    for i in xrange(len(sections)):
      m = re.match("^==([^=\n]+)==$", sections[i], re.M)
      if not m:
        pagemsg("Can't find language name in text: [[%s]]" % (sections[i]))
      elif m.group(1) == "Russian":
        # Extract off trailing separator
        mm = re.match(r"^(.*?\n)(\n*--+\n*)$", sections[i], re.S)
        if mm:
          sections[i:i+1] = [mm.group(1), mm.group(2)]

        # When creating non-lemma forms, warn about matching lemma template
        if is_lemma_template:
          parsed = blib.parse_text(sections[i])
          for t in parsed.filter_templates():
            if is_lemma_template(t) and template_head_matches(t, inflections):
              pagemsg("WARNING: Creating non-lemma form and found matching lemma template: %s" % unicode(t))

        subsections = re.split("(^===+[^=\n]+===+\n)", sections[i], 0, re.M)

        # Go through each subsection in turn, looking for subsection
        # matching the POS with an appropriate headword template whose
        # head matches the inflected form
        for j in xrange(len(subsections)):
          match_pos = False
          if j > 0 and (j % 2) == 0:
            if re.match("^===+%s===+\n" % pos, subsections[j - 1]):
              match_pos = True

          # Found a POS match
          if match_pos:
            parsed = blib.parse_text(subsections[j])

            # True if the inflection codes in template T (an 'inflection of'
            # template) exactly match the inflections given in INFLS (in
            # any order), or if the former are a superset of the latter
            def compare_inflections(t, infls):
              infl_params = []
              for param in t.params:
                name = unicode(param.name)
                value = unicode(param.value)
                if name not in ["1", "2"] and re.search("^[0-9]+$", name) and value:
                  infl_params.append(value)
              inflset = set(infls)
              paramset = set(infl_params)
              if inflset == paramset:
                return True
              if paramset > inflset:
                pagemsg("WARNING: Found actual inflection %s whose codes are a superset of intended codes %s, accepting" % (
                  unicode(t), "|".join(infls)))
                return True
              if paramset < inflset:
                # Check to see if we match except for a missing perfective or
                # imperfective aspect, which we will update.
                if (paramset | {"pfv"}) == inflset or (paramset | {"impfv"}) == inflset:
                  pagemsg("Need to update actual inflection %s with intended codes %s" % (
                    unicode(t), "|".join(infls)))
                  return "update"
                else:
                  pagemsg("WARNING: Found actual inflection %s whose codes are a subset of intended codes %s" % (
                    unicode(t), "|".join(infls)))
              return False

            # Find the inflection headword template(s) (e.g. 'ru-noun form' or
            # 'head|ru|verb form').
            def template_name(t):
              if infltemp_is_head:
                return "|".join([unicode(t.name), getparam(t, "1"), getparam(t, "2")])
              else:
                return unicode(t.name)
            infl_headword_templates = [t for t in parsed.filter_templates()
                if template_name(t) == infltemp and
                template_head_matches(t, inflections)]

            # Find the definitional (typically 'inflection of') template(s).
            # We store a tuple of (TEMPLATE, NEEDS_UPDATE) where NEEDS_UDPATE
            # is true if we need to overwrite the form codes (this happens
            # when we want to add the verb aspect 'pfv' or 'impfv' to the
            # form codes).
            defn_templates = []
            for t in parsed.filter_templates():
              if (unicode(t.name) == deftemp and
                  compare_param(t, "1", lemma, lemmatr) and
                  (not deftemp_needs_lang or
                    compare_param(t, "lang", "ru", None))):
                if not deftemp_uses_inflection_of:
                  defn_templates.append((t, False))
                else:
                  result = compare_inflections(t, deftemp_param)
                  if result == "update":
                    defn_templates.append((t, True))
                  elif result:
                    defn_templates.append((t, False))

            def fetch_param_chain(t, firstparam, parampref):
              vals = []
              paramno = 0
              while True:
                paramno += 1
                val = getparam(t, firstparam if paramno == 1 else "%s%s" % (
                  parampref, paramno))
                if not val:
                  return vals
                else:
                  vals.append(val)

            def append_param_to_chain(t, val, firstparam, parampref):
              paramno = 0
              while True:
                paramno += 1
                next_param = firstparam if paramno == 1 else "%s%s" % (
                    parampref, paramno)
                if not getparam(t, next_param):
                  t.add(next_param, val)
                  return next_param

            def remove_param_chain(t, firstparam, parampref):
              paramno = 0
              changed = False
              while True:
                paramno += 1
                next_param = firstparam if paramno == 1 else "%s%s" % (
                    parampref, paramno)
                if getparam(t, next_param):
                  rmparam(t, next_param)
                  changed = True
                else:
                  return changed

            # For nouns and adjectives, check the existing gender of the given
            # headword template and attempt to make sure it matches the given
            # gender or can be compatibly modified to the new gender. Return
            # False if genders incompatible (and issue a warning if
            # WARNING_ON_FALSE), else modify existing gender if needed, and
            # return True. (E.g. existing "p" matches new "m-an" and will be
            # modified to "m-an-p"; # existing "m-p" matches new "m" and will
            # be left alone.)
            def check_fix_noun_adj_gender(headword_template, gender, warning_on_false):
              def gender_compatible(existing, new):
                # Compare existing and new m/f gender
                m = re.search(r"\b([mf])\b", existing)
                existing_mf = m and m.group(1)
                m = re.search(r"\b([mf])\b", new)
                new_mf = m and m.group(1)
                if existing_mf and new_mf and existing_mf != new_mf:
                  pagemsg("%sCan't modify mf gender from %s to %s" % (
                      "WARNING: " if warning_on_false else "",
                      existing_mf, new_mf))
                  return False
                new_mf = new_mf or existing_mf

                # Compare existing and new animacy
                m = re.search(r"\b(an|in)\b", existing)
                existing_an = m and m.group(1)
                m = re.search(r"\b(an|in)\b", new)
                new_an = m and m.group(1)
                if existing_an and new_an and existing_an != new_an:
                  pagemsg("%sCan't modify animacy from %s to %s" % (
                      "WARNING: " if warning_on_false else "",
                      existing_an, new_an))
                  return False
                new_an = new_an or existing_an

                # Compare existing and new plurality
                m = re.search(r"\b([p])\b", existing)
                existing_p = m and m.group(1)
                m = re.search(r"\b([p])\b", new)
                new_p = m and m.group(1)
                if existing_p and not is_noun_adj_plural:
                  pagemsg("%sExisting gender %s is plural but new form isn't plural" % (
                      "WARNING: " if warning_on_false else "", existing))
                  return False
                new_p = new_p or existing_p

                # Construct result
                return '-'.join([x for x in [new_mf, new_an, new_p] if x])

              if len(gender) == 0:
                return True # "nochange"

              existing_genders = fetch_param_chain(headword_template,
                  first_gender_param, "g")
              for g in gender:
                if g in existing_genders:
                  continue
                changed = False
                if existing_genders:
                  # Try to modify an existing gender to match the new gender
                  for paramno, existing in enumerate(existing_genders):
                    new_gender = gender_compatible(existing, g)
                    if new_gender:
                      newparam = first_gender_param if paramno == 0 else (
                          "g%s" % (paramno + 1))
                      pagemsg("Modifying gender param %s from %s to %s" %
                          (newparam, existing, new_gender))
                      headword_template.add(first_gender_param, new_gender)
                      changed = True
                      break
                  else:
                    pagemsg("%sUnable to modify existing genders %s to match new gender %s" % (
                      "WARNING: " if warning_on_false else "",
                      ",".join(existing_genders), g))
                if not changed:
                  newparam = append_param_to_chain(headword_template, g,
                      first_gender_param, "g")
                  pagemsg("Adding new gender param %s=%s" %
                      (newparam, g))
                subsections[j] = unicode(parsed)
                sections[i] = ''.join(subsections)
                notes.append("update gender %s" % g)
              return True # changed and "changed" or "nochange"

            # For verbs, the only gender is 'pf' or 'impf' (CURRENTLY UNUSED)
            #def check_fix_verb_gender(headword_template, gender):
            #  existing_genders = fetch_param_chain(headword_template,
            #      first_gender_param, "g")
            #  for g in gender:
            #    if g not in existing_genders:
            #      newparam = append_param_to_chain(headword_template, g,
            #        first_gender_param, "g")
            #      pagemsg("Added verb gender %s=%s" % (newparam, g))
            #      subsections[j] = unicode(parsed)
            #      sections[i] = ''.join(subsections)
            #      notes.append("update gender %s" % g)

            # Update the gender in HEADWORD_TEMPLATE according to GENDER
            # (which might be empty, meaning no updating) using
            # check_fix_gender(). Also update any other parameters in
            # HEADWORD_TEMPLATE according to PARAMS. (NOTE: We don't
            # currently have any such params, but we preserve this code
            # in any we will in the future.) Return False and issue a
            # warning if we're unable to update (meaning a parameter we
            # wanted to set already existed in HEADWORD_TEMPLATE with a
            # different value); else return True. If changes were made,
            # an appropriate note will be added to 'notes' and the
            # section and subsection text updated.
            def check_fix_infl_params(headword_template, params, gender,
                warning_on_false):
              if gender:
                if is_noun_or_adj:
                  if not check_fix_noun_adj_gender(headword_template, gender,
                      warning_on_false):
                    return False
              if is_verb_form:
                # If verb form, remove any existing gender, since it
                # instead goes into the definition line
                if remove_param_chain(headword_template, first_gender_param,
                    "g"):
                  subsections[j] = unicode(parsed)
                  sections[i] = ''.join(subsections)
                  notes.append("remove gender")

              # REMAINING CODE IN FUNCTION NOT CURRENTLY USED
              # First check that we can update params before changing anything
              for param, value in params:
                existing = getparam(headword_template, param)
                assert(value)
                if existing == value:
                  pass
                elif existing:
                  pagemsg("%sCan't modify %s from %s to %s" % (
                      "WARNING: " if warning_on_false else "",
                      param, existing, value))
                  return False
              # Now update params
              changed = False
              for param, value in params:
                existing = getparam(headword_template, param)
                assert(value)
                if existing:
                  assert(existing == value)
                else:
                  headword_template.add(param, value)
                  changed = True
                  notes.append("update %s=%s" % (param, value))
              if changed:
                subsections[j] = unicode(parsed)
                sections[i] = ''.join(subsections)
              return True

            # Replace the form-code parameters in 'inflection of'
            # (or 'ru-participle of') with those in INFLS, putting the
            # non-form-code parameters in the right places.
            def check_fix_defn_params(t, infls):
              # Following code mostly copied from fix_verb_form.py
              origt = unicode(t)
              # Fetch param 1 and param 2, and non-numbered params.
              param1 = getparam(t, "1")
              param2 = getparam(t, "2")
              lang = getparam(t, "lang")
              tr = getparam(t, "tr")
              non_numbered_params = []
              for param in t.params:
                pname = unicode(param.name)
                if not re.search(r"^[0-9]+$", pname) and pname not in ["lang", "tr"]:
                  non_numbered_params.append((pname, param.value))
              # Erase all params.
              del t.params[:]
              # Put back lang, param 1, param 2, tr, then the replacements
              # for the higher numbered params, then the non-numbered params.
              if lang:
                t.add("lang", lang)
              t.add("1", param1)
              t.add("2", param2)
              if tr:
                t.add("tr", tr)
              for paramno, param in enumerate(infls):
                t.add(str(paramno+3), param)
              for name, value in non_numbered_params:
                t.add(name, value)
              newt = unicode(t)
              if origt != newt:
                pagemsg("Replaced %s with %s" % (origt, newt))
                notes.append("update form codes (pfv/impfv)")
                subsections[j] = unicode(parsed)
                sections[i] = ''.join(subsections)

            # Make sure there's exactly one headword template.
            if len(infl_headword_templates) > 1:
              pagemsg("WARNING: Found multiple inflection headword templates for %s; taking no action"
                  % (infltype))
              break

            # We found both templates and their heads matched; inflection
            # entry is already present.
            if defn_templates and infl_headword_templates:
              pagemsg("Exists and has Russian section and found %s already in it"
                  % (infltype))
              # Maybe fix up auxiliary parameters (e.g. gender) in the headword
              # template.
              check_fix_infl_params(infl_headword_templates[0], [], gender,
                  True)
              # Maybe override the current form code parameters in the
              # definition template(s) with the supplied ones (i.e. those
              # derived from the declension/conjugation template on the
              # lemma page).
              for t, needs_update in defn_templates:
                if needs_update:
                  check_fix_defn_params(t, deftemp_param)
              # "Do nothing", but set a comment, in case we made a template
              # change like changing gender.
              comment = "Update params of existing entry: %s %s, %s %s" % (
                  infltype, joined_infls, lemmatype, lemma)
              break

            # At this point, didn't find either headword or definitional
            # template, or both. If we found headword template, insert
            # new definition in same section.
            elif infl_headword_templates:
              # Make sure we can set the gender appropriately (and other
              # inflection parameters, if any were to exist). If not, we will
              # end up checking for more entries and maybe adding an entirely
              # new entry.
              if check_fix_infl_params(infl_headword_templates[0],
                  [], gender, True): # was False but safer to issue warning
                subsections[j] = unicode(parsed)
                # If there's already a defn line present, insert after
                # any such defn lines. Else, insert at beginning.
                if re.search(r"^# \{\{%s\|" % deftemp, subsections[j], re.M):
                  if not subsections[j].endswith("\n"):
                    subsections[j] += "\n"
                  subsections[j] = re.sub(r"(^(# \{\{%s\|.*\n)+)" % deftemp,
                      r"\1# %s\n" % new_defn_template, subsections[j],
                      1, re.M)
                else:
                  subsections[j] = re.sub(r"^#", "# %s\n#" % new_defn_template,
                      subsections[j], 1, re.M)
                sections[i] = ''.join(subsections)
                pagemsg("Insert existing defn with {{%s}} at beginning after any existing such defns" % (
                    deftemp))
                comment = "Insert existing defn with {{%s}} at beginning after any existing such defns: %s %s, %s %s" % (
                    deftemp, infltype, joined_infls, lemmatype, lemma)
                break

        # else of for loop over subsections, i.e. no break out of loop
        else:
          if not need_new_entry:
            break
          # At this point we couldn't find an existing subsection with
          # matching POS and appropriate headword template whose head matches
          # the the inflected form.

          def insert_new_text_before_section(insert_at):
            pagemsg("Found section to insert %s before: [[%s]]" % (
                generic_infltype, subsections[insert_at + 1]))

            comment = "Insert entry for %s %s of %s before section for same lemma" % (
              infltype, joined_infls, lemma)
            if insert_at > 0:
              subsections[insert_at - 1] = ensure_two_trailing_nl(
                  subsections[insert_at - 1])
            if indentlevel == 3:
              subsections[insert_at:insert_at] = [newpos + "\n"]
            else:
              assert(indentlevel == 4)
              subsections[insert_at:insert_at] = [newposl4 + "\n"]
            sections[i] = ''.join(subsections)
            return comment

          def insert_new_text_after_section(insert_at, secafter_desc):
            pagemsg("Found section to insert %s after: [[%s]]" % (
                generic_infltype, subsections[insert_at - 1]))

            # Determine indent level and skip past sections at higher indent
            m = re.match("^(==+)", subsections[insert_at - 2])
            indentlevel = len(m.group(1))
            while insert_at < len(subsections):
              if (insert_at % 2) == 0:
                insert_at += 1
                continue
              m = re.match("^(==+)", subsections[insert_at])
              newindent = len(m.group(1))
              if newindent <= indentlevel:
                break
              pagemsg("Skipped past higher-indented subsection: [[%s]]" %
                  subsections[insert_at])
              insert_at += 1

            secmsg = "%s section for same lemma" % secafter_desc
            pagemsg("Inserting after %s" % secmsg)
            comment = "Insert entry for %s %s of %s after %s" % (
              infltype, joined_infls, lemma, secmsg)
            subsections[insert_at - 1] = ensure_two_trailing_nl(
                subsections[insert_at - 1])
            if indentlevel == 3:
              subsections[insert_at:insert_at] = [newpos + "\n"]
            else:
              assert(indentlevel == 4)
              subsections[insert_at:insert_at] = [newposl4 + "\n"]
            sections[i] = ''.join(subsections)
            return comment

          # If participle, try to find an existing noun or adjective with the
          # same lemma to insert before. Insert before the first such one.
          if is_participle:
            insert_at = None
            for j in xrange(len(subsections)):
              if j > 0 and (j % 2) == 0:
                if re.match("^===+(Noun|Adjective)===+", subsections[j - 1]):
                  parsed = blib.parse_text(subsections[j])
                  for t in parsed.filter_templates():
                    if (unicode(t.name) in ["ru-adj", "ru-noun", "ru-proper noun", "ru-noun+", "ru-proper noun+"] and
                        template_head_matches(t, inflections) and insert_at is None):
                      insert_at = j - 1

            if insert_at is not None:
              comment = insert_new_text_before_section(insert_at)
              break

          # If adjective form, try to find an existing participle form with
          # the same lemma to insert after. If short adjective form, also
          # try to find an existing adverb or predicative with the same
          # lemma to insert after. In all cases, insert after the last such
          # one.
          if is_adj_form:
            insert_at = None
            for j in xrange(2, len(subsections), 2):
              if re.match("^===+Participle===+", subsections[j - 1]):
                parsed = blib.parse_text(subsections[j])
                for t in parsed.filter_templates():
                  if (unicode(t.name) == "head" and getparam(t, "1") == "ru" and
                      getparam(t, "2") == "participle form" and
                      template_head_matches(t, inflections)):
                    insert_at = j + 1
              if is_short_adj_form:
                if re.match("^===+Adverb===+", subsections[j - 1]):
                  parsed = blib.parse_text(subsections[j])
                  for t in parsed.filter_templates():
                    if (unicode(t.name) in ["ru-adv"] and
                        template_head_matches(t, inflections)):
                      insert_at = j + 1
                elif re.match("^===+Predicative===+", subsections[j - 1]):
                  parsed = blib.parse_text(subsections[j])
                  for t in parsed.filter_templates():
                    if (unicode(t.name) == "head" and getparam(t, "1") == "ru" and
                        getparam(t, "2") == "predicative" and
                        template_head_matches(t, inflections)):
                      insert_at = j + 1
            if insert_at:
              comment = insert_new_text_after_section(insert_at,
                  "adverb/predicative/participle form" if is_short_adj_form
                  else "participle form")
              break

          # Now try to find an existing section corresponding to the same
          # lemma. This happens e.g. with verb forms, such as смо́трите
          # 2nd plural pres ind vs. смотри́те 2nd plural imperative, or
          # with nouns of e.g. accent patterns c and d, in the gen sg vs.
          # nom pl of masculine nouns.
          #
          # Insert after the last such section.

          insert_at = None
          for j in xrange(2, len(subsections), 2):
            if re.match("^===+%s===+\n" % pos, subsections[j - 1]):
              parsed = blib.parse_text(subsections[j])
              defn_templates = [t for t in parsed.filter_templates()
                  if unicode(t.name) == deftemp and
                  compare_param(t, "1", lemma, lemmatr) and
                  (not deftemp_needs_lang or
                    compare_param(t, "lang", "ru", None))]
              if defn_templates:
                insert_at = j + 1

          if insert_at:
            comment = insert_new_text_after_section(insert_at, generic_infltype)
            break

          pagemsg("Exists and has Russian section, appending to end of section")
          # [FIXME! Conceivably instead of inserting at end we should insert
          # next to any existing ===Noun=== (or corresponding POS, whatever
          # it is), in particular after the last one. However, this makes less
          # sense when we create separate etymologies, as we do. Conceivably
          # this would mean inserting after the last etymology section
          # containing an entry of the same part of speech.
          #
          # (Perhaps for now we should just skip creating entries if we find
          # an existing Russian entry?)] -- comment out of date
          if "\n===Etymology 1===\n" in sections[i]:
            j = 2
            while ("\n===Etymology %s===\n" % j) in sections[i]:
              j += 1
            pagemsg("Found multiple etymologies, adding new section \"Etymology %s\"" % (j))
            comment = "Append entry (Etymology %s) for %s %s of %s, pos=%s in existing Russian section" % (
              j, infltype, joined_infls, lemma, pos)
            sections[i] = ensure_two_trailing_nl(sections[i])

            sections[i] += "===Etymology %s===\n" % j + entrytextl4
          else:
            pagemsg("Wrapping existing text in \"Etymology 1\" and adding \"Etymology 2\"")
            comment = "Wrap existing Russian section in Etymology 1, append entry (Etymology 2) for %s %s of %s, pos=%s" % (
                infltype, joined_infls, lemma, pos)
            # Wrap existing text in "Etymology 1" and increase the indent level
            # by one of all headers
            sections[i] = re.sub("^\n*==Russian==\n+", "", sections[i])
            wikilink_re = r"^(\{\{wikipedia\|.*?\}\})\n*"
            mmm = re.match(wikilink_re, sections[i])
            wikilink = (mmm.group(1) + "\n") if mmm else ""
            if mmm:
              sections[i] = re.sub(wikilink_re, "", sections[i])
            sections[i] = re.sub("^===Etymology===\n", "", sections[i])
            sections[i] = ("==Russian==\n" + wikilink + "\n===Etymology 1===\n" +
                ("\n" if sections[i].startswith("==") else "") +
                ensure_two_trailing_nl(re.sub("^==(.*?)==$", r"===\1===",
                  sections[i], 0, re.M)) +
                "===Etymology 2===\n" + entrytextl4)
        break
      elif m.group(1) > "Russian":
        pagemsg("Exists; inserting before %s section" % (m.group(1)))
        comment = "Create Russian section and entry for %s %s of %s, pos=%s; insert before %s section" % (
            infltype, joined_infls, lemma, pos, m.group(1))
        sections[i:i] = [newsection, "\n----\n\n"]
        break

    else: # else of for loop over sections, i.e. no break out of loop
      pagemsg("Exists; adding section to end")
      comment = "Create Russian section and entry for %s %s of %s, pos=%s; append at end" % (
          infltype, joined_infls, lemma, pos)

      if sections:
        sections[-1] = ensure_two_trailing_nl(sections[-1])
        sections += ["----\n\n", newsection]
      else:
        pagemsg("WARNING: No language sections in current page")
        notes.append("formerly empty")
        if pagehead.lower().startswith("#redirect"):
          pagemsg("WARNING: Page is redirect, overwriting")
          notes.append("overwrite redirect")
          pagehead = re.sub(r"#redirect *\[\[(.*?)\]\] *(<!--.*?--> *)*\n*",
              r"{{also|\1}}\n", pagehead, 0, re.I)
        sections += [newsection]

    # End of loop over sections in existing page; rejoin sections
    newtext = pagehead + ''.join(sections) + pagetail

    if page.text != newtext:
      assert comment or notes

    # Eliminate sequences of 3 or more newlines, which may come from
    # ensure_two_trailing_nl(). Add comment if none, in case of existing page
    # with extra newlines.
    newnewtext = re.sub(r"\n\n\n+", r"\n\n", newtext)
    if newnewtext != newtext and not comment and not notes:
      notes = ["eliminate sequences of 3 or more newlines"]
    newtext = newnewtext

    if page.text == newtext:
      pagemsg("No change in text")
    elif verbose:
      pagemsg("Replacing <%s> with <%s>" % (page.text, newtext),
          simple = True)
    else:
      pagemsg("Text has changed")
    page.text = newtext

  # Executed whether creating new page or modifying existing page.
  # Check for changed text and save if so.
  notestext = '; '.join(notes)
  if notestext:
    if comment:
      comment += " (%s)" % notestext
    else:
      comment = notestext
  if page.text != existing_text:
    if save:
      pagemsg("Saving with comment = %s" % comment, simple=True)
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment, simple=True)

# Parse a noun/verb/adv form spec (from the user), one or more forms separated
# by commas, possibly including aliases. INFL_DICT is a dictionary
# mapping possible form codes to a tuple specifying the corresponding set of
# inflection codes in {{inflection of|...}}, or a list of multiple such tuples
# (for cases where a single form code refers to multiple inflections, such
# as with adjectives, where the form code gen_m specifies not only the genitive
# masculine singular but also the genitive neuter singular and the animate
# accusative masculine singular. ALIASES is a dictionary mapping aliases to
# form codes. Returns a list of tuples (FORM, INFLSETS), where FORM is a form
# code and INFLSETS is the corresponding value entry in INFL_DICT (a tuple of
# inflection codes, or a list of such tuples).
def parse_form_spec(formspec, infl_dict, aliases):
  forms = []
  for form in re.split(",", formspec):
    if form in aliases:
      for f in aliases[form]:
        if f not in forms:
          forms.append(f)
    elif form in infl_dict:
      if form not in forms:
        forms.append(form)
    else:
      raise ValueError("Invalid value '%s'" % form)

  infls = []
  for form in forms:
    infls.append((form, infl_dict[form]))
  return infls

adj_form_inflection_list = [
  ["nom_m", [("nom", "m", "s"), ("in", "acc", "m", "s")]],
  ["nom_f", ("nom", "f", "s")],
  ["nom_n", ("nom", "n", "s")],
  ["nom_p", [("nom", "p"), ("in", "acc", "p")]],
  ["nom_mp", ("nom", "m", "p")],
  ["gen_m", [("gen", "m", "s"), ("an", "acc", "m", "s"), ("gen", "n", "s")]],
  ["gen_f", ("gen", "f", "s")],
  ["gen_p", [("gen", "p"), ("an", "acc", "p")]],
  ["dat_m", [("dat", "m", "s"), ("dat", "n", "s")]],
  ["dat_f", ("dat", "f", "s")],
  ["dat_p", ("dat", "p")],
  ["acc_f", ("acc", "f", "s")],
  ["acc_n", ("acc", "n", "s")],
  ["ins_m", ("ins", "m", "s")],
  ["ins_f", ("ins", "f", "s")],
  ["ins_p", ("ins", "p")],
  ["pre_m", ("pre", "m", "s")],
  ["pre_f", ("pre", "f", "s")],
  ["pre_p", ("pre", "p")],
  ["short_m", ("short", "m", "s")],
  ["short_f", ("short", "f", "s")],
  ["short_n", ("short", "n", "s")],
  ["short_p", ("short", "p")]
]

adj_form_inflection_dict = dict(adj_form_inflection_list)
adj_form_aliases = {
    "all":[x for x, y in adj_form_inflection_list],
    "long":["nom_m", "nom_n", "nom_f", "nom_p", "nom_mp",
      "gen_m", "gen_f", "gen_p", "dat_m", "dat_f", "dat_p",
      "acc_f", "acc_n", "ins_m", "ins_f", "ins_p", "pre_m", "pre_f", "pre_p"],
    "short":["short_m", "short_n", "short_f", "short_p"]
}

noun_form_inflection_list = [
  ["nom_sg", ("nom", "s")],
  ["gen_sg", ("gen", "s")],
  ["dat_sg", ("dat", "s")],
  ["acc_sg", ("acc", "s")],
  ["acc_sg_an", ("an", "acc", "s")],
  ["acc_sg_in", ("in", "acc", "s")],
  ["ins_sg", ("ins", "s")],
  ["pre_sg", ("pre", "s")],
  ["nom_pl", ("nom", "p")],
  ["gen_pl", ("gen", "p")],
  ["dat_pl", ("dat", "p")],
  ["acc_pl", ("acc", "p")],
  ["acc_pl_an", ("an", "acc", "p")],
  ["acc_pl_in", ("in", "acc", "p")],
  ["ins_pl", ("ins", "p")],
  ["pre_pl", ("pre", "p")],
]

noun_form_inflection_dict = dict(noun_form_inflection_list)
noun_form_aliases = {
    "all":[x for x, y in noun_form_inflection_list],
    "sg":["nom_sg", "gen_sg", "dat_sg", "acc_sg", "acc_sg_an", "acc_sg_in",
      "ins_sg", "pre_sg"],
    "pl":["nom_pl", "gen_pl", "dat_pl", "acc_pl", "acc_pl_an", "acc_pl_in",
      "ins_pl", "pre_pl"],
}

verb_form_inflection_list = [
  # present tense
  ["pres_1sg", ("1", "s", "pres", "ind")],
  ["pres_2sg", ("2", "s", "pres", "ind")],
  ["pres_3sg", ("3", "s", "pres", "ind")],
  ["pres_1pl", ("1", "p", "pres", "ind")],
  ["pres_2pl", ("2", "p", "pres", "ind")],
  ["pres_3pl", ("3", "p", "pres", "ind")],
  # future tense
  ["futr_1sg", ("1", "s", "fut", "ind")],
  ["futr_2sg", ("2", "s", "fut", "ind")],
  ["futr_3sg", ("3", "s", "fut", "ind")],
  ["futr_1pl", ("1", "p", "fut", "ind")],
  ["futr_2pl", ("2", "p", "fut", "ind")],
  ["futr_3pl", ("3", "p", "fut", "ind")],
  # imperative
  ["impr_sg", ("2", "s", "imp")],
  ["impr_pl", ("2", "p", "imp")],
  # past
  ["past_m", ("m", "s", "past", "ind")],
  ["past_f", ("f", "s", "past", "ind")],
  ["past_n", ("n", "s", "past", "ind")],
  ["past_pl", ("p", "past", "ind")],
  ["past_m_short", ("short", "m", "s", "past", "ind")],
  ["past_f_short", ("short", "f", "s", "past", "ind")],
  ["past_n_short", ("short", "n", "s", "past", "ind")],
  ["past_pl_short", ("short", "p", "past", "ind")],
  # active participles
  ["pres_actv_part", ("pres", "act", "part")],
  ["past_actv_part", ("past", "act", "part")],
  # passive participles
  ["pres_pasv_part", ("pres", "pass", "part")],
  ["past_pasv_part", ("past", "pass", "part")],
  # adverbial participles
  ["pres_adv_part", ("pres", "adv", "part")],
  ["past_adv_part", ("past", "adv", "part")],
  ["past_adv_part_short", ("short", "past", "adv", "part")],
  # infinitive
  ["infinitive", ("infinitive")]
]
verb_form_inflection_dict = dict(verb_form_inflection_list)
verb_form_aliases = {
    "all":[x for x, y in verb_form_inflection_list],
    "pres":["pres_1sg", "pres_2sg", "pres_3sg", "pres_1pl", "pres_2pl", "pres_3pl"],
    "futr":["futr_1sg", "futr_2sg", "futr_3sg", "futr_1pl", "futr_2pl", "futr_3pl"],
    "impr":["impr_sg", "impr_pl"],
    "past":["past_m", "past_f", "past_n", "past_pl", "past_m_short", "past_f_short", "past_n_short", "past_pl_short"],
    "part":["pres_actv_part", "past_actv_part", "pres_pasv_part", "past_pasv_part", "pres_adv_part", "past_adv_part", "past_adv_part_short"]
}

def split_ru_tr(form):
  if "//" in form:
    rutr = re.split("//", form)
    assert len(rutr) == 2
    ru, tr = rutr
    return (ru, tr)
  else:
    return (form, None)

# Find inflection templates, skipping those under SKIP_POSES and issuing
# warnings for bad headers and bad level indentation, according to
# EXPECTED_HEADER and EXPECTED_POSES (see comment to create_forms()).
def find_inflection_templates(text, expected_header, expected_poses, skip_poses,
    is_inflection_template, pagemsg):
  templates = []

  sections = re.split("(^==[^=\n]+==\n)", text, 0, re.M)
  for i in xrange(2, len(sections), 2):
    if sections[i-1] == "==Russian==\n":
      subsections = re.split("(^===+[^=\n]+===+\n)", sections[i], 0, re.M)
      headers_at_level = {}
      last_levelno = 2
      for j in xrange(2, len(subsections), 2):
        m = re.search("^(=+)([^=\n]+)", subsections[j-1])
        levelno = len(m.group(1))
        header = m.group(2)
        headers_at_level[levelno] = header
        if levelno - last_levelno > 1:
          pagemsg("WARNING: Misformatted header level (jump by %s - %s = %s, in section %s)" % (
            levelno, last_levelno, levelno - last_levelno, subsections[j-1].replace("\n", "")))
        last_levelno = levelno
        parsed = blib.parse_text(subsections[j])
        for t in parsed.filter_templates():
          if is_inflection_template(t):
            if header != expected_header:
              pagemsg("WARNING: Expected inflection template under %s header but instead found under %s header" % (
                expected_header, header))
            pos_header = headers_at_level.get(levelno-1, None)
            if pos_header and pos_header not in expected_poses:
              pagemsg("WARNING: Inflection template under unexpected part of speech %s" %
                  pos_header)
            if pos_header not in skip_poses:
              templates.append(t)
            else:
              pagemsg("Skipping inflection template because under part of speech %s: %s" % (
                pos_header, unicode(t)))
  return templates

# Given a list of form values, each of which is a tuple (RUSSIAN, TRANSLIT)
# where the TRANSLIT may be None or the empty string (in both cases treated
# as missing), group by RUSSIAN to handle cases where multiple translits are
# possible, generate any missing translits and join by commas. Return the list
# of form values, in the same order except with multiple translits combined.
def group_translits(formvals, pagemsg, expand_text):
  # Group formvals by Russian, to group multiple translits
  formvals_by_russian = OrderedDict()
  for formvalru, formvaltr in formvals:
    if formvalru in formvals_by_russian:
      formvals_by_russian[formvalru].append(formvaltr)
    else:
      formvals_by_russian[formvalru] = [formvaltr]
  formvals = []
  # If there is more than one translit, then generate the
  # translit for any missing translit and join by commas
  for russian, translits in formvals_by_russian.iteritems():
    if len(translits) == 1:
      formvals.append((russian, translits[0]))
    else:
      manual_translits = []
      for translit in translits:
        if translit:
          manual_translits.append(translit)
        else:
          translit = expand_text("{{xlit|ru|%s}}" % russian)
          if not translit:
            pagemsg("WARNING: Error generating translit for %s" % russian)
          else:
            manual_translits.append(translit)
      joined_manual_translits = ", ".join(manual_translits)
      pagemsg("create_forms: For Russian %s, found multiple manual translits %s" %
          (russian, joined_manual_translits))
      formvals.append((russian, joined_manual_translits))
  return formvals

# Create required forms for all nouns/verbs/adjectives.
#
# LEMMAS_TO_PROCESS is a list of lemma pages to process. Entries are assumed
# to be without accents and have е in place of ё. If empty, process all lemmas
# of the appropriate part of speech.
#
# SAVE is as in create_inflection_entry(). STARTFROM and UPTO, if not None,
# delimit the range of pages to process (inclusive on both ends).
#
# FORMSPEC specifies the form(s) to do, a comma-separated list of form codes,
# possibly including aliases (e.g. 'all'). FORM_INFLECTION_DICT is a dictionary
# mapping possible form codes to a tuple of the corresponding inflection codes
# in {{inflection of|...}}, or a list of such tuples; see 'parse_form_spec'.
# FORM_ALIASES is a dictionary mapping aliases to form codes.
#
# POS specifies the part of speech (lowercase, singular, e.g. "verb").
# INFLTEMP specifies the inflection template name (e.g. "head|ru|verb form" or
# "ru-noun form"). DICFORM_CODES specifies the form code for the dictionary
# form (e.g. "infinitive", "nom_m") or a list of such codes to try (e.g.
# ["nom_sg", "nom_pl"]).
#
# EXPECTED_HEADER specifies the header that the inflection template (e.g.
# 'ru-decl-adj' for adjectives, 'ru-conj-2a' etc. for verbs) should be under
# (Declension or Conjugation); a warning will be issued if it's wrong.
# EXPECTED_POSES is a list of the parts of speech that the inflection template
# should be under (e.g. ["Noun", "Proper noun"]); a warning will be issued if
# an unexpected part of speech is found. A warning is also issued if the
# level indentation is wrong. SKIP_POSES is a list of parts of speech to skip
# the inflections of (e.g. ["Participle", "Pronoun"] for adjectives).
# IS_INFLECTION_TEMPLATE is a function that is passed one argument, a template,
# and should indicate if it's an inflection template. CREATE_FORM_GENERATOR
# is a function that's passed one argument, an inflection template, and should
# return a template (a string) that can be expanded to yield a set of forms,
# identified by form codes.
#
# IS_LEMMA_TEMPLATE is a function that is passed one argument, a template,
# and should indicate if it's a lemma template (e.g. 'ru-adj' for adjectives).
# This is used to issue warnings in case of non-lemma forms where there's
# a corresponding lemma (NOTE, this situation could be legitimate for nouns).
#
# GET_GENDER, if supplied, should be a function of three arguments (a template,
# the form code and the arguments resulting from calling CREATE_FORM_GENERATOR
# and parsing the result into a dictionary). It should return a list of gender
# codes to be inserted into the headword template. (NOTE: This is special-cased
# for verbs.)
#
# SKIP_INFLECTIONS, if supplied, should be a function of three arguments, the
# form name, Russian and translit (which may be missing), and should return
# true if the particular form value in question is to be skipped. This is
# used e.g. to skip periphrastic future forms.
def create_forms(lemmas_to_process, save, startFrom, upTo, formspec,
    form_inflection_dict, form_aliases, pos, infltemp, dicform_codes,
    expected_header, expected_poses, skip_poses, is_inflection_template,
    create_form_generator, is_lemma_template, get_gender=None,
    skip_inflections=None):

  forms_desired = parse_form_spec(formspec, form_inflection_dict,
      form_aliases)
  if type(dicform_codes) is not list:
    dicform_codes = [dicform_codes]

  # If lemmas_to_process, we want to process the lemmas in the order they're
  # in this list, but the lemmas in the list have е in place of ё, so we need
  # to do some work to get the corresponding pages with ё in them.
  if lemmas_to_process:
    lemmas_to_process_set = set(lemmas_to_process)
    unaccented_lemmas = {}
    for index, page in blib.cat_articles("Russian %ss" % pos):
      pagetitle = unicode(page.title())
      unaccented_title = ru.make_unstressed(pagetitle)
      if unaccented_title in lemmas_to_process_set:
        if unaccented_title in unaccented_lemmas:
          unaccented_lemmas[unaccented_title].append(pagetitle)
        else:
          unaccented_lemmas[unaccented_title] = [pagetitle]
    pagetitles_to_process = []
    for lemma in lemmas_to_process:
      if lemma in unaccented_lemmas:
        pagetitles_to_process.extend(unaccented_lemmas[lemma])
      else:
        msg("WARNING: Can't find pages to match lemma %s" % lemma)
    pages_to_process = ((index, pywikibot.Page(site, page)) for index, page in
        blib.iter_items(pagetitles_to_process, startFrom, upTo))
  else:
    pages_to_process = blib.cat_articles("Russian %ss" % pos, startFrom, upTo)

  for index, page in pages_to_process:
    pagetitle = unicode(page.title())
    #if lemmas_to_process and ru.make_unstressed(pagetitle) not in lemmas_to_process:
    #  continue
    def pagemsg(txt):
      msg("Page %s %s: %s" % (index, pagetitle, txt))
    def expand_text(tempcall):
      return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

    # Find the inflection templates. Rather than just look for all inflection
    # templates, we may skip those under certain parts of speech, e.g.
    # participles for adjective forms. This is to avoid the issue with
    # преданный, which has one adjectival inflection as an adjective
    # and a different one as a participle.
    inflection_templates = find_inflection_templates(page.text, expected_header,
        expected_poses, skip_poses, is_inflection_template, pagemsg)
    if len(inflection_templates) > 1 and pos == "adjective":
      pagemsg("WARNING: Multiple inflection templates for %s" % pagetitle)
    for t in inflection_templates:
      result = expand_text(create_form_generator(t))
      if not result:
        pagemsg("WARNING: Error generating %s forms, skipping" % pos)
        continue
      args = ru.split_generate_args(result)
      for dicform_code in dicform_codes:
        if dicform_code in args:
          break
      else:
        pagemsg("WARNING: No dictionary form available among putative codes %s, skipping" %
            ",".join(dicform_codes))
        continue
      if dicform_code != dicform_codes[0]:
        pagemsg("create_forms: Using non-default dictionary form code %s" % dicform_code)
      dicforms = re.split(",", args[dicform_code])
      if len(dicforms) > 1:
        pagemsg("create_forms: Found multiple dictionary forms: %s" % args[dicform_code])
      # Fetch dictionary forms, remove accents on monosyllables
      dicforms = [split_ru_tr(dicform) for dicform in dicforms]
      dicforms = [(ru.remove_monosyllabic_accents(dicru), dictr) for dicru, dictr in dicforms]
      # Group dictionary forms by Russian, to group multiple translits
      dicforms = group_translits(dicforms, pagemsg, expand_text)
      for dicformru, dicformtr in dicforms:
        for formname, inflsets in forms_desired:
          # Skip the dictionary form; also skip forms that don't have
          # listed inflections (e.g. singulars with plural-only nouns,
          # animate/inanimate variants when a noun isn't bianimate):
          if formname != dicform_code and formname in args and args[formname]:

            # Group inflections by unaccented Russian, so we process
            # multiple accent variants together
            formvals_by_pagename = OrderedDict()
            formvals = re.split(",", args[formname])
            if len(formvals) > 1:
              pagemsg("create_forms: Found multiple form values for %s=%s, dictionary form %s%s" %
                  (formname, args[formname], dicformru, dicformtr and " (%s)" % dicformtr or ""))
            for formval in formvals:
              formvalru, formvaltr = split_ru_tr(formval)
              formval_no_accents = ru.remove_accents(formvalru)
              if skip_inflections and skip_inflections(formname, formvalru, formvaltr):
                pagemsg("create_forms: Skipping %s=%s%s" % (formname, formvalru,
                  formvaltr and " (%s)" % formvaltr or ""))
              elif formval_no_accents in formvals_by_pagename:
                formvals_by_pagename[formval_no_accents].append((formvalru, formvaltr))
              else:
                formvals_by_pagename[formval_no_accents] = [(formvalru, formvaltr)]
            # Process groups of inflections
            formvals_by_pagename_items = formvals_by_pagename.items()
            if len(formvals_by_pagename_items) > 1:
              pagemsg("create_forms: For form %s, found multiple page names %s" % (
                formname, ",".join("%s" % formval_no_accents for formval_no_accents, inflections in formvals_by_pagename_items)))
            for formval_no_accents, inflections in formvals_by_pagename_items:
              inflections = [(ru.remove_monosyllabic_accents(infl), infltr) for infl, infltr in inflections]
              inflections_printed = ",".join("%s%s" %
                  (infl, " (%s)" % infltr if infltr else "")
                  for infl, infltr in inflections)
              if formval_no_accents == ru.remove_accents(dicformru):
                pagemsg("create_forms: Skipping form %s=%s because would go on lemma page" % (formname, inflections_printed))
              else:
                if len(inflections) > 1:
                  pagemsg("create_forms: For pagename %s, found multiple inflections %s" % (
                    formval_no_accents, inflections_printed))
                # Group inflections by Russian, to group multiple translits
                inflections = group_translits(inflections, pagemsg, expand_text)

                if type(inflsets) is not list:
                  inflsets = [inflsets]
                gender = get_gender(t, formname, args) if get_gender else []
                for inflset in inflsets:
                  if pos == "verb":
                    assert gender == ["pf"] or gender == ["impf"]
                    if gender == ["pf"]:
                      inflset = inflset + ("pfv",)
                    else:
                      inflset = inflset + ("impfv",)
                    gender = []
                  create_inflection_entry(save, index, inflections,
                    dicformru, dicformtr, pos.capitalize(),
                    "%s form %s" % (pos, formname), "dictionary form",
                    infltemp, "", "inflection of", inflset, gender,
                    is_lemma_template=is_lemma_template)

def create_verb_generator(t):
  verbtype = re.sub(r"^ru-conj-", "", unicode(t.name))
  params = re.sub(r"^\{\{ru-conj-.*?\|(.*)\}\}$", r"\1", unicode(t), 0, re.S)
  return "{{ru-generate-verb-forms|type=%s|%s}}" % (verbtype, params)

def skip_future_periphrastic(formname, ru, tr):
  return re.search(ur"^(бу́ду|бу́дешь|бу́дет|бу́дем|бу́дете|бу́дут) ", ru)

def get_verb_gender(t, formname, args):
  gender = re.sub("-.*", "", getparam(t, "1"))
  assert gender in ["pf", "impf"]
  return [gender]

def create_verb_forms(save, startFrom, upTo, formspec, lemmas_to_process):
  create_forms(lemmas_to_process, save, startFrom, upTo, formspec,
      verb_form_inflection_dict, verb_form_aliases,
      "verb", "head|ru|verb form", "infinitive",
      "Conjugation", ["Verb", "Idiom"], [],
      lambda t:unicode(t.name).startswith("ru-conj") and unicode(t.name) != "ru-conj-verb-see",
      create_verb_generator,
      lambda t:unicode(t.name) == "ru-verb",
      get_gender=get_verb_gender,
      skip_inflections=skip_future_periphrastic)

def get_adj_gender(t, formname, args):
  if "short" in formname:
    m = re.search("_([mfnp])", formname)
    assert m
    return [m.group(1)]
  else:
    return []

def create_adj_forms(save, startFrom, upTo, formspec, lemmas_to_process):
  create_forms(lemmas_to_process, save, startFrom, upTo, formspec,
      adj_form_inflection_dict, adj_form_aliases,
      "adjective", "head|ru|adjective form", "nom_m",
      # Proper noun can occur because names are formatted using {{ru-decl-adj}}
      # with decl type 'proper'.
      "Declension", ["Adjective", "Participle", "Pronoun", "Proper noun"],
      ["Participle", "Pronoun", "Proper noun"],
      lambda t:unicode(t.name) == "ru-decl-adj",
      lambda t:re.sub(r"^\{\{ru-decl-adj", "{{ru-generate-adj-forms", unicode(t)),
      lambda t:unicode(t.name) == "ru-adj",
      #get_gender=get_adj_gender
      )

def get_noun_gender(t, formname, args):
  return [re.sub("-p$", "", x) for x in re.split(",", args["g"])]

def create_noun_forms(save, startFrom, upTo, formspec, lemmas_to_process):
  create_forms(lemmas_to_process, save, startFrom, upTo, formspec,
      noun_form_inflection_dict, noun_form_aliases,
      "noun", "ru-noun form", ["nom_sg", "nom_pl"],
      "Declension", ["Noun", "Proper noun"], [],
      lambda t:unicode(t.name) == "ru-noun-table",
      lambda t:re.sub(r"^\{\{ru-noun-table", "{{ru-generate-noun-args", unicode(t)),
      lambda t:unicode(t.name) in ["ru-noun", "ru-proper noun", "ru-noun+", "ru-proper noun+"],
      get_gender=get_noun_gender)

pa = blib.create_argparser("Create Russian inflection entries")
pa.add_argument("--adj-form",
    help="""Do specified adjective-form inflections, a comma-separated list.
Each element is compatible with the override specifications used in
'ru-decl-adj': nom_m, nom_n, nom_f, nom_p, nom_mp, gen_m, gen_f, gen_p,
dat_m, dat_f, dat_p, acc_f, acc_n, ins_m, ins_f, ins_p, pre_m, pre_f, pre_p,
short_m, short_n, short_f, short_p. Also possible is 'all' (all forms),
'long' (all long forms), 'short' (all short forms). The nominative masculine
singular form will not be created even if specified, because it is the
same as the dictionary/lemma form. Also, non-existent forms for particular
adjectives will not be created.""")
pa.add_argument("--noun-form",
    help="""Do specified noun-form inflections, a comma-separated list.
Each element is compatible with the override specifications used in
'ru-noun-table': nom_sg, gen_sg, dat_sg, acc_sg, ins_sg, pre_sg, nom_pl,
gen_pl, dat_pl, acc_pl, ins_pl, pre_pl, acc_sg_an, acc_sg_in, acc_pl_an,
acc_pl_in. Also possible is 'all' (all forms), 'sg' (all singular forms),
'pl' (all plural forms). The nominative singular form will not be created
even if specified, because it is the same as the dictionary/lemma form,
nor will accusative singulars that have the same form as the nominative
singular (or accusative plurals that have the same form as the nominative
plural, for pluralia tantum). Also, non-existent forms for particular nouns
will not be created. Note that the animate/inanimate accusative variants
are only for bianimate nouns.""")
pa.add_argument("--verb-form",
    help="""Do specified verb-form inflections, a comma-separated list.
Each element is compatible with the specifications used in module ru-verb:
pres_1sg, pres_2sg, pres_3sg, pres_1pl, pres_2pl, pres_3pl;
futr_1sg, futr_2sg, futr_3sg, futr_1pl, futr_2pl, futr_3pl;
impr_sg, impr_pl;
past_m, past_f, past_n, past_pl;
past_m_short, past_f_short, past_n_short, past_pl_short;
pres_actv_part, past_actv_part, pres_pasv_part, past_pasv_part,
pres_adv_part, past_adv_part, past_adv_part_short;
infinitive (ignored). Also possible is 'all' (all forms), 'pres' (all present
forms), 'futr' (all future forms), 'impr' (all imperative forms), 'past'
(all past forms). The infinitive form will not be created even if specified,
because it is the same as the dictionary/lemma form. Also, non-existent forms
for particular verbs will not be created.""")
pa.add_argument("--lemmafile",
    help=u"""List of lemmas to process. Assumed to be without accents and have е in place of ё.""")

params = pa.parse_args()
startFrom, upTo = blib.get_args(params.start, params.end)

if params.lemmafile:
  lemmas_to_process = [x.strip() for x in codecs.open(params.lemmafile, "r", "utf-8")]
else:
  lemmas_to_process = []
if params.adj_form:
  create_adj_forms(params.save, startFrom, upTo, params.adj_form, lemmas_to_process)
if params.noun_form:
  create_noun_forms(params.save, startFrom, upTo, params.noun_form, lemmas_to_process)
if params.verb_form:
  create_verb_forms(params.save, startFrom, upTo, params.verb_form, lemmas_to_process)

blib.elapsed_time()

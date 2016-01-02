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

import pywikibot, re, sys, codecs, argparse

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
def fetch_noun_lemma(template, expand_text):
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
# If ENTRYTEXT is given, this is the text to use for the entry, starting
# directly after the "==Etymology==" line, which is assumed to be necessary.
# If not given, this text is synthesized from the other parameters.
#
# IS_LEMMA_TEMPLATE is a function that is passed one argument, a template,
# and should indicate if it's a lemma template (e.g. 'ru-adj' for adjectives).
# This is used to issue warnings in case of non-lemma forms where there's
# a corresponding lemma (NOTE, this situation could be legitimate for nouns).
#
def create_inflection_entry(save, index, inflections, lemma, lemmatr,
    pos, infltype, lemmatype, infltemp, infltemp_param, deftemp,
    deftemp_param, deftemp_needs_lang=True, entrytext=None,
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
  is_short_adj_form = "adjective form short" in infltype
  deftemp_uses_inflection_of = deftemp == "inflection of"
  infltemp_is_head = infltemp.startswith("head|")

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
    paramval = getparam(t, param)
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
    headparam = []
    headno = 0
    for infl, infltr in inflections:
      headno += 1
      if headno == 1:
        headparam.append("%s%s%s" % ("head=" if infltemp_is_head else "", infl,
          "|tr=%s" % infltr if infltr else ""))
      else:
        headparam.append("head%s=%s%s" % (headno, infl,
          "|tr=%s" % infltr if infltr else ""))
    # Synthesize new entry. Some of the parts here besides 'entrytext',
    # 'entrytextl4' and 'newsection' are used down below when creating
    # verb parts and participles; these parts don't exist when 'entrytext'
    # was passed in, but that isn't a problem because it isn't passed in
    # when creating verb parts or participles.
    new_headword_template = "{{%s|%s%s}}" % (infltemp, "|".join(headparam),
        infltemp_param)
    new_defn_template = "{{%s%s|%s%s%s}}" % (
      deftemp, "|lang=ru" if deftemp_needs_lang else "",
      lemma, "|tr=%s" % lemmatr if lemmatr else "",
      deftemp_param if isinstance(deftemp_param, basestring) else "||" + "|".join(deftemp_param))
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
  existing_text = page.text

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
                if name not in ["1", "2"] and re.search("^[0-9]+$", name):
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
                pagemsg("WARNING: Found actual inflection %s whose codes are a subset of intended codes %s" % (
                  unicode(t), "|".join(infls)))
              return False

            # Find the inflection headword (e.g. 'ru-noun form' or
            # 'head|ru|verb form') and definitional (typically 'inflection of')
            # templates.

            def template_name(t):
              if infltemp_is_head:
                return "|".join([unicode(t.name), getparam(t, "1"), getparam(t, "2")])
              else:
                return unicode(t.name)
            infl_headword_templates = [t for t in parsed.filter_templates()
                if template_name(t) == infltemp and
                template_head_matches(t, inflections)]
            defn_templates = [t for t in parsed.filter_templates()
                if unicode(t.name) == deftemp and compare_param(t, "1", lemma, lemmatr)
                and (not deftemp_needs_lang or compare_param(t, "lang", "ru", None))
                and (not deftemp_uses_inflection_of or compare_inflections(t, deftemp_param))]

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
              break

            # At this point, didn't find either headword or definitional
            # template, or both. If we found headword template, insert
            # new definition in same section.
            elif infl_headword_templates:
              subsections[j] = unicode(parsed)
              if subsections[j][-1] != '\n':
                subsections[j] += '\n'
              subsections[j] = re.sub(r"^(.*\n#[^\n]*\n)",
                  r"\1# %s\n" % new_defn_template, subsections[j], 1, re.S)
              sections[i] = ''.join(subsections)
              pagemsg("Adding new definitional template to existing defn for pos = %s" % (pos))
              comment = "Add new definitional template to existing defn: %s %s, %s %s, pos=%s" % (
                  infltype, joined_infls, lemmatype, lemma, pos)
              break

        # else of for loop over subsections, i.e. no break out of loop
        else:
          if not need_new_entry:
            break
          # At this point we couldn't find an existing subsection with
          # matching POS and appropriate headword template whose head matches
          # the the inflected form.

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
              pagemsg("Found section to insert participle before: [[%s]]" %
                  subsections[insert_at + 1])

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
              pagemsg("Found section to insert adjective form after: [[%s]]" %
                  subsections[insert_at - 1])

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

              if is_short_adj_form:
                possible_shared_pos = "adverb/predicative/participle form"
              else:
                possible_shared_pos = "participle form"
              pagemsg("Inserting after %s section for same lemma" %
                  possible_shared_pos)
              comment = "Insert entry for %s %s of %s after %s section for same lemma" % (
                infltype, joined_infls, lemma, possible_shared_pos)
              subsections[insert_at - 1] = ensure_two_trailing_nl(
                  subsections[insert_at - 1])
              if indentlevel == 3:
                subsections[insert_at:insert_at] = [newpos + "\n"]
              else:
                assert(indentlevel == 4)
                subsections[insert_at:insert_at] = [newposl4 + "\n"]
              sections[i] = ''.join(subsections)
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
          notes.append("overwriting redirect")
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

nom_form_inflection_list = [
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

nom_form_inflection_dict = dict(nom_form_inflection_list)
nom_form_aliases = {
    "all":[x for x, y in nom_form_inflection_list]
}

verb_form_inflection_list = [
  # present tense
  ["pres_1sg", ("1", "sg", "pres", "ind")],
  ["pres_2sg", ("2", "sg", "pres", "ind")],
  ["pres_3sg", ("3", "sg", "pres", "ind")],
  ["pres_1pl", ("1", "pl", "pres", "ind")],
  ["pres_2pl", ("2", "pl", "pres", "ind")],
  ["pres_3pl", ("3", "pl", "pres", "ind")],
  # future tense
  ["futr_1sg", ("1", "sg", "fut", "ind")],
  ["futr_2sg", ("2", "sg", "fut", "ind")],
  ["futr_3sg", ("3", "sg", "fut", "ind")],
  ["futr_1pl", ("1", "pl", "fut", "ind")],
  ["futr_2pl", ("2", "pl", "fut", "ind")],
  ["futr_3pl", ("3", "pl", "fut", "ind")],
  # imperative
  ["impr_sg", ("2", "sg", "imp")],
  ["impr_pl", ("2", "pl", "imp")],
  # past
  ["past_m", ("m", "sg", "past", "ind")],
  ["past_f", ("f", "sg", "past", "ind")],
  ["past_n", ("n", "sg", "past", "ind")],
  ["past_pl", ("p", "past", "ind")],
  ["past_m_short", ("short", "m", "sg", "past", "ind")],
  ["past_f_short", ("short", "f", "sg", "past", "ind")],
  ["past_n_short", ("short", "n", "sg", "past", "ind")],
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

def sechead_matches_poses(sechead, matching_poses):
  for pos in matching_poses:
    m = re.search("^===+([^=\n]+)===+\n$", sechead)
    assert m
    if m.group(1) == pos:
      return True
  return False

def find_inflection_templates(text, matching_poses, is_inflection_template):
  templates = []

  sections = re.split("(^==[^=\n]+==\n)", text, 0, re.M)
  for i in xrange(2, len(sections), 2):
    if sections[i-1] == "==Russian==\n":
      l3secs = re.split("(^===[^=\n]+===\n)", sections[i], 0, re.M)
      for j in xrange(2, len(l3secs), 2):
        if sechead_matches_poses(l3secs[j-1], matching_poses):
          for t in blib.parse_text(l3secs[j]).filter_templates():
            if is_inflection_template(t):
              templates.append(t)
        l4secs = re.split("(^====[^=\n]+====\n)", l3secs[j], 0, re.M)
        for k in xrange(2, len(l4secs), 2):
          if sechead_matches_poses(l4secs[k-1], matching_poses):
            for t in blib.parse_text(l4secs[k]).filter_templates():
              if is_inflection_template(t):
                templates.append(t)
  return templates

# Create required forms for all nouns/verbs/adjectives.
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
# "ru-noun form"). DICFORM_CODE specifies the form code for the dictionary
# form (e.g. "infinitive", "nom_m" or "nom_sg").
#
# MATCHING_POSES specifies the parts of speech to look under to find
# inflection templates; a list of capitalized parts of speech, e.g.
# "Proper nouns". IS_INFLECTION_TEMPLATE is a function that is passed
# one argument, a template, and should indicate if it's an inflection template
# (e.g. 'ru-conj-2a' for verbs). CREATE_FORM_GENERATOR is a function that's
# passed one argument, an inflection template, and should return a template
# (a string) that can be expanded to yield a set of forms, identified by form
# codes.
#
# IS_LEMMA_TEMPLATE is a function that is passed one argument, a template,
# and should indicate if it's a lemma template (e.g. 'ru-adj' for adjectives).
# This is used to issue warnings in case of non-lemma forms where there's
# a corresponding lemma (NOTE, this situation could be legitimate for nouns).
def create_forms(save, startFrom, upTo, formspec,
    form_inflection_dict, form_aliases, pos, infltemp, dicform_code,
    matching_poses, is_inflection_template, create_form_generator,
    is_lemma_template):
  forms_desired = parse_form_spec(formspec, form_inflection_dict,
      form_aliases)
  for index, page in blib.cat_articles("Russian %ss" % pos, startFrom, upTo):
    pagetitle = unicode(page.title())
    def pagemsg(txt):
      msg("Page %s %s: %s" % (index, pagetitle, txt))
    def expand_text(tempcall):
      return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

    # Find the inflection templates. Rather than just look for all inflection
    # templates, we look for those under the right parts of speech. This is
    # to avoid the issue with преданный, which has one adjectival inflection
    # as an adjective and a different one as a participle.
    for t in find_inflection_templates(page.text, matching_poses, is_inflection_template):
      result = expand_text(create_form_generator(t))
      if not result:
        pagemsg("WARNING: Error generating %s forms, skipping" % pos)
        continue
      args = ru.split_generate_args(result)
      dicforms = re.split(",", args[dicform_code])
      if len(dicforms) > 1:
        pagemsg("create_forms: Found multiple dictionary forms: %s" % args[dicform_code])
      for dicform in dicforms:
        for formname, inflsets in forms_desired:
          # Skip the dictionary form; also skip forms that don't have
          # listed inflections (e.g. singulars with plural-only nouns,
          # animate/inanimate variants when a noun isn't bianimate):
          if formname != dicform_code and formname in args and args[formname]:
            dicformru, dicformtr = split_ru_tr(dicform)

            # Group inflections by unaccented Russian, so we process
            # multiple accent variants together
            formvals_by_pagename = OrderedDict()
            formvals = re.split(",", args[formname])
            if len(formvals) > 1:
              pagemsg("create_forms: Found multiple form values for %s=%s, dictionary form %s" %
                  (formname, args[formname], dicform))
            for formval in formvals:
              formvalru, formvaltr = split_ru_tr(formval)
              formval_no_accents = ru.remove_accents(formvalru)
              if formval_no_accents in formvals_by_pagename:
                formvals_by_pagename[formval_no_accents].append((formvalru, formvaltr))
              else:
                formvals_by_pagename[formval_no_accents] = [(formvalru, formvaltr)]
            # Process groups of inflections
            formvals_by_pagename_items = formvals_by_pagename.items()
            if len(formvals_by_pagename_items) > 1:
              pagemsg("create_forms: For form %s, found multiple page names %s" % (
                formname, ",".join("%s" % formval_no_accents for formval_no_accents, inflections in formvals_by_pagename_items)))
            for formval_no_accents, inflections in formvals_by_pagename_items:
              if len(inflections) > 1:
                pagemsg("create_forms: For pagename %s, found multiple inflections %s" % (
                  formval_no_accents, ",".join("%s%s" % (infl, " (%s)" % infltr if infltr else "") for infl, infltr in inflections)))
              # Group inflections by Russian, to group multiple translits
              formvals_by_russian = OrderedDict()
              for formvalru, formvaltr in inflections:
                if formvalru in formvals_by_russian:
                  formvals_by_russian[formvalru].append(formvaltr)
                else:
                  formvals_by_russian[formvalru] = [formvaltr]
              inflections = []
              # If there is more than one translit, then generate the
              # translit for any missing translit and join by commas
              for russian, translits in formvals_by_russian.iteritems():
                if len(translits) == 1:
                  inflections.append((russian, translits[0]))
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
                  inflections.append((russian, joined_manual_translits))

              if type(inflsets) is not list:
                inflsets = [inflsets]
              for inflset in inflsets:
                create_inflection_entry(save, index, inflections,
                  dicformru, dicformtr, pos.capitalize(),
                  "%s form %s" % (pos, formname), "dictionary form",
                  infltemp, "", "inflection of", inflset,
                  is_lemma_template=is_lemma_template)

def create_verb_generator(t):
  verbtype = re.sub(r"^ru-conj-", "", unicode(t.name))
  params = re.sub(r"^\{\{ru-conj-.*?\|(.*)\}\}$", r"\1", unicode(t))
  return "{{ru-generate-verb-forms|type=%s|%s}}" % (verbtype, params)

def create_verb_forms(save, startFrom, upTo, formspec):
  create_forms(save, startFrom, upTo, formspec,
      verb_form_inflection_dict, verb_form_aliases,
      "verb", "head|ru|verb form", "infinitive",
      ["Verb"], lambda t:unicode(t.name).startswith("ru-conj"),
      create_verb_generator,
      lambda t:unicode(t.name) == "ru-verb")

def create_adj_forms(save, startFrom, upTo, formspec):
  create_forms(save, startFrom, upTo, formspec,
      adj_form_inflection_dict, adj_form_aliases,
      "adjective", "head|ru|adjective form", "nom_m",
      ["Adjective"], lambda t:unicode(t.name) == "ru-decl-adj",
      lambda t:re.sub(r"^\{\{ru-decl-adj", "{{ru-generate-adj-forms", unicode(t)),
      lambda t:unicode(t.name) == "ru-adj")

def create_noun_forms(save, startFrom, upTo, formspec):
  create_forms(save, startFrom, upTo, formspec,
      noun_form_inflection_dict, noun_form_aliases,
      "noun", "ru-noun form", "nom_sg",
      ["Noun", "Proper Noun"],
      lambda t:unicode(t.name) == "ru-noun-table",
      lambda t:re.sub(r"^\{\{ru-noun-table", "{{ru-generate-noun-forms", unicode(t)),
      lambda t:unicode(t.name) in ["ru-noun", "ru-proper noun", "ru-noun+", "ru-proper noun+"])

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
'ru-noun-table': nom_sg, gen_sg, dat_sg, acc_sg, ins_sg, pre_sg. Also
possible is 'all' (all forms), 'sg' (all singular forms), 'pl' (all plural
forms). orms). The nominative singular form will not be created even if
specified, because it is the same as the dictionary/lemma form. Also,
non-existent forms for particular nouns will not be created.""")
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

params = pa.parse_args()
startFrom, upTo = blib.get_args(params.start, params.end)

if params.adj_form:
  create_adj_forms(params.save, startFrom, upTo, params.adj_form)
if params.noun_form:
  create_noun_forms(params.save, startFrom, upTo, params.noun_form)
if params.verb_form:
  create_verb_forms(params.save, startFrom, upTo, params.verb_forms)

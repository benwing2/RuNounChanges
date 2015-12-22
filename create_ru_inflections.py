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

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru

verbose = True

def remove_diacritics(word):
  return re.sub(DIACRITIC_ANY, "", word)

def remove_links(text):
  text = re.sub(r"\[\[[^|\]]*?\|", "", text)
  text = re.sub(r"\[\[", "", text)
  text = re.sub(r"\]\]", "", text)
  return text

def get_vn_gender(word, form):
  # Remove -un or -u i3rab
  word = re.sub(UNU + "$", "", reorder_shadda(word))
  if word.endswith(TAM):
    return "f"
  elif word.endswith(AN + AMAQ) or word.endswith(AN + ALIF):
    return "m"
  elif word.endswith(ALIF + HAMZA):
    if form != "I":
      return "m"
    elif re.match("^.[" + A + I + U + "]." + A + ALIF + HAMZA + "$", word):
      # only 3 consonants including hamza, which subs for a final-weak
      # consonant
      return "m"
    else:
      return "?"
  elif (word.endswith(AMAQ) or word.endswith(AMAD) or word.endswith(ALIF)):
    return "?"
  else:
    return "m"

# Make sure there are two trailing newlines
def ensure_two_trailing_nl(text):
  return re.sub(r"\n*$", r"\n\n", text)

lemma_inflection_counts = {}

# Create or insert a section describing a given inflection of a given lemma.
# INFLECTION is the vocalized inflectional form (e.g. the
# plural, feminine, verbal noun, participle, etc.); LEMMA is the vocalized
# lemma (e.g. the singular, masculine or dictionary form of a verb); INFLTR
# and LEMMATR are the associated manual transliterations (if any). POS is the
# part of speech of the word (capitalized, e.g. "Noun"). Only save the changed
# page if SAVE is true. INDEX is the numeric index of the lemma page, for
# ID purposes and to aid restarting. INFLTYPE is e.g. "plural", "feminine",
# "verbal noun", "active participle" or "passive participle", and is used in
# messages; both POS and INFLTYPE are used in special-case code that is
# appropriate to only certain inflectional types. LEMMATYPE is e.g.
# "singular", "masculine" or "dictionary form" and is used in messages.
# INFLTEMP is the headword template for the inflected-word entry (e.g.
# "ar-noun-pl", "ar-adj-pl" or "ar-adj-fem"). INFLTEMP_PARAM is a parameter
# or parameters to add to the created INFLTEMP template, and should be either
# empty or of the form "|foo=bar" (or e.g. "|foo=bar|baz=bat" for more than
# one parameter). DEFTEMP is the definitional template that points to the
# base form (e.g. "plural of", "masculine plural of" or "feminine of").
# DEFTEMP_PARAM is a parameter or parameters to add to the created DEFTEMP
# template, similar to INFLTEMP_PARAM. If ENTRYTEXT is given, this is the
# text to use for the entry, starting directly after the "==Etymology==" line,
# which is assumed to be necessary. If not given, this text is synthesized
# from the other parameters.
def create_inflection_entry(save, index, inflection, infltr, lemma, lemmatr,
    pos, infltype, lemmatype, infltemp, infltemp_param, deftemp,
    deftemp_param, entrytext=None):

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
  inflection = blib.remove_links(inflection)

  # Fetch pagename, create pagemsg() fn to output msg with page name included
  pagename = ru.remove_accents(inflection)
  def pagemsg(text, simple = False):
    if simple:
      msg("Page %s %s: %s" % (index, pagename, text))
    else:
      msg("Page %s %s: %s: %s %s%s, %s %s%s" % (index, pagename, text,
        infltype, inflection, " (%s)" % infltr if infltr else "",
        lemmatype, lemma, " (%s)" % lemmatr if lemmatr else ""))

  is_participle = infltype.endswith("participle")
  is_vn = infltype == "verbal noun"
  is_verb_part = pos == "Verb"
  if is_verb_part:
    # Make sure infltemp_param is '|' + FORM, as we expect
    assert(len(infltemp_param) >= 2 and infltemp_param[0] == '|'
        and infltemp_param[1] in ["I", "V", "X"])
    verb_part_form = infltemp_param[1:]
    verb_part_inserted_defn = False
  is_plural_noun = infltype == "plural" and pos == "Noun"
  vn_or_participle = is_vn or is_participle
  lemma_is_verb = is_verb_part or vn_or_participle

  if inflection == "-":
    pagemsg("Not creating %s entry - for %s %s%s" % (
      infltype, lemmatype, lemma, " (%s)" % lemmatr if lemmatr else ""))
    return

  # Prepare to create page
  pagemsg("Creating entry")
  infl_no_vowels = pagename
  lemma_no_vowels = remove_diacritics(lemma)
  page = pywikibot.Page(site, pagename)

  def compare_param(template, param, value):
    paramval = getparam(template, param)
    return paramval == value

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
    new_headword_template_prefix = "%s|%s" % (infltemp, inflection)
    new_headword_template = "{{%s%s%s}}" % (new_headword_template_prefix,
        infltemp_param, "|tr=%s" % infltr if infltr else "")
    new_defn_template = "{{%s|%s%s%s}}" % (
      deftemp, lemma,
      "|tr=%s" % lemmatr if lemmatr else "",
      deftemp_param)
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
        infltype, inflection, lemma, pos)
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

        subsections = re.split("(^===+[^=\n]+===+\n)", sections[i], 0, re.M)

        # Go through each subsection in turn, looking for subsection
        # matching the POS with an appropriate headword template whose
        # head matches the inflected form
        for j in xrange(len(subsections)):
          match_pos = False
          particip_pos_mismatch = False
          if j > 0 and (j % 2) == 0:
            if re.match("^===+%s===+\n" % pos, subsections[j - 1]):
              match_pos = True
            if is_participle:
              for mismatch_pos in ["Noun", "Adjective"]:
                if re.match("^===+%s===+\n" % mismatch_pos, subsections[j - 1]):
                  particip_pos_mismatch = True
                  particip_mismatch_pos = mismatch_pos
                  break

          # Found a POS match
          if match_pos or particip_pos_mismatch:
            parsed = blib.parse_text(subsections[j])

            # Find the inflection headword (e.g. 'ar-noun-pl') and
            # definitional (e.g. 'plural of') templates. We require that
            # they match, either exactly (apart from i3rab) or only in the
            # consonants. If verb part, also require that the conj form match
            # in the inflection headword template, but don't require that
            # the lemma match in the definitional template.

            # First, for each template, return a tuple of
            # (template, param, matches), where MATCHES is true if any head
            # matches FORM and PARAM is the (first) matching head param.
            def template_head_match_info(template, form):
              # Look at all heads
              if compare_param(template, "1", form):
                return (template, "1", True)
              i = 2
              while True:
                param = "head" + str(i)
                if not getparam(template, param):
                  return (template, None, False)
                if compare_param(template, param, form):
                  return (template, param, True)
                i += 1
            # True if any head in the template matches FORM.
            def template_head_matches(template, form):
              return template_head_match_info(template, form)[2]
            head_matches_tuples = [template_head_match_info(t, inflection)
                for t in parsed.filter_templates()]
            # Now get a list of (TEMPLATE, PARAM) for all matching templates,
            # where PARAM is the matching head param, as above.
            infl_headword_templates = (
                [(t, param) for t, param, matches in head_matches_tuples
                 if t.name == infltemp and matches
                 and (not is_verb_part or compare_param(t, "2", verb_part_form))])
            defn_templates = [t for t in parsed.filter_templates()
                if t.name == deftemp and (is_verb_part or
                compare_param(t, "1", lemma))]
            # Special-case handling for actual noun plurals. We expect an
            # ar-noun but if we encounter an ar-coll-noun with the plural as
            # the (collective) head and the singular as the singulative, we
            # output a message and skip so we don't end up creating a
            # duplicate entry.
            if is_plural_noun:
              headword_collective_templates = [t for t in parsed.filter_templates()
                  if t.name == "ar-coll-noun" and template_head_matches(t, inflection)
                  and compare_param(t, "sing", lemma)]
              if headword_collective_templates:
                pagemsg("WARNING: Exists and has Russian section and found collective noun with %s already in it; taking no action"
                    % (infltype))
                break

            def particip_mismatch_check():
              if particip_pos_mismatch:
                pagemsg("WARNING: Found match for %s but in ===%s=== section rather than ===%s==="
                    % (infltype, particip_mismatch_pos, pos))

            # Make sure there's exactly one headword template.
            if len(infl_headword_templates) > 1:
              pagemsg("WARNING: Found multiple inflection headword templates for %s; taking no action"
                  % (infltype))
              break

            # We found both templates and their heads matched; inflection
            # entry is probably already present. For verb forms, however,
            # check all the parameters of the definitional template,
            # because there may be multiple definitional templates
            # corresponding to different inflections that have the same form
            # for the same lemma (e.g. يَكْتُنُو yaktubū is both subjunctive and
            # jussive, and يَكْتُبْنَ yaktubna is all 3 of indicative, subjunctive
            # and jussive).
            if defn_templates and infl_headword_templates:
              pagemsg("Exists and has Russian section and found %s already in it"
                  % (infltype))

              particip_mismatch_check()

              infl_headword_template, infl_headword_matching_param = \
                  infl_headword_templates[0]

              # For verb forms check for an exactly matching definitional
              # template; if not, insert one at end of definition.
              if is_verb_part:
                def compare_verb_part_defn_templates(code1, code2):
                  pagemsg("Comparing %s with %s" % (code1, code2))
                  def canonicalize_defn_template(code):
                    code = reorder_shadda(code)
                    code = re.sub(r"\[\[.*?\]\]", "", code)
                    code = re.sub(r"\|gloss=[^|}]*", "", code)
                    code = re.sub(r"\|lang=ar", "", code)
                    return code
                  return (canonicalize_defn_template(code1) ==
                      canonicalize_defn_template(code2))
                found_exact_matching = False
                for d_t in defn_templates:
                  if compare_verb_part_defn_templates(unicode(d_t),
                      new_defn_template):
                    pagemsg("Found exact-matching definitional template for %s; taking no action"
                        % (infltype))
                    found_exact_matching = True
                  else:
                    pagemsg("Found non-matching definitional template for %s: %s"
                        % (infltype, unicode(d_t)))

                if verb_part_inserted_defn:
                  # If we already inserted an entry or found an exact-matching
                  # entry, check for duplicate entries. Currently we combine
                  # entries with the same inflection and conjugational form
                  # and separate lemmas, but previously created separate
                  # entries. We will add the new definition to the existing
                  # section but need to check for the previously added separate
                  # sections.
                  if found_exact_matching and len(defn_templates) == 1:
                    pagemsg("Found duplicate definition, deleting")
                    subsections[j - 1] = ""
                    subsections[j] = ""
                    sections[i] = ''.join(subsections)
                    notes.append("delete duplicate definition for %s %s, form %s"
                        % (infltype, inflection, verb_part_form))
                elif not found_exact_matching:
                  subsections[j] = unicode(parsed)
                  if subsections[j][-1] != '\n':
                    subsections[j] += '\n'
                  subsections[j] = re.sub(r"^(.*\n#[^\n]*\n)",
                      r"\1# %s\n" % new_defn_template, subsections[j], 1, re.S)
                  sections[i] = ''.join(subsections)
                  pagemsg("Adding new definitional template to existing defn for pos = %s" % (pos))
                  comment = "Add new definitional template to existing defn: %s %s, %s %s, pos=%s" % (
                      infltype, inflection, lemmatype, lemma, pos)

                # Don't break, so we can check for duplicate entries.
                # We set need_new_entry to false so we won't insert a new
                # one down below.
                verb_part_inserted_defn = True
                need_new_entry = False

              # Else, not verb form. Remove i3rab from existing headword and
              # definitional template, and maybe update the template heads
              # with better-vocalized versions.
              else:
                if len(defn_templates) > 1:
                  pagemsg("WARNING: Found multiple definitional templates for %s; taking no action"
                      % (infltype))
                  break
                defn_template = defn_templates[0]

                #### Rest of this code primarily for plurals and feminines,
                #### which may be partly vocalized and may have existing i3rab.
                #### For verbal nouns and participles, we require exact match
                #### so conditions like 'len(inflection) > len(existing_infl)'
                #### won't apply, and there generally isn't existing i3rab.
                
                # Check for i3rab in existing infl and remove it if so.
                existing_infl = \
                    check_maybe_remove_i3rab(infl_headword_template,
                        infl_headword_matching_param, infltype)

                # Check for i3rab in existing lemma and remove it if so
                existing_lemma = \
                    check_maybe_remove_i3rab(defn_template, "1", lemmatype)

                # Replace existing infl with new one
                if len(inflection) > len(existing_infl):
                  pagemsg("Updating existing %s %s with %s" %
                      (infltemp, existing_infl, inflection))
                  infl_headword_template.add(infl_headword_matching_param,
                    inflection)
                  if infltr:
                    trparam = "tr" if infl_headword_matching_param == "1" \
                        else infl_headword_matching_param.replace("head", "tr")
                    infl_headword_template.add(trparam, infltr)

                # Replace existing lemma with new one
                if len(lemma) > len(existing_lemma):
                  pagemsg("Updating existing '%s' %s with %s" %
                      (deftemp, existing_lemma, lemma))
                  defn_template.add("1", lemma)
                  if lemmatr:
                    defn_template.add("tr", lemmatr)

                #### End of code primarily for plurals and feminines.

                subsections[j] = unicode(parsed)
                sections[i] = ''.join(subsections)
                comment = "Update Russian with better vocalized versions: %s %s, %s %s, pos=%s" % (
                    infltype, inflection, lemmatype, lemma, pos)
                break

            # At this point, didn't find either headword or definitional
            # template, or both.
            elif vn_or_participle:
              # Insert {{ar-verbal noun of}} (or equivalent for participles).
              # Return comment (can't set it inside of fn).
              def insert_vn_defn():
                subsections[j] = unicode(parsed)
                subsections[j] = re.sub("^#",
                    "# %s\n#" % new_defn_template,
                    subsections[j], 1, re.M)
                sections[i] = ''.join(subsections)
                pagemsg("Insert existing defn with {{%s}} at beginning" % (
                    deftemp))
                return "Insert existing defn with {{%s}} at beginning: %s %s, %s %s" % (
                    deftemp, infltype, inflection, lemmatype, lemma)

              # If verb or participle, see if we found inflection headword
              # template at least. If so, add definition to beginning as
              # {{ar-verbal noun of}} (or equivalent for participles).
              if infl_headword_templates:
                infl_headword_template, infl_headword_matching_param = \
                    infl_headword_templates[0]

                # Check for i3rab in existing infl and remove it if so
                check_maybe_remove_i3rab(infl_headword_template,
                    infl_headword_matching_param, infltype)

                # Now actually add {{ar-verbal noun of}} (or equivalent
                # for participles).
                comment = insert_vn_defn()
                break

              elif is_participle:
                # Couldn't find headword template; if we're a participle,
                # see if there's a generic noun or adjective template
                # with the same head.
                for other_template in ["ar-noun", "ar-adj"]:
                  other_headword_templates = [
                      t for t in parsed.filter_templates()
                      if t.name == other_template and template_head_matches(t, inflection)]
                  if other_headword_templates:
                      pagemsg("WARNING: Found %s matching %s" %
                          (other_template, infltype))
                      # FIXME: Should we break here? Should we insert
                      # a participle defn?

            # At this point, didn't find either headword or definitional
            # template, or both, and not vn or participle. If we found
            # headword template, insert new definition in same section.
            elif infl_headword_templates:
              # Previously, when looking for a matching headword template,
              # we may not have required the vowels to match exactly
              # (e.g. when creating plurals). But now we want to make sure
              # they do, or we will put the new definition under a wrong
              # headword.
              infl_headword_template, infl_headword_matching_param = \
                  infl_headword_templates[0]
              if compare_param(infl_headword_template, infl_headword_matching_param, inflection, require_exact_match=True):
                # Also make sure manual translit matches
                trparam = "tr" if infl_headword_matching_param == "1" \
                    else infl_headword_matching_param.replace("head", "tr")
                existing_tr = getparam(infl_headword_template, trparam)
                # infltr may be None and existing_tr may be "", but
                # they should match
                if (infltr or None) == (existing_tr or None):
                  subsections[j] = unicode(parsed)
                  if subsections[j][-1] != '\n':
                    subsections[j] += '\n'
                  subsections[j] = re.sub(r"^(.*\n#[^\n]*\n)",
                      r"\1# %s\n" % new_defn_template, subsections[j], 1, re.S)
                  sections[i] = ''.join(subsections)
                  pagemsg("Adding new definitional template to existing defn for pos = %s" % (pos))
                  comment = "Add new definitional template to existing defn: %s %s, %s %s, pos=%s" % (
                      infltype, inflection, lemmatype, lemma, pos)
                  break

        # else of for loop over subsections, i.e. no break out of loop
        else:
          if not need_new_entry:
            break
          # At this point we couldn't find an existing subsection with
          # matching POS and appropriate headword template whose head matches
          # the the inflected form.

          # If verb part, try to find an existing verb section corresponding
          # to the same verb or another verb of the same conjugation form
          # (either the lemma of the verb or another non-lemma form).
          # When looking at the lemma of the verb, make sure both the
          # conjugation form and the consonants match so we don't end up
          # e.g. matching non-past yasurr (from sarra) with yasara, but
          # we do match up forms from faʿala and faʿila.
          # Insert after the last such one.
          if is_verb_part:
            insert_at = None
            for j in xrange(len(subsections)):
              if j > 0 and (j % 2) == 0:
                if re.match("^===+Verb===+", subsections[j - 1]):
                  parsed = blib.parse_text(subsections[j])
                  for t in parsed.filter_templates():
                    if (t.name == deftemp and compare_param(t, "1", lemma) or
                        t.name == infltemp and (not t.has("2") or compare_param(t, "2", verb_part_form)) or
                        t.name == "ar-verb" and re.sub("-.*$", "", getparam(t, "1")) == verb_part_form and remove_diacritics(get_dicform(page, t)) == remove_diacritics(lemma)):
                      insert_at = j + 1
            if insert_at:
              pagemsg("Found section to insert verb part after: [[%s]]" %
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

              pagemsg("Inserting after verb section for same lemma")
              comment = "Insert entry for %s %s of %s after verb section for same lemma" % (
                infltype, inflection, lemma)
              subsections[insert_at - 1] = ensure_two_trailing_nl(
                  subsections[insert_at - 1])
              if indentlevel == 3:
                subsections[insert_at:insert_at] = [newpos + "\n"]
              else:
                assert(indentlevel == 4)
                subsections[insert_at:insert_at] = [newposl4 + "\n"]
              sections[i] = ''.join(subsections)
              sort_verb_part_sections()
              break

          # If participle, try to find an existing noun or adjective with the
          # same lemma to insert before. Insert before the first such one.
          if is_participle:
            insert_at = None
            for j in xrange(len(subsections)):
              if j > 0 and (j % 2) == 0:
                if re.match("^===+(Noun|Adjective)===+", subsections[j - 1]):
                  parsed = blib.parse_text(subsections[j])
                  for t in parsed.filter_templates():
                    if (t.name in ["ar-noun", "ar-adj"] and
                        template_head_matches(t, inflection) and insert_at is None):
                      insert_at = j - 1

            if insert_at is not None:
              pagemsg("Found section to insert participle before: [[%s]]" %
                  subsections[insert_at + 1])

              comment = "Insert entry for %s %s of %s before section for same lemma" % (
                infltype, inflection, lemma)
              if insert_at > 0:
                subsections[insert_at - 1] = ensure_two_trailing_nl(
                    subsections[insert_at - 1])
              subsections[insert_at:insert_at] = [newpos + "\n"]
              sections[i] = ''.join(subsections)
              break

          pagemsg("Exists and has Russian section, appending to end of section")
          # FIXME! Conceivably instead of inserting at end we should insert
          # next to any existing ===Noun=== (or corresponding POS, whatever
          # it is), in particular after the last one. However, this makes less
          # sense when we create separate etymologies, as we do. Conceivably
          # this would mean inserting after the last etymology section
          # containing an entry of the same part of speech.
          #
          # (Perhaps for now we should just skip creating entries if we find
          # an existing Russian entry?)
          if "\n===Etymology 1===\n" in sections[i]:
            j = 2
            while ("\n===Etymology %s===\n" % j) in sections[i]:
              j += 1
            pagemsg("Found multiple etymologies, adding new section \"Etymology %s\"" % (j))
            comment = "Append entry (Etymology %s) for %s %s of %s, pos=%s in existing Russian section" % (
              j, infltype, inflection, lemma, pos)
            sections[i] = ensure_two_trailing_nl(sections[i])
            sections[i] += "===Etymology %s===\n" % j + entrytextl4
          else:
            pagemsg("Wrapping existing text in \"Etymology 1\" and adding \"Etymology 2\"")
            comment = "Wrap existing Russian section in Etymology 1, append entry (Etymology 2) for %s %s of %s, pos=%s" % (
                infltype, inflection, lemma, pos)
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
            infltype, inflection, lemma, pos, m.group(1))
        sections[i:i] = [newsection, "\n----\n\n"]
        break

    else: # else of for loop over sections, i.e. no break out of loop
      pagemsg("Exists; adding section to end")
      comment = "Create Russian section and entry for %s %s of %s, pos=%s; append at end" % (
          infltype, inflection, lemma, pos)

      sections[-1] = ensure_two_trailing_nl(sections[-1])
      sections += ["----\n\n", newsection]

    # End of loop over sections in existing page; rejoin sections
    newtext = pagehead + ''.join(sections) + pagetail

    # If participle, remove [[Category:Russian participles]]
    if is_participle:
      oldnewtext = newtext
      newtext = re.sub(r"\n+\[\[Category:Russian participles]]\n+", r"\n\n",
          newtext)
      if newtext != oldnewtext:
        pagemsg("Removed [[Category:Russian participles]]")

    if page.text == newtext:
      pagemsg("No change in text")
    elif verbose:
      pagemsg("Replacing [[%s]] with [[%s]]" % (page.text, newtext),
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
    assert(comment)
    pagemsg("comment = %s" % comment, simple = True)
    if save:
      page.save(comment = comment)

def create_noun_plural(save, index, inflection, infltr, lemma, lemmatr, pos):
  create_inflection_entry(save, index, inflection, infltr, lemma, lemmatr, pos,
      "plural", "singular", "ar-noun-pl", "", "plural of", "|lang=ar")

def create_adj_plural(save, index, inflection, infltr, lemma, lemmatr, pos):
  create_inflection_entry(save, index, inflection, infltr, lemma, lemmatr, pos,
      "plural", "singular", "ar-adj-pl", "", "masculine plural of", "|lang=ar")

def create_noun_feminine_entry(save, index, inflection, infltr, lemma, lemmatr,
    pos):
  create_inflection_entry(save, index, inflection, infltr, lemma, lemmatr, pos,
      "feminine", "masculine", None, # FIXME
      "", "feminine of", "|lang=ar")

def create_adj_feminine_entry(save, index, inflection, infltr, lemma, lemmatr,
    pos):
  create_inflection_entry(save, index, inflection, infltr, lemma, lemmatr, pos,
      "feminine", "masculine", "ar-adj-fem", "", "feminine of", "|lang=ar")

def create_inflection_entries(save, pos, tempname, startFrom, upTo, createfn,
    param):
  for cat in [u"Russian %ss" % pos.lower()]:
    for page, index in blib.cat_articles(cat, startFrom, upTo):
      for template in blib.parse(page).filter_templates():
        if template.name == tempname:
          lemma = getparam(template, "1")
          lemmatr = getparam(template, "tr")
          # Handle blank head; use page title
          if lemma == "":
            lemma = page.title()
            msg("Page %s: blank head in template %s (tr=%s)" % (
              lemma, tempname, lemmatr))
          infl = getparam(template, param)
          infltr = getparam(template, param + "tr")
          if infl:
            createfn(save, index, infl, infltr, lemma, lemmatr, pos)
          i = 2
          while infl:
            infl = getparam(template, param + str(i))
            infltr = getparam(template, param + str(i) + "tr")
            if infl:
              otherhead = getparam(template, "head" + str(i))
              otherheadtr = getparam(template, "tr" + str(i))
              if otherhead:
                msg("Page %s: Using head%s %s (tr=%s) as lemma for %s (tr=%s)" % (
                  lemma, i, otherhead, otherheadtr, infl, infltr))
                createfn(save, index, infl, infltr, otherhead, otherheadtr, pos)
              else:
                createfn(save, index, infl, infltr, lemma, lemmatr, pos)
            i += 1

def create_plurals(save, pos, tempname, startFrom, upTo):
  return create_inflection_entries(save, pos, tempname, startFrom, upTo,
      create_noun_plural if pos == "Noun" else create_adj_plural, "pl")

def create_feminines(save, pos, tempname, startFrom, upTo):
  return create_inflection_entries(save, pos, tempname, startFrom, upTo,
      create_noun_feminine if pos == "Noun" else create_adj_feminine, "f")

def expand_template(page, text):
  # Make an expand-template call to expand the template text.
  # The code here is based on the expand_text() function of the Page object.
  # FIXME: Use site.expand_text(text, title=page.title(withSection=False))
  req = pywikibot.data.api.Request(action="expandtemplates",
      text = text,
      title = page.title(withSection=False),
      site = page.site,
      prop = "wikitext" # "*"
      )
  #return req.submit()["expandtemplates"]["*"]
  return req.submit()["expandtemplates"]["wikitext"]

def get_part_prop(page, template, prefix):
  # Make an expand-template call to convert the conjugation template to
  # the desired form or property.
  return expand_template(page,
      re.sub("\{\{ar-(conj|verb)\|", "{{%s|" % prefix, unicode(template)))

def get_dicform(page, template):
  return get_part_prop(page, template, "ar-past3sm")

def get_passive(page, template):
  return get_part_prop(page, template, "ar-verb-prop|passive")

# For a given value of passive= (yes, impers, no, only, only-impers), does
# the verb have an active form?
def has_active_form(passive):
  assert(passive in ["yes", "impers", "no", "only", "only-impers"])
  return passive in ["yes", "impers", "no"]

# For a given value of passive= (yes, impers, no, only, only-impers) and a
# given person/number/gender combination, does the verb have a passive form?
# Supply None for PERS for non-finite verb parts (participles).
def has_passive_form(passive, pers):
  assert(passive in ["yes", "impers", "no", "only", "only-impers"])
  # If no person or it's 3sm, then impersonal passives have it. Otherwise no.
  if not pers or pers == "3sm":
    return passive != "no"
  return passive == "yes" or passive =="only"

# Create a verbal noun entry, either creating a new page or adding to an
# existing page. Do nothing if entry is already present. SAVE, INDEX are as in
# create_inflection_entry(). VN is the vocalized verbal noun; VERBPAGE is the
# Page object representing the dictionary-form verb of this verbal noun;
# TEMPLATE is the conjugation template for the verb, i.e. {{ar-conj|...}};
# UNCERTAIN is true if the verbal noun is uncertain (indicated with a ? at
# the end of the vn=... parameter in the conjugation template).
def create_verbal_noun(save, index, vn, form, page, template, uncertain):
  dicform = get_dicform(page, template)

  gender = get_vn_gender(vn, form)
  if gender == "?":
    msg("Page %s %s: WARNING: Unable to determine gender: verbal noun %s, dictionary form %s"
        % (index, remove_diacritics(vn), vn, dicform))
    genderparam = ""
  else:
    genderparam = "|%s" % gender

  defparam = "|form=%s%s" % (form, uncertain and "|uncertain=yes" or "")
  create_inflection_entry(save, index, vn, None, dicform, None, "Noun",
    "verbal noun", "dictionary form", "ar-noun", genderparam,
    "ar-verbal noun of", defparam)

def create_verbal_nouns(save, startFrom, upTo):
  for page, index in blib.cat_articles("Russian verbs", startFrom, upTo):
    for template in blib.parse(page).filter_templates():
      if template.name == "ar-conj":
        form = re.sub("-.*$", "", getparam(template, "1"))
        vnvalue = getparam(template, "vn")
        uncertain = False
        if vnvalue.endswith("?"):
          vnvalue = vnvalue[:-1]
          uncertain = True
        if not vnvalue:
          if form != "I":
            # Augmented verb. Fetch auto-generated verbal noun(s).
            vnvalue = get_part_prop(page, template, "ar-verb-part-all|vn")
          else:
            continue
        vns = re.split(u"[,،]", vnvalue)
        for vn in vns:
          create_verbal_noun(save, index, vn, form, page, template, uncertain)

def create_participle(save, index, part, page, template, actpass, apshort):
  dicform = get_dicform(page, template)

  # Retrieve form, eliminate any weakness value (e.g. "I" from "I-sound")
  form = re.sub("-.*$", "", getparam(template, "1"))
  create_inflection_entry(save, index, part, None, dicform, None, "Participle",
    "%s participle" % actpass, "dictionary form",
    "ar-%s-participle" % apshort, "|" + form,
    "%s participle of" % actpass, "|lang=ar")

def create_participles(save, startFrom, upTo):
  for page, index in blib.cat_articles("Russian verbs", startFrom, upTo):
    for template in blib.parse(page).filter_templates():
      if template.name == "ar-conj":
        passive = get_passive(page, template)
        if has_active_form(passive):
          apvalue = get_part_prop(page, template, "ar-verb-part-all|ap")
          if apvalue:
            aps = re.split(",", apvalue)
            for ap in aps:
              create_participle(save, index, ap, page, template, "active",
                  "act")
        if has_passive_form(passive, None):
          ppvalue = get_part_prop(page, template, "ar-verb-part-all|pp")
          if ppvalue:
            pps = re.split(",", ppvalue)
            for pp in pps:
              create_participle(save, index, pp, page, template, "passive",
                  "pass")

adj_form_inflection_list = [
  ["nom_m": ("nom", "m", "s")],
  ["nom_f": ("nom", "f", "s")],
  ["nom_n": ("nom", "n", "s")],
  ["nom_p": ("nom", "p")],
  ["nom_mp": ("nom", "m", "p")],
  ["gen_m": ("gen", "m", "s")],
  ["gen_f": ("gen", "f", "s")],
  ["gen_p": ("gen", "p")],
  ["dat_m": ("dat", "m", "s")],
  ["dat_f": ("dat", "f", "s")],
  ["dat_p": ("dat", "p")],
  ["acc_f": ("acc", "f", "s")],
  ["acc_n": ("acc", "n", "s")],
  ["ins_m": ("ins", "m", "s")],
  ["ins_f": ("ins", "f", "s")],
  ["ins_p": ("ins", "p")],
  ["pre_m": ("pre", "m", "s")],
  ["pre_f": ("pre", "f", "s")],
  ["pre_p": ("pre", "p")],
  ["short_m": ("short", "m", "s")],
  ["short_f": ("short", "f", "s")],
  ["short_n": ("short", "n", "s")],
  ["short_p": ("short", "p")]
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
  ["nom_sg": ("nom", "s")],
  ["gen_sg": ("gen", "s")],
  ["dat_sg": ("dat", "s")],
  ["acc_sg": ("acc", "s")],
  ["ins_sg": ("ins", "s")],
  ["pre_sg": ("pre", "s")],
  ["nom_pl": ("nom", "p")],
  ["gen_pl": ("gen", "p")],
  ["dat_pl": ("dat", "p")],
  ["acc_pl": ("acc", "p")],
  ["ins_pl": ("ins", "p")],
  ["pre_pl": ("pre", "p")],
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

# Create a single verb form. SAVE, INDEX are as in create_inflection_entry().
# PAGE is the page of the lemma. DICFORM is the accented infinitive.
# of the lemma, PASSIVE is the value of the 'passive' property of the lemma.
# VOICE is either "active" or "passive", and PERSON and TENSE
# indicate the particular person/number/gender/tense/mood combination, using
# the codes passed to {{ar-verb-part-all|...}}. We refuse to do combinations
# not compatible with the value of PASSIVE, and we refuse to do the
# dictionary form (3sm-perf, or 3sm-ps-perf for passive-only verbs).
# We assume that impossible parts (passive and non-2nd-person imperatives)
# have already been filtered.
def create_verb_form(save, index, page, inf, formname, forms, infls):
  # Refuse to do the dictionary form.
  if formname == "infinitive":
    return
  if not forms:
    return
  infl_person = persons_infl_entry[person]
  infl_tense = tenses_infl_entry[tense] % voices_infl_entry[voice]
  partid = (voice == "active" and "%s-%s" % (person, tense) or
      "%s-ps-%s" % (person, tense))
  # Retrieve form, eliminate any weakness value (e.g. "I" from "I-sound")
  form = re.sub("-.*$", "", getparam(template, "1"))
  value = get_part_prop(page, template, "ar-verb-part-all|%s" % partid)
  if value:
    parts = re.split(",", value)
    for part in parts:
      create_inflection_entry(save, index, part, None, dicform, None, "Verb",
        "verb part %s" % partid, "dictionary form",
        "ar-verb-form", "|" + form,
        "inflection of", "||lang=ar|%s|%s" % (infl_person, infl_tense))

# Parse a noun/verb/adv form spec, one or more forms separated by commas,
# possibly including aliases.
def parse_form_spec(formspec, infl_dict, aliases):
  def check(variable, value, possible):
    if not value in possible:
      raise ValueError("Invalid value '%s' for %s, expected one of %s" % (
        value, variable, '/'.join(possible)))

  forms = []
  for form in re.split(",", formspec):
    if form in aliases:
      for f in aliases[form]:
        if form not in forms:
          forms.append(form)
    elif form in infl_dict:
      if form not in forms:
        forms.append(form)
    else:
      raise ValueError("Invalid value '%s'" % form)

  infls = []
  for form in forms:
    infls.append([form, infl_dict[form]])
  return infls

# Create required verb parts for all verbs. PART specifies the part(s) to do.
# If "all", do all parts (other than 3sm-perf, the dictionary form);
# otherwise, only do the specified part(s).
# SAVE is as in create_inflection_entry(). STARTFROM and UPTO, if not None,
# delimit the range of pages to process (inclusive on both ends).
def create_verb_forms(save, startFrom, upTo, formspec):
  forms_desired = parse_form_spec(formspec, verb_form_inflection_dict,
      verb_form_aliases)
  for index, page in blib.cat_articles("Russian verbs", startFrom, upTo):
    def pagemsg(txt):
      msg("Page %s %s: %s" % (index, page, txt))
    def expand_text(tempcall):
      return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

    for t in blib.parse(page).filter_templates():
      tname = unicode(t.name)
      if unicode(t.name).startswith("ru-conj"):
        verbtype = re.sub(r"^ru-conj-", "", tname)
        params = re.sub(r"^\{\{ru-conj-.*?\|(.*)\}\}$", r"\1", unicode(t))
        result = blib.expand_text("{{ru-generate-verb-forms|type=%s|%s}}" %
            (verbtype, params))
        if not result:
          pagemsg("WARNING: Error generating verb forms, skipping")
          continue
        args = ru.split_generate_args(result)
        dicform = args["infinitive"]
        for form, infls in forms_desired:
          if form in args:
            create_verb_form(save, index, page, dicform, form, args[form], infls)

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
startFrom, upTo = blib.parse_start_end(params.start, params.end)

if params.adj_form:
  create_adj_forms(params.save, startFrom, upTo, params.adj_form)
if params.noun_form:
  create_noun_forms(params.save, startFrom, upTo, params.noun_form)
if params.verb_form:
  create_verb_forms(params.save, startFrom, upTo, params.verb_forms)

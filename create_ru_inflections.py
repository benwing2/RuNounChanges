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
# (may be empty). FIXME: If either the lemma specifies manual translit or
# TR is given, we should consider transliterating the other one in case
# of redundant manual translit.
def lemma_matches(lemma, ru, tr):
  if tr:
    ru = ru + "//" + tr
  for lem in re.split(",", lemma):
    if ru == lem:
      return True
  return False

# Create or insert a section describing a given inflection of a given lemma.
# INFLECTION is the vocalized inflectional form (e.g. the
# plural, feminine, verbal noun, participle, etc.); LEMMA is the vocalized
# lemma (e.g. the singular, masculine or dictionary form of a verb); INFLTR
# and LEMMATR are the associated manual transliterations (if any). POS is the
# part of speech of the word (capitalized, e.g. "Noun"). Only save the changed
# page if SAVE is true. INDEX is the numeric index of the lemma page, for
# ID purposes and to aid restarting. INFLTYPE is e.g. "adj form nom_m",
# and is used in messages; both POS and INFLTYPE are used in special-case
# code that is appropriate to only certain inflectional types. LEMMATYPE is
# e.g. "infinitive" or "masculine singular" and is used in messages.
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
def create_inflection_entry(save, index, inflection, infltr, lemma, lemmatr,
    pos, infltype, lemmatype, infltemp, infltemp_param, deftemp,
    deftemp_param, deftemp_needs_lang=True, entrytext=None):

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
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagename, pagemsg, verbose)

  is_participle = "participle" in infltype
  uses_inflection_of = infltemp == "inflection of"

  if inflection == "-":
    pagemsg("Not creating %s entry - for %s %s%s" % (
      infltype, lemmatype, lemma, " (%s)" % lemmatr if lemmatr else ""))
    return

  # Prepare to create page
  pagemsg("Creating entry")
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

            # Find the inflection headword (e.g. 'ru-noun form' or
            # 'head|ru|verb form') and definitional (typically 'inflection of')
            # templates.

            # First, for each template, return a tuple of
            # (template, param, matches), where MATCHES is true if any head
            # matches FORM and PARAM is the (first) matching head param.
            def template_head_match_info(template, form):
              # Look at all heads
              firstparam = "head" if infltemp.startswith("head|") else "1"
              if compare_param(template, firstparam, form):
                return (template, firstparam, True)
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

            # True if the inflection codes in template T (an 'inflection of'
            # template) exactly match the inflections given in INFLS (in
            # any order)
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
              union = inflset | paramset
              if union == paramset:
                pagemsg("WARNING: Found actual inflection %s whose codes are a superset of intended codes %s" % (
                  unicode(t), "|".join(infls)))
              elif union == inflset:
                pagemsg("WARNING: Found actual inflection %s whose codes are a subset of intended codes %s" % (
                  unicode(t), "|".join(infls)))
              return False

            # Now get a list of (TEMPLATE, PARAM) for all matching templates,
            # where PARAM is the matching head param, as above.
            infl_headword_templates = [(t, param)
                for t, param, matches in head_matches_tuples
                if unicode(t.name) == infltemp and matches]
            defn_templates = [t for t in parsed.filter_templates()
                if unicode(t.name) == deftemp and compare_param(t, "1", lemma)
                and (not deftemp_needs_lang or compare_param(t, "lang", "ru"))
                and (not uses_inflection_of or compare_inflections(t, deftemp_param))]

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
            # entry is already present.
            if defn_templates and infl_headword_templates:
              pagemsg("Exists and has Russian section and found %s already in it"
                  % (infltype))

              particip_mismatch_check()
              break

            # At this point, didn't find either headword or definitional
            # template, or both. If we found headword template, insert
            # new definition in same section.
            elif infl_headword_templates:
              # Previously, when looking for a matching headword template,
              # we may not have required the vowels to match exactly
              # (e.g. when creating plurals). But now we want to make sure
              # they do, or we will put the new definition under a wrong
              # headword.
              infl_headword_template, infl_headword_matching_param = \
                  infl_headword_templates[0]
              # Also make sure manual translit matches
              trparam = "tr" if infl_headword_matching_param in ["1", "head"] \
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

          # If participle, try to find an existing noun or adjective with the
          # same lemma to insert before. Insert before the first such one.
          if is_participle:
            insert_at = None
            for j in xrange(len(subsections)):
              if j > 0 and (j % 2) == 0:
                if re.match("^===+(Noun|Adjective)===+", subsections[j - 1]):
                  parsed = blib.parse_text(subsections[j])
                  for t in parsed.filter_templates():
                    if (t.name in ["ru-adj"] and
                        template_head_matches(t, inflection) and insert_at is None):
                      insert_at = j - 1
                    if (t.name in ["ru-noun+", "ru-proper noun+"] and insert_at is None):
                      lemma = fetch_noun_lemma(template, expand_text)
                      if lemma is None:
                        pagemsg("WARNING: Error generating noun forms")
                      elif lemma_matches(lemma, inflection, infltr):
                        insert_at = j - 1

            if insert_at is not None:
              pagemsg("Found section to insert participle before: [[%s]]" %
                  subsections[insert_at + 1])

              comment = "Insert entry for %s %s of %s before section for same lemma" % (
                infltype, inflection, lemma)
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

# Parse a noun/verb/adv form spec, one or more forms separated by commas,
# possibly including aliases.
def parse_form_spec(formspec, infl_dict, aliases):
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

def split_ru_tr(form):
  if "//" in form:
    rutr = re.split("//", form)
    assert len(rutr) == 2
    ru, tr = rutr
    return (ru, tr)
  else:
    return (form, None)

# Create required forms for all nouns/verbs/adjectives.
# SAVE is as in create_inflection_entry(). STARTFROM and UPTO, if not None,
# delimit the range of pages to process (inclusive on both ends).
#
# FORMSPEC specifies the form(s) to do, a comma-separated list of form codes,
# possibly including aliases (e.g. 'all'). FORM_INFLECTION_DICT is a dictionary
# mapping possible form codes to the corresponding inflection codes in
# {{inflection of|...}}. FORM_ALIASES is a dictionary mapping aliases to
# form codes.
#
# POS specifies the part of speech (lowercase, singular, e.g. "verb").
# INFLTEMP specifies the inflection template name (e.g. "head|ru|verb form" or
# "ru-noun form"). DICFORM_CODE specifies the form code for the dictionary
# form (e.g. "infinitive", "nom_m" or "nom_sg").
#
# IS_INFLECTION_TEMPLATE is a function that is passed one argument, a template,
# and should indicate if it's an inflection template (e.g. 'ru-conj-2a' for
# verbs). CREATE_FORM_GENERATOR is a function that's passed one argument,
# a template, and should return a template (a string) that can be expanded to
# yield a set of forms, identified by form codes.
def create_forms(save, startFrom, upTo, formspec,
    form_inflection_dict, form_aliases, pos, infltemp, dicform_code,
    is_inflection_template, create_form_generator):
  forms_desired = parse_form_spec(formspec, form_inflection_dict,
      form_aliases)
  for index, page in blib.cat_articles("Russian %ss" % pos, startFrom, upTo):
    def pagemsg(txt):
      msg("Page %s %s: %s" % (index, page, txt))
    def expand_text(tempcall):
      return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

    for t in blib.parse(page).filter_templates():
      tname = unicode(t.name)
      if is_inflection_template(t):
        result = blib.expand_text(create_form_generator(t))
        if not result:
          pagemsg("WARNING: Error generating %s forms, skipping" % pos)
          continue
        args = ru.split_generate_args(result)
        dicforms = args[dicform_code]
        for dicform in re.split(",", dicforms):
          for form, infls in forms_desired:
            if form != dicform_code and form in args and args[form]:
              dicformru, dicformtr = split_ru_tr(dicform)
              for formval in re.split(",", args[form]):
                formvalru, formvaltr = split_ru_tr(formval)
                create_inflection_entry(save, index, formvalru, formvaltr,
                  dicformru, dicformtr, pos.capitalize(),
                  "%s form %s" % (pos, formname), "dictionary form",
                  infltemp, "",
                  "inflection of", infls)

def create_verb_generator(t):
  verbtype = re.sub(r"^ru-conj-", "", unicode(t.name))
  params = re.sub(r"^\{\{ru-conj-.*?\|(.*)\}\}$", r"\1", unicode(t))
  return "{{ru-generate-verb-forms|type=%s|%s}}" % (verbtype, params)

def create_verb_forms(save, startFrom, upTo, formspec):
  create_forms(save, startFrom, upTo, formspec,
      verb_form_inflection_dict, verb_form_aliases,
      "verb", "head|ru|verb form", "infinitive",
      lambda t:unicode(t.name).startswith("ru-conj"),
      create_verb_generator)

def create_adj_forms(save, startFrom, upTo, formspec):
  create_forms(save, startFrom, upTo, formspec,
      adj_form_inflection_dict, adj_form_aliases,
      "adjective", "head|ru|adjective form", "nom_m",
      lambda t:unicode(t.name) == "ru-decl-adj",
      lambda t:re.sub(r"^\{\{ru-decl-adj", "{{ru-generate-adj-forms", unicode(t)))

def create_noun_forms(save, startFrom, upTo, formspec):
  create_forms(save, startFrom, upTo, formspec,
      noun_form_inflection_dict, noun_form_aliases,
      "noun", "ru-noun form", "nom_sg",
      lambda t:unicode(t.name) == "ru-noun-table",
      lambda t:re.sub(r"^\{\{ru-noun-table", "{{ru-generate-noun-forms", unicode(t)))

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

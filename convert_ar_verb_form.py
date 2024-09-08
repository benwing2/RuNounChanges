#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, json

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import arabiclib

raw_category_re = r"\[\[\s*(?:[Cc][Aa][Tt][Ee][Gg][Oo][Rr][Yy]|[Cc][Aa][Tt])\s*:[^\[\]\n]+\]\]"
allowed_lemma_pairs = [
  set(["حي", "حيي"]),
  set(["استحيا", "استحى"]),
  set(["توفى", "توفي"]), # active-passive equivalents
]

conj_table = {}
def lookup_conjugation(verb_form, lemma, pagemsg, errandpagemsg):
  cached = False
  if lemma in conj_table:
    cached = True
    conjs_by_form, warning = conj_table[lemma]
    if warning:
      pagemsg("%s: No conjugation because '%s' (cached)" % (lemma, warning))
      return None
  else:
    cached = False
    conjpage = pywikibot.Page(site, lemma)
    conjtext = blib.safe_page_text(conjpage, errandpagemsg)
    warning = None
    if not conjtext:
      if blib.safe_page_exists(conjpage, errandpagemsg):
        warning = "WARNING: Lemma page exists but is blank"
      else:
        warning = "WARNING: Lemma page doesn't exist"
      conjs_by_form = None
    else:
      parsed = blib.parse_text(conjtext)
      conjs_by_form = {}
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn == "ar-conj":
          arg1 = getparam(t, "1")
          if re.search("^<.*>$", arg1):
            newconj = arg1[1:-1]
          elif "<" in arg1 or "((" in arg1:
            warning = "WARNING: Conjugation has < or ((, can't parse: %s" % arg1
            break
          else:
            newconj = arg1
          arg_vform = re.sub("[./-].*$", "", newconj)
          new_conjs = conjs_by_form.get(arg_vform, [])
          new_conjs.append(newconj)
          if arg_vform in conjs_by_form:
            pagemsg("WARNING: Saw multiple form-%s conjugations for lemma %s, may need to manually annotate with definitions: %s"
                    % (arg_vform, lemma, ",".join(new_conjs)))
          conjs_by_form[arg_vform] = new_conjs
      if not warning:
        if not conjs_by_form:
          if re.search(r"==\s*Arabic\s*==", conjtext):
            warning = "WARNING: Lemma page exists and has an ==Arabic== section but has no conjugations"
          else:
            warning = "WARNING: Lemma page exists but does not have an ==Arabic== section"
          conjs_by_form = None
      else:
        pagemsg("%s: %s" % (lemma, warning))
        conjs_by_form = None
    assert warning and not conjs_by_form or not warning and conjs_by_form
    conj_table[lemma] = (conjs_by_form, warning)
    if not conjs_by_form:
      pagemsg("%s: No conjugation because '%s'" % (lemma, warning))
      return None
  cached_msg = " (cached)" if cached else ""
  if verb_form not in conjs_by_form:
    pagemsg("WARNING: %s: Didn't find conjugation for verb form %s%s" % (lemma, verb_form, cached_msg))
    return None
  conjs = conjs_by_form[verb_form]
  pagemsg("%s: Returning %s%s" % (lemma, ",".join("<%s>" % conj for conj in conjs), cached_msg))
  return conjs

def escape_newlines(text):
  return text.replace("\n", r"\n")

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  if blib.page_should_be_ignored(pagetitle):
    return

  def do_etymtext(etymtext, verb_form, unvocalized_lemmas, verb_header_level, vocalized_lemmas,
                  num_ar_verb_forms, ar_rootbox_calls, saw_nonlemma):
    ar_verb_form_parts = []
    ar_verb_form_occurrences_msg = "%s occurrence%s of {{ar-verb-form}}" % (
      num_ar_verb_forms, "s" if num_ar_verb_forms > 1 else "")
    voclemma_msg = "vocalized lemma%s %s" % ("s" if len(vocalized_lemmas) > 1 else "", ",".join(vocalized_lemmas))
    for unvocalized_lemma in unvocalized_lemmas:
      conjs = lookup_conjugation(verb_form, unvocalized_lemma, pagemsg, errandpagemsg)
      if not conjs:
        pagemsg("WARNING: Can't replace %s for verb form %s, %s" % (
          ar_verb_form_occurrences_msg, verb_form, voclemma_msg))
        return etymtext
      ar_verb_form_parts.append("+%s<%s>" % (unvocalized_lemma, verb_form))
    #def trim_conj_with_lemma(conj, unvocalized_lemma):
    #  segments = blib.parse_multi_delimiter_balanced_segment_run(conj, [("[", "]"), ("<", ">")])
    #  dot_separated_groups = blib.split_alternating_runs_and_strip_spaces(segments, r"\.")
    #  # Rejoin each dot-separated group into a single string, since we aren't actually going to do any parsing
    #  # of bracket-bounded textual runs; then filter out overrides for verbal nouns and participles.
    #  filtered_indicators = []
    #  for dot_separated_group in dot_separated_groups:
    #      indicator = "".join(dot_separated_group)
    #      # FIXME: Do we want to filter out any other indicators?
    #      if not re.search("^(vn|ap|pp):", indicator):
    #          filtered_indicators.append(indicator)
    #  return "%s<%s>" % (unvocalized_lemma, ".".join(filtered_indicators))
    # FIXME: Need to store all conjs from different unvocalized lemmas and process them.
    #trimmed_conjs_with_lemma = [trim_conj_with_lemma(conj) for conj in conjs]
    stuff_at_beginning = []
    if saw_nonlemma:
      stuff_at_beginning.append("{{nonlemma}}\n")
    ar_rootbox_calls = "".join(ar_rootbox_calls)
    if ar_rootbox_calls:
      ar_rootbox_calls += "\n"
    stuff_at_beginning.append(ar_rootbox_calls)
    stuff_at_beginning = "".join(stuff_at_beginning)
    if not ar_verb_form_parts:
      pagemsg("WARNING: Something wrong, would substitute empty parameter into {{ar-verb form}}")
      return etymtext
    ar_verb_form_call = "{{ar-verb form|%s}}" % "|".join(ar_verb_form_parts)
    equal_signs = "=" * verb_header_level
    newtext = "%s\n%sVerb%s\n%s\n\n" % (stuff_at_beginning, equal_signs, equal_signs, ar_verb_form_call)
    notes.append("replace %s for verb form %s, unvocalized lemma%s %s, %s with %s" % (
      ar_verb_form_occurrences_msg, verb_form, "s" if len(unvocalized_lemmas) > 1 else "", ",".join(unvocalized_lemmas),
      voclemma_msg, ar_verb_form_call))
    #pagemsg("Replaced <%s> with <%s>" % (escape_newlines(etymtext), escape_newlines(newtext)))
    return newtext

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Arabic", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  no_multi_etym_msg = None
  if "==Etymology" not in secbody:
    if "{{ar-verb-form|" not in secbody:
      return
    no_multi_etym_msg = "Saw {{ar-verb-form}} but not multiple Etymology sections"
    etym_sections = ["", "", secbody]
    verb_header_level = 3
  else:
    etym_sections = re.split("(^===[^=]+===\n)", secbody, 0, re.M)
    verb_header_level = 4
  for k in range(2, len(etym_sections), 2):
    etymtext = etym_sections[k]
    if "{{ar-verb-form|" not in etymtext:
      continue
    m = re.search(raw_category_re, etymtext)
    if m:
      pagemsg("WARNING: Saw raw category in {{ar-verb-form}} section, skipping: %s" % m.group(0))
      continue
    verb_form = None
    vocalized_lemmas = []
    unvocalized_lemmas = []
    parsed = blib.parse_text(etymtext)
    must_continue = False
    num_ar_verb_forms = 0
    ar_rootboxes = []
    saw_nonlemma = False
    for t in parsed.filter_templates():
      def getp(param):
        return getparam(t, param)
      def check_allowed_params(allow_fn):
        for param in t.params:
          pn = pname(param)
          if not allow_fn(pn):
            pagemsg("WARNING: Unrecognized param %s=%s: %s" % (pn, str(param.value), str(t)))
            return False
        return True
      tn = tname(t)
      if tn == "ar-verb-form":
        if not check_allowed_params(lambda pn: pn in ["1", "2"]):
          must_continue = True
          break
        vform = getp("2")
        if "<" in vform:
          pagemsg("WARNING: Saw angle bracket in {{ar-verb-form}}, skipping: %s" % str(t))
          must_continue = True
          break
        if verb_form and verb_form != vform:
          pagemsg("WARNING: Saw two different verb forms %s and %s in same etym section for {{ar-verb-form}}, skipping: %s"
                  % (verb_form, vform, str(t)))
          must_continue = True
          break
        verb_form = vform
        num_ar_verb_forms += 1
      elif tn in ["infl of", "inflection of"]:
        lang = getp("1")
        if lang != "ar":
          pagemsg("WARNING: Saw wrong language code in {{%s}}, skipping: %s" % (tname(t), lang, str(t)))
          must_continue = True
          break
        if not check_allowed_params(lambda pn: re.search("^[0-9]+$", pn)):
          must_continue = True
          break
        lemma = getp("2")
        if lemma not in vocalized_lemmas:
          vocalized_lemmas.append(lemma)
        unvoc_lemma = arabiclib.remove_diacritics(lemma)
        if unvocalized_lemmas and unvoc_lemma not in unvocalized_lemmas:
          all_lemmas = unvocalized_lemmas + [unvoc_lemma]
          if set(all_lemmas) in allowed_lemma_pairs:
            pagemsg("Saw lemma alternatives %s, allowing" % ",".join(all_lemmas))
            unvocalized_lemmas.append(unvoc_lemma)
            continue

          if verb_form == "I":
            m = re.search("^(.*)[ايى]$", unvoc_lemma)
            if m:
              stem = m.group(1)
              for current_unvoc_lemma in unvocalized_lemmas:
                if not re.search("^%s[ايى]$" % stem, current_unvoc_lemma):
                  break
              else: # no break
                pagemsg("Saw form I final-weak with different final vowels: current %s, new %s; allowing" % (
                  ",".join(unvocalized_lemmas), unvoc_lemma))
                unvocalized_lemmas.append(unvoc_lemma)
                continue

          if verb_form in ["III", "VI"]:
            if len(unvocalized_lemmas) > 1:
              pagemsg("WARNING: Form III/VI, already saw two or more unvocalized lemmas %s, can't process a third %s" %
                      (",".join(unvocalized_lemmas), unvoc_lemma))
              must_continue = True
              break
            unvocalized_lemma = unvocalized_lemmas[0]
            inner_continue = False
            for lemma1, lemma2, lemma1_is_current in [
              (unvocalized_lemma, unvoc_lemma, True),
              (unvoc_lemma, unvocalized_lemma, False),
            ]:
              m = re.search(r"ا(.)\1$", lemma1)
              if m:
                final_cons = m.group(1)
                m2 = re.search("ا%s$" % final_cons, lemma2)
                if m2:
                  person_number_suffix_non_past = "|وا|ي|[وي]ن|ن"
                  person_number_suffix_past = "ت|نا|تم|تن"
                  person_number_suffix = "(?:%s|%s)$" % (person_number_suffix_non_past, person_number_suffix_past)
                  # form III/VI geminate, with both full and elided variants listed as inflections
                  if re.search("[او]%s%s%s$" % (final_cons, final_cons, person_number_suffix), pagetitle):
                    pagemsg("Saw form III/VI geminate with both full and elided variants %s and %s listed as inflections, pagetitle is full variant %s so picking that" % (
                      lemma1, lemma2, pagetitle))
                    if lemma1_is_current:
                      # current lemma is already the full one, so do nothing
                      inner_continue = True
                      continue
                    else:
                      unvocalized_lemmas = [lemma1]
                      inner_continue = True
                      continue
                  if re.search("[او]%s%s$" % (final_cons, person_number_suffix), pagetitle):
                    pagemsg("Saw form III/VI geminate with both full and elided variants %s and %s listed as inflections, pagetitle is elided variant %s so picking that" % (
                      lemma1, lemma2, pagetitle))
                    if lemma1_is_current:
                      unvocalized_lemmas = [lemma2]
                      inner_continue = True
                      continue
                    else:
                      # current lemma is already the elided one, so do nothing
                      inner_continue = True
                      continue
            if inner_continue:
              continue
          pagemsg("WARNING: Saw two or more different unvocalized lemmas %s and %s in same etym section for {{%s}} in conjunction with {{ar-verb-form}}, skipping: %s"
                  % (",".join(unvocalized_lemmas), unvoc_lemma, tname(t), str(t)))
          must_continue = True
          break
        if unvoc_lemma not in unvocalized_lemmas:
          unvocalized_lemmas.append(unvoc_lemma)
      elif tn == "ar-rootbox":
        ar_rootboxes.append(str(t))
      elif tn == "nonlemma":
        saw_nonlemma = True
      elif tn not in ["ar-IPA"]:
        pagemsg("WARNING: Saw unrecognized template in {{ar-verb-form}} section (form %s, vocalized lemma(s) %s)%s; skipping: %s"
                % (verb_form, ",".join(vocalized_lemmas), no_multi_etym_msg and "; %s" % no_multi_etym_msg or "",
                   str(t)))
        must_continue = True
        break
    if must_continue:
      continue
    etym_sections[k] = do_etymtext(etym_sections[k], verb_form, unvocalized_lemmas, verb_header_level, vocalized_lemmas,
                                   num_ar_verb_forms, ar_rootboxes, saw_nonlemma)
  secbody = "".join(etym_sections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)

  return text, notes
  
parser = blib.create_argparser("Convert {{ar-verb-form}} to new-format {{ar-verb form}}", include_pagefile=True,
                               include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==Arabic== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_refs=["Template:ar-verb-form"], skip_ignorable_pages=True)

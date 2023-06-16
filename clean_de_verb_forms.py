#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site
import infltags

"""
Examples of verb forms to convert:

Page 1 aal: -------- begin text --------

# {{label|de|colloquial}} {{verb form of|de|aalen||1|s|pres}}

->

# {{lb|de|colloquial}} {{verb form of|de|aalen||1|s|pres}}


Page 3 aalend: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{participle of|de|aalen||pres}}

->

===Participle===
{{head|de|present participle}}

# {{present participle of|de|aalen}}


Page 12 aas: -------- begin text --------

===Verb===
{{head|de|verb form}}
# {{verb form of|de|aasen||s|imp}}

->

===Verb===
{{head|de|verb form}}

# {{verb form of|de|aasen||s|imp}}


Page 27 abalieniert: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{verb form of|de|abalienieren||3|s|pres|;|2|p|pres|;|p|imp}}
# {{participle of|de|abalienieren||past}}

->

===Verb===
{{head|de|verb form}}

# {{verb form of|de|abalienieren||3|s|pres|;|2|p|pres|;|p|imp}}

===Participle===
{{head|de|past participle}}

# {{past participle of|de|abalienieren}}


Page 49 abandonniert: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{participle of|de|abandonnieren||past}}
# {{verb form of|de|abandonnieren||3|s|pres|;|2|p|pres|;|p|imp}}

->

===Verb===
{{head|de|verb form}}

# {{verb form of|de|abandonnieren||3|s|pres|;|2|p|pres|;|p|imp}}

===Participle===
{{head|de|past participle}}

# {{past participle of|de|abandonnieren}}


Page 75 abbauend: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{inflection of|de|abbauen||pres|part}}

->

===Participle===
{{head|de|present participle}}

# {{present participle of|de|abbauen}}


Page 137 abbiegend: -------- begin text --------

===Noun===
{{head|de|present participle}}

# {{present participle of|de|abbiegen|nocat=1}}

===Verb===
{{head|de|verb form}}

# {{participle of|de|abbiegen||pres}}

->

===Participle===
{{head|de|present participle}}

# {{present participle of|de|abbiegen}}


Page 160 abblätter: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{verb form of|de|abblättern||1|s|dep|pres}}

->

===Verb===
{{head|de|verb form}}

# {{lb|de|colloquial}} {{verb form of|de|abblättern||1|s|dep|pres}}


Page 182 abblitzend: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{present participle of|de|abblitzen}}

->

===Participle===
{{head|de|present participle}}

# {{present participle of|de|abblitzen}}


Page 263 abdirigiert: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{past participle of|de|abdirigieren}}

->

===Participle===
{{head|de|past participle}}

# {{past participle of|de|abdirigieren}}


Page 419 abführt: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{inflection of|de|abführen||3|s|pres|indc}}
# {{inflection of|de|abführen||2|p|pres|indc}}

->

===Verb===
{{head|de|verb form}}

# {{verb form of|de|abführen||3|s|pres|;|2|p|pres}}


Page 431 abgebaggert: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{inflection of|de|abbaggern||perf|part}}

->

===Participle===
{{head|de|past participle}}

# {{past participle of|de|abbaggern}}


Page 508 abgerieben: -------- begin text --------

===Participle===
{{head|de|verb form}}

# {{participle of|de|abreiben||past}}

->

===Participle===
{{head|de|past participle}}

# {{past participle of|de|abreiben}}


Page 600 abhäute: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{inflection of|de|abhäuten||1|s|dep|pres|;|1//3|s|dep|sub|I}}

->

===Verb===
{{head|de|verb form}}

# {{verb form of|de|abhäuten||1|s|dep|pres|;|1//3|s|dep|sub|I}}


Page 1548 addete: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{inflection of|de|adden||1//3//1//3|s|pret|;|1//3|s|sub|II}}

->

===Verb===
{{head|de|verb form}}

# {{verb form of|de|adden||1//3|s|pret|;|1//3|s|sub|II}}


Page 1684 akklimatisiert: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{inflection of|de|akklimatisieren||3|s|pres|;|perf|part|;|2|p|pres|;|p|imp}}

->

===Verb===
{{head|de|verb form}}

# {{verb form of|de|akklimatisieren||3|s|pres|;|2|p|pres|;|p|imp}}

===Participle===
{{head|de|past participle}}

# {{past participle of|de|akklimatisieren}}


Page 1863 anbetreffend: -------- begin text --------

===Verb===
{{head|de|verb form}}
# {{present participle of|de|anbetreffen}}

->

===Verb===
{{head|de|verb form}}

# {{present participle of|de|anbetreffen}}


Page 2684 antizipiert: -------- begin text --------

===Participle===
{{head|de|past participle}}

# {{past participle of|de|antizipieren|nocat=1}}

->

===Participle===
{{head|de|past participle}}

# {{past participle of|de|antizipieren}}


Page 2685 antizipierte: -------- begin text --------

===Participle===
{{head|de|participle form}}

# {{de-adj form of|antizipiert}}

->

===Participle===
{{head|de|past participle form}}

# {{de-adj form of|antizipiert}}


Page 16368 etymologisiert: -------- begin text --------

===Noun===
{{head|de|verb form}}

# {{infl of|de|etymologisieren||3|s|pres|ind}}
# {{infl of|de|etymologisieren||2|p|pres|ind}}
# {{infl of|de|etymologisieren||2|p|imp}}
# {{infl of|de|etymologisieren||past|part}}

->

===Verb===
{{head|de|verb form}}

# {{verb form of|de|etymologisieren||3|s|pres|;|2|p|pres|;|p|imp}}

===Participle===
{{head|de|past participle}}

# {{past participle of|de|etymologisieren}}


Page 16544 fache: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{inflection of|de|fachen||1|s|pres|ind}}
# {{inflection of|de|fachen||1|s|pres|sub}}
# {{inflection of|de|fachen||3|s|pres|sub}}
# {{inflection of|de|fachen||2|s|pres|imp}}

->

===Verb===
{{head|de|verb form}}

# {{verb form of|de|fachen||1|s|pres|;|1//3|s|sub|I|;|s|imp}}


Page 17178 feilte: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{inflection of|de|feilen||1//3|s|preterite|;|1//3|s|subj|II}}

->

===Verb===
{{head|de|verb form}}

# {{verb form of|de|feilen||1//3|s|pret|;|1//3|s|subj|II}}


Page 20936 geprüft: -------- begin text --------

===Verb===
{{head|de|verb forms}}

# {{inflection of|de|prüfen||past|part}}; [[verified]], [[checked]], [[proved]]

->

===Participle===
{{head|de|past participle}}

# {{past participle of|de|prüfen}}; [[verified]], [[checked]], [[proved]]


Page 21309 gestaltet: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{inflection of|de|gestalten||3|s|pres|indc}}
# {{inflection of|de|gestalten||2|p|pres|indc}}
# {{past participle of|de|gestalten}}

->

===Verb===
{{head|de|verb form}}

# {{verb form of|de|gestalten||3|s|pres|;|2|p|pres}}

===Participle===
{{head|de|past participle}}

# {{past participle of|de|gestalten}}


Page 21523 gewann: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{inflection of|de|gewinnen||1//3|s|ind|past}}

->

===Verb===
{{head|de|verb form}}

# {{verb form of|de|gewinnen||1//3|s|pret}}


Page 21730 giere: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{inflection of|de|gieren||1|s|pres|ind//sub|;|3|s|pres|subj|;|2|s|impr}}

->

===Verb===
{{head|de|verb form}}

# {{verb form of|de|gieren||1|s|pres|;|1//3|s|sub|I|;|s|imp}}


Page 21734 giert: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{inflection of|de|gieren||3|s|pres|indc|;|2|p|pres|ind//imp}}

->

===Verb===
{{head|de|verb form}}

# {{verb form of|de|gieren||3|s|pres|;|2|p|pres|;|p|imp}}


Page 21735 gierte: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{inflection of|de|gieren||1//3|s|pret|ind//sub}}

->

===Verb===
{{head|de|verb form}}

# {{verb form of|de|gieren||1//3|s|pret|;|1//3|s|sub|II}}


Page 21807 ginge: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{inflection of|de|gehen||1|s|past|subj}}
# {{inflection of|de|gehen||3|s|past|subj}}

->

===Verb===
{{head|de|verb form}}

# {{verb form of|de|gehen||1//3|s|sub|II}}


Page 22083 glaube: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{inflection of|de|glauben||1|s|ind|pres}}
# {{inflection of|de|glauben||2|s|imp}}
# {{inflection of|de|glauben||1|s|sub|pres}}
# {{inflection of|de|glauben||3|s|sub|pres}}

->

===Verb===
{{head|de|verb form}}

# {{verb form of|de|glauben||1|s|pres|;|1/3|s|sub|I|;|s|imp}}


Page 22705 grub: -------- begin text --------

===Verb===
{{head|de|verb form}}

# {{inflection of|de|graben||s|past|impf}}

->

===Verb===
{{head|de|verb form}}

# {{verb form of|de|graben||1//3|s|pret}}
"""

tag_to_dimension_table, tag_to_canonical_form_table = infltags.fetch_tag_tables()

no_split_etym = set()

# Convert occurrences of the tags on the left side of the pair (in any order) to the tags on the right side of the pair
# (in the specified order, at the location of the first replaced tag). Order in the following list matters.
inflection_conversions = [
  (["indc"], ["ind"]),
  (["pres", "ind"], ["pres"]),
  (["perf"], ["pret"]),
  (["past"], ["pret"]),
  (["ptcp"], ["part"]),
  (["preterite"], ["pret"]),
  (["pret", "ind"], ["pret"]),
  (["pret", "impf"], ["pret"]),
  (["pres", "sub"], ["sub", "I"]),
  (["pret", "sub"], ["sub", "II"]),
  (["impr"], ["imp"]),
  (["2", "s", "imp"], ["s", "imp"]),
  (["2", "p", "imp"], ["p", "imp"]),
  (["pres", "imp"], ["imp"]),
]

class BreakException(Exception):
  pass

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "German", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  def verify_lang(t, lang=None):
    lang = lang or getparam(t, "1")
    if lang != "de":
      pagemsg("WARNING: Saw {{%s}} for non-German language: %s" % (tname(t), str(t)))
      raise BreakException()

  def verify_verb_lemma(t, term):
    if not re.search("(e[rl]*n|th?un|sein)$", term):
      pagemsg("WARNING: Term %s doesn't look like an infinitive: %s" % (term, str(t)))
      raise BreakException()

  def verify_past_participle(t, term):
    if not re.search("(t|en|th?an)$", term):
      pagemsg("WARNING: Term %s doesn't look like a past participle: %s" % (term, str(t)))
      raise BreakException()

  def verify_present_participle(t, term):
    if not re.search("e[rl]*nd$", term):
      pagemsg("WARNING: Term %s doesn't look like a present participle: %s" % (term, str(t)))
      raise BreakException()

  def check_unrecognized_params(t, allowed_params, no_break=False):
    for param in t.params:
      pn = pname(param)
      pv = str(param.value)
      if pn not in allowed_params:
        pagemsg("WARNING: Saw unrecognized param %s=%s: %s" % (pn, pv, str(t)))
        if not no_break:
          raise BreakException()
        else:
          return False
    return True

  for k in range(2, len(subsections), 2):
    if re.search("==(Verb|Participle|Noun)==", subsections[k - 1]):
      # Make sure that we're dealing with a potential verb form of participle; occasional participles under Noun
      maybe_saw_verb_form = False
      parsed = blib.parse_text(subsections[k])
      for t in parsed.filter_templates():
        tn = tname(t)
        def getp(param):
          return getparam(t, param)

        if (tn == "head" and getp("1") == "de" and getp("2") in [
          "verb form", "verb forms", "participle form", "past participle form", "participle", "past participle",
          "present participle"]):
          maybe_saw_verb_form = True
          break

      if not maybe_saw_verb_form:
        continue

      this_sec_notes = []
      newsubsecheader = subsections[k - 1]
      newsubseck = subsections[k]
      try:
        # Replace 1//3//1//3 with 1//3.
        newnewsubseck = newsubseck.replace("1//3//1//3", "1//3")
        if newnewsubseck != newsubseck:
          this_sec_notes.append("replace 1//3//1//3 inflection tag with 1//3")
          newsubseck = newnewsubseck

        # Combine adjacent {{inflection of}}/{{verb form of}} calls.
        newsubseck = infltags.combine_adjacent_inflection_of_calls(newsubseck, this_sec_notes, pagemsg)

        # Split out any participle forms from {{inflection of}}.
        while True:
          # Loop repeatedly in case we have more than one {{inflection of}} (e.g. with [[erudite]]).
          # After splitting an {{inflection of}} into two, we need to re-parse the text so that further
          # changes don't stomp on the previous ones.
          parsed = blib.parse_text(newsubseck)
          made_a_change = False
          for t in parsed.filter_templates():
            tn = tname(t)
            def getp(param):
              return getparam(t, param)

            if tn in infltags.generic_inflection_of_templates or tn == "verb form of":
              addltemp = None
              addltemp_arg = None
              removed_tag_set = None
              tags, params, lang, term, tr, alt = (
                infltags.extract_tags_and_nontag_params_from_inflection_of(t, this_sec_notes)
              )
              verify_lang(t, lang)
              if params or tr or alt:
                pagemsg("WARNING: Saw extra parameters in {{%s}}, skipping: %s" % (tn, str(t)))
                raise BreakException()
              tag_sets = infltags.split_multipart_tag_sets(infltags.split_tags_into_tag_sets(tags))

              filtered_tag_sets = []
              did_remove = False
              for tag_set in tag_sets:
                # Replace according to inflection_conversions.
                for conv_from, conv_to in inflection_conversions:
                  conv_from = set(conv_from)
                  if conv_from <= set(tag_set):
                    new_tags = []
                    inserted = False
                    for tag in tag_set:
                      if tag in conv_from:
                        if not inserted:
                          new_tags.extend(conv_to)
                          inserted = True
                      else:
                        new_tags.append(tag)
                    tag_set = new_tags

                newtemp = None
                tag_set_set = set(tag_set)
                if tag_set_set == {"pret", "part"}:
                  newtemp = "past participle of"
                elif tag_set_set == {"pres", "part"}:
                  newtemp = "present participle of"
                else:
                  filtered_tag_sets.append(tag_set)
                if newtemp:
                  if addltemp:
                    pagemsg("WARNING: Saw more than one past participle form in {{%s}}: {{%s|de|%s}} and {{%s|de|%s}}" % (
                      tn, addltemp, addltemp_arg, newtemp, term))
                    raise BreakException()
                  addltemp = newtemp
                  addltemp_arg = term
                  removed_tag_set = tag_set

              def put_back_tags(new_tags):
                origt = str(t)
                # Now combine adjacent tags into multipart tags.
                def warn(text):
                  pagemsg("WARNING: %s" % text)
                new_tags, this_notes = infltags.combine_adjacent_tags_into_multipart(
                  tn, lang, term, new_tags, tag_to_dimension_table, pagemsg, warn,
                  tag_to_canonical_form_table=tag_to_canonical_form_table
                )
                infltags.put_back_new_inflection_of_params(t, this_notes, new_tags, params, lang, term, tr, alt)
                if origt != str(t):
                  this_sec_notes.extend(this_notes)
                  pagemsg("Replace %s with %s" % (origt, str(t)))
                  return True
                else:
                  return False

              if addltemp and not filtered_tag_sets:
                origt = str(t)
                blib.set_template_name(t, addltemp)
                del t.params[:]
                t.add("1", "de")
                t.add("2", addltemp_arg)
                this_sec_notes.append("replace {{%s|de}} with {{%s|de}}" % (tn, addltemp))
                made_a_change = True
                pagemsg("Replace %s with %s" % (origt, str(t)))
                newsubseck = str(parsed)
              elif filtered_tag_sets and not addltemp:
                new_tags = infltags.combine_tag_set_group(filtered_tag_sets)
                changed = put_back_tags(new_tags)
                if changed:
                  if new_tags != tags or not this_sec_notes:
                    this_sec_notes.append("clean {{%s|de}}" % tn)
                  made_a_change = True
                  newsubseck = str(parsed)
              elif addltemp and filtered_tag_sets:
                new_tags = infltags.combine_tag_set_group(filtered_tag_sets)
                m = re.search(r"\A(.*)^([^\n]*)%s([^\n]*)\n(.*)\Z" % re.escape(str(t)), newsubseck, re.S | re.M)
                if not m:
                  pagemsg("WARNING: Something wrong, can't find %s in <<%s>>" % (str(t), newsubseck))
                  raise BreakException()
                before_lines, before_on_line, after_on_line, after_lines = m.groups()
                put_back_tags(new_tags)
                this_sec_notes.append("remove %s from {{%s|de}} and replace with {{%s|de}}" % ("|".join(removed_tag_set), tn,
                  addltemp))
                made_a_change = True
                newsubseck = "%s%s%s%s\n%s{{%s|de|%s}}%s\n%s" % (
                  before_lines, before_on_line, str(t), after_on_line, before_on_line, addltemp, addltemp_arg,
                  after_on_line, after_lines)
              else:
                pagemsg("WARNING: Something wrong, no tag sets remain and no new templates added: %s" % str(t))
                raise BreakException()
              
              if made_a_change:
                # Break the for-loop over templates. Re-parse and start again from the top.
                break

          if not made_a_change:
            # Break the 'while True' loop.
            break

        # Now replace {{participle of}} with regular participle inflection templates. Also remove nocat=1 from
        # regular participle inflection templates, convert {{inflection of}}/{{infl of}} to {{verb form of}}
        # and convert {{head|de|verb forms}} to {{head|de|verb form}}.
        parsed = blib.parse_text(newsubseck)

        for t in parsed.filter_templates():
          tn = tname(t)
          def getp(param):
            return getparam(t, param)

          if tn == "participle of":
            verify_lang(t)
            check_unrecognized_params(t, ["1", "2", "3", "4"])
            if getp("3"):
              pagemsg("WARNING: {{participle of}} has 3=: %s" % str(t))
              raise BreakException()
            part_type = getp("4")
            if part_type == "past":
              name = "past participle of"
              verify_past_participle(t, pagetitle)
            elif part_type == "pres":
              name = "present participle of"
              verify_present_participle(t, pagetitle)
            else:
              pagemsg("WARNING: Unrecognized 4= in {{participle of}}: %s" % str(t))
              raise BreakException()
            lemma = getp("2")
            verify_verb_lemma(t, lemma)
            blib.set_template_name(t, name)
            rmparam(t, "4")
            rmparam(t, "3")
            this_sec_notes.append("convert {{participle of|de|...|%s}} to {{%s|de}}" % (part_type, name))
            newsubseck = str(parsed)

          elif tn in ["past participle of", "present participle of"]:
            verify_lang(t)
            if tn == "past participle of":
              verify_past_participle(t, pagetitle)
            else:
              verify_present_participle(t, pagetitle)
            verify_verb_lemma(t, getp("2"))
            if getp("nocat"):
              rmparam(t, "nocat")
              this_sec_notes.append("remove nocat=1 from {{%s|de}}" % tn)
              newsubseck = str(parsed)

          elif tn in infltags.generic_inflection_of_templates:
            verify_lang(t)
            verify_verb_lemma(t, getp("2"))
            blib.set_template_name(t, "verb form of")
            this_sec_notes.append("replace {{%s|de}} with {{verb form of|de}}" % tn)
            newsubseck = str(parsed)

          elif tn == "head" and getp("1") == "de" and getp("2") == "verb forms":
            t.add("2", "verb form")
            this_sec_notes.append("replace {{head|de|verb forms}} with {{head|de|verb form}}")
            newsubseck = str(parsed)


        # Now split {{inflection of}} and {{present/past participle of}} under the same header. Also correct header
        # POS and headword POS as needed.
        parsed = blib.parse_text(newsubseck)

        saw_verb_form_of = False
        saw_pastp_of = False
        saw_presp_of = False
        saw_part_form_of = False
        head_template = None
        part_template = None
        for t in parsed.filter_templates():
          tn = tname(t)
          def getp(param):
            return getparam(t, param)
          if tn == "verb form of":
            saw_verb_form_of = True
          elif tn in ["past participle of", "present participle of"]:
            if tn == "past participle of":
              saw_pastp_of = True
            else:
              saw_presp_of = True
            if part_template:
              pagemsg("WARNING: Saw two participle templates %s and %s in likely verb form subsection" % (
                str(part_template), str(t)))
              raise BreakException()
            part_template = t
          elif tn == "de-adj form of":
            saw_part_form_of = True
          elif tn == "head":
            verify_lang(t)
            if getp("2") not in ["verb form", "participle form", "past participle form", "participle",
                "past participle", "present participle"]:
              pagemsg("WARNING: Saw strange headword POS in likely verb form subsection: %s" % str(t))
              raise BreakException()
            if head_template:
              pagemsg("WARNING: Saw two head templates %s and %s in likely verb form subsection" % (
                str(head_template), str(t)))
              raise BreakException()
            head_template = t

        if not head_template:
          pagemsg("WARNING: Didn't see head template in likely verb form subsection: <<%s>>" % newsubseck)
          raise BreakException()

        saw_it = 0
        if saw_pastp_of:
          saw_it += 1
        if saw_presp_of:
          saw_it += 1
        if saw_part_form_of:
          saw_it += 1
        if saw_it > 1:
          pagemsg("WARNING: Saw more than one of {{past participle of}}, {{present participle of}}, {{de-adj form of}}: <<%s>>" % newsubseck)
          raise BreakException()
        saw_part_of = saw_pastp_of or saw_presp_of
        if saw_part_of and not saw_verb_form_of:
          check_unrecognized_params(head_template, ["1", "2", "head"])
          pos = getparam(head_template, "2")
          should_pos = "past participle" if saw_pastp_of else "present participle"
          if pos in ["verb form", "participle"]:
            head_template.add("2", should_pos)
            this_sec_notes.append("convert {{head|de|verb form}} to {{head|de|%s}}" % should_pos)
            newsubseck = str(parsed)
          elif pos != should_pos:
            pagemsg("WARNING: Head template has strange POS for participle, should be '%s': %s"
                % (should_pos, str(head_template)))
            raise BreakException()
          if "Verb" in newsubsecheader:
            newsubsecheader = newsubsecheader.replace("Verb", "Participle")
            this_sec_notes.append("correct ==Verb== to ==Participle== for participle")
          if "Noun" in newsubsecheader:
            newsubsecheader = newsubsecheader.replace("Noun", "Participle")
            this_sec_notes.append("correct ==Noun== to ==Participle== for participle")

        elif saw_part_of and saw_verb_form_of:
          check_unrecognized_params(head_template, ["1", "2", "head"])
          lines = newsubseck.rstrip("\n").split("\n")
          headword_line = None
          lines_for_verb_form_of = []
          lines_for_part = []
          last_line_is_part = False
          for i, line in enumerate(lines):
            is_headword_line = line.startswith("{")
            if is_headword_line and i > 0:
              pagemsg("WARNING: Saw headword line not at beginning of subsection: %s" % line)
              raise BreakException()
            if not is_headword_line and i == 0:
              pagemsg("WARNING: Saw non-headword line at beginning of subsection: %s" % line)
              raise BreakException()
            if is_headword_line:
              headword_line = line
            elif re.search(r"^#+[:*]", line):
              # a quotation or similar
              if last_line_is_part:
                lines_for_part.append(line)
              else:
                lines_for_verb_form_of.append(line)
            elif not line:
              last_line_is_part = False
              lines_for_verb_form_of.append(line)
            elif not line.startswith("#"):
              pagemsg("WARNING: Saw non-definition line in definition subsection: %s" % line)
              last_line_is_part = False
              lines_for_verb_form_of.append(line)
            elif re.search(r"\{\{\s*verb form of\s*\|", line):
              # A {{verb form of}} line
              last_line_is_part = False
              lines_for_verb_form_of.append(line)
            elif re.search(r"\{\{\s*(present|past) participle of\s*\|", line):
              # A participle-of line
              last_line_is_part = True
              lines_for_part.append(line)
            else:
              pagemsg("WARNING: Saw strange definition line in definition subsection: %s" % line)
              last_line_is_part = False
              lines_for_verb_form_of.append(line)

          if not headword_line:
            pagemsg("WARNING: Something wrong, didn't see headword line in subsection: <<%s>>" % newsubseck)
            raise BreakException()
          if headword_line != str(head_template):
            pagemsg("WARNING: Additional text on headword line besides headword template: %s" % headword_line)
            raise BreakException()
          head_template_head = getparam(head_template, "head")
          if head_template_head:
            head_template_head = "|head=%s" % head_template_head
          headword_line_1 = "{{head|de|verb form%s}}" % head_template_head
          if saw_presp_of:
            verify_present_participle(part_template, pagetitle)
            newpos = "present participle"
          else:
            verify_past_participle(part_template, pagetitle)
            newpos = "past participle"
          headword_line_2 = "{{head|de|%s}}" % newpos
          
          newsubsecheader = re.sub("(Verb|Noun)", "Participle", newsubsecheader)
          newsubseck_lines = (
            [headword_line_2, ""] + lines_for_part
            + ["", newsubsecheader.replace("Participle", "Verb").rstrip("\n"), headword_line_1]
            + lines_for_verb_form_of
          )
          newsubseck = "\n".join(newsubseck_lines) + "\n\n"
          this_sec_notes.append("split verb form and past participle into two subsections")

        elif saw_part_form_of:
          if saw_verb_form_of:
            pagemsg("WARNING: Saw both 'verb form of' and 'de-adj form of' in same section: <<%s>>" % newsubseck)
            raise BreakException()
          check_unrecognized_params(head_template, ["1", "2", "head"])
          pos = getparam(head_template, "2")
          if pos in ["participle", "present participle", "past participle", "past participle form"]:
            pagemsg("WARNING: Head template has strange POS for participle form: %s" % str(head_template))
            raise BreakException()
          if pos == "verb form":
            head_template.add("2", "participle form")
            this_sec_notes.append("convert {{head|de|%s}} to {{head|de|participle form}} for participle form" % pos)
            newsubseck = str(parsed)
          if "Verb" in newsubsecheader:
            newsubsecheader = newsubsecheader.replace("Verb", "Participle")
            this_sec_notes.append("correct ==Verb== to ==Participle== for participle form")
          if "Noun" in newsubsecheader:
            newsubsecheader = newsubsecheader.replace("Noun", "Participle")
            this_sec_notes.append("correct ==Noun== to ==Participle== for participle form")

      except BreakException:
        # something went wrong, go to next subsection
        continue

      subsections[k] = newsubseck
      subsections[k - 1] = newsubsecheader
      notes.extend(this_sec_notes)

  secbody = "".join(subsections)

  # Remove duplicate sections, which may happen with present participles:

  #===Noun===
  #{{head|de|present participle}}
  #
  ## {{present participle of|de|abbiegen|nocat=1}}
  #
  #===Verb===
  #{{head|de|verb form}}
  #
  ## {{participle of|de|abbiegen||pres}}

  # which becomes

  #===Participle===
  #{{head|de|present participle}}
  # 
  ## {{present participle of|de|abbiegen}}
  #
  #===Participle===
  #{{head|de|present participle}}
  #
  ## {{present participle of|de|abbiegen}}

  newsecbody = blib.rsub_repeatedly(r"^(==.*?\n)\1", r"\1", secbody, 0, re.M | re.S)
  if newsecbody != secbody:
    notes.append("remove duplicate participle sections")
    secbody = newsecbody

  #  # Now split etym sections as needed.
  #
  #  def extract_pos_and_lemma(subsectext, lemma_pos, head_lemma_poses, head_nonlemma_poses, special_templates, allowable_form_of_templates):
  #    parsed = blib.parse_text(subsectext)
  #    pos = None
  #    lemma = None
  #    for t in parsed.filter_templates():
  #      tn = tname(t)
  #      def getp(param):
  #        return getparam(t, param)
  #      if tn == "head":
  #        verify_lang(t)
  #        if pos:
  #          pagemsg("WARNING: Saw two headwords: <<%s>>" % subsectext)
  #          raise BreakException()
  #        pos = getp("2")
  #        if pos in head_lemma_poses:
  #          lemma = True
  #        elif pos in head_nonlemma_poses:
  #          pass
  #        else:
  #          pagemsg("WARNING: Strange pos=%s for %s: <<%s>" % (pos, lemma_pos, subsectext))
  #          raise BreakException()
  #      if tn in special_templates:
  #        if pos:
  #          pagemsg("WARNING: Saw two headwords: <<%s>>" % subsectext)
  #          raise BreakException()
  #        pos = special_templates[tn]
  #        if not pos.endswith(" form"):
  #          lemma = True
  #      if tn in allowable_form_of_templates or tn in infltags.generic_inflection_of_templates:
  #        verify_lang(t)
  #        if pos is None:
  #          pagemsg("WARNING: Didn't see headword template in %s section: <<%s>>" % (lemma_pos, subsectext))
  #          raise BreakException()
  #        if lemma is True:
  #          pagemsg("WARNING: Saw form-of template %s in lemma %s section: <<%s>>" % (str(t), lemma_pos, subsectext))
  #          raise BreakException()
  #        if lemma:
  #          pagemsg("WARNING: Saw two form-of templates in lemma %s section, second is %s: <<%s>>" %
  #            (lemma_pos, str(t), subsectext))
  #        lemma = getp("2")
  #    if lemma is None:
  #      pagemsg("WARNING: Unable to locate lemma in nonlemma %s section: <<%s>>" % (lemma_pos, subsectext))
  #      raise BreakException()
  #    return pos, lemma
  #
  #  def contains_any(lst, items):
  #    return any(item in lst for item in items)
  #
  #  text_before_etym_sections = []
  #  text_for_etym_sections = []
  #  this_notes = []
  #
  #  def process_etym_section(secno, sectext, is_etym_section):
  #    split_etym_sections = []
  #    goes_in_all_at_top = []
  #    goes_at_top_of_first_etym_section = ""
  #    last_etym_section = None
  #    subsections = re.split("(^==+[^=\n]+==+\n)", sectext, 0, re.M)
  #    if not is_etym_section:
  #      text_before_etym_sections.append(subsections[0])
  #    else:
  #      goes_at_top_of_first_etym_section = subsections[0]
  #    for k in range(2, len(subsections), 2):
  #      pos = None
  #      lemma = None
  #      if "=Pronunciation=" in subsections[k - 1]:
  #        if is_etym_section:
  #          goes_in_all_at_top.append(k)
  #        else:
  #          text_before_etym_sections.append(subsections[k - 1])
  #          text_before_etym_sections.append(subsections[k])
  #      elif "=Etymology=" in subsections[k - 1]:
  #        if is_etym_section:
  #          pagemsg("WARNING: Saw =Etymology= in etym section")
  #          raise BreakException()
  #        goes_at_top_of_first_etym_section = subsections[k]
  #      elif "=Alternative forms=" in subsections[k - 1]:
  #        # If =Alternative forms= at top, treat like =Pronunciation=; otherwise, append to
  #        # end of last etym section.
  #        if last_etym_section is None:
  #          if is_etym_section:
  #            goes_in_all_at_top.append(k)
  #          else:
  #            text_before_etym_sections.append(subsections[k - 1])
  #            text_before_etym_sections.append(subsections[k])
  #        else:
  #          existing_poses, existing_lemmas, existing_sections = split_etym_sections[last_etym_section]
  #          existing_sections.append((k, None))
  #      elif "=Adjective=" in subsections[k - 1]:
  #        pos, lemma = extract_pos_and_lemma(subsections[k], "adjective", {"adjective"}, {"adjective form"},
  #            {"it-adj": "adjective", "it-adj-sup": "adjective", "it-adj-form": "adjective form"},
  #            {"adj form of", "plural of", "masculine plural of", "feminine singular of", "feminine plural of"})
  #      elif "=Participle=" in subsections[k - 1]:
  #        pos, lemma = extract_pos_and_lemma(subsections[k], "participle", {"participle", "present participle", "past participle"},
  #            {"participle form", "past participle form"},
  #            {"it-pp": "past participle"},
  #            {"masculine plural of", "feminine singular of", "feminine plural of"})
  #      elif "=Noun=" in subsections[k - 1]:
  #        pos, lemma = extract_pos_and_lemma(subsections[k], "noun", {"noun"}, {"noun form"},
  #            {"it-noun": "noun", "it-plural noun": "noun"}, {"noun form of", "plural of"})
  #      elif "=Verb=" in subsections[k - 1]:
  #        # FIXME, handle {{it-compound of}}
  #        pos, lemma = extract_pos_and_lemma(subsections[k], "verb", {"verb"}, {"verb form"},
  #            {"it-verb": "verb"}, {"verb form of"})
  #      elif "=Adverb=" in subsections[k - 1]:
  #        pos, lemma = extract_pos_and_lemma(subsections[k], "adverb", {"adverb"}, [],
  #            {"it-adv": "adverb"}, [])
  #      elif "=Interjection=" in subsections[k - 1]:
  #        pos, lemma = extract_pos_and_lemma(subsections[k], "interjection", {"interjection"}, [],
  #            {}, [])
  #      elif "=Preposition=" in subsections[k - 1]:
  #        pos, lemma = extract_pos_and_lemma(subsections[k], "preposition", {"preposition"}, [],
  #            {}, [])
  #      elif "=Conjunction=" in subsections[k - 1]:
  #        pos, lemma = extract_pos_and_lemma(subsections[k], "conjunction", {"conjunction"}, [],
  #            {}, [])
  #      elif re.search(r"=\s*(Synonyms|Antonyms|Hyponyms|Hypernyms|Coordinate terms|Derived terms|Related terms|Descendants|Usage notes|References|Further reading|See also|Conjugation|Declension|Inflection)\s*=", subsections[k - 1]):
  #        if last_etym_section is None:
  #          pagemsg("WARNING: Saw section header %s without preceding lemma or non-lemma form" %
  #              subsections[k - 1].strip())
  #          raise BreakException()
  #        existing_poses, existing_lemmas, existing_sections = split_etym_sections[last_etym_section]
  #        existing_sections.append((k, None))
  #      else:
  #        pagemsg("WARNING: Unrecognized section header: %s" % subsections[k - 1].strip())
  #        raise BreakException()
  #
  #      if pos:
  #        for etym_section_no, (existing_poses, existing_lemmas, existing_sections) in enumerate(split_etym_sections):
  #          ok_to_group = False
  #          if pos in ["participle form", "past participle form", "adjective form"] and pagetitle.endswith("a"):
  #            if contains_any(existing_poses, ["noun"]):
  #              for existing_section, existing_section_pos in existing_sections:
  #                if existing_section_pos == "noun":
  #                  parsed = blib.parse_text(subsections[existing_section])
  #                  for t in parsed.filter_templates():
  #                    tn = tname(t)
  #                    def getp(param):
  #                      return getparam(t, param)
  #                    if tn == "it-noun" and getp("m") or tn == "female equivalent of":
  #                      pagemsg("Grouping %s in section %s with likely female equivalent noun in section %s; defn is %s" % (
  #                        pos, k, existing_section, ";".join(blib.find_defns(subsections[existing_section], "it"))))
  #                      ok_to_group = True
  #                      break
  #                  if ok_to_group:
  #                    break
  #                  else:
  #                    pagemsg("Not grouping %s in section %s with likely non-female-equivalent noun in section %s; defn is %s" % (
  #                      pos, k, existing_section, ";".join(blib.find_defns(subsections[existing_section], "it"))))
  #          if not ok_to_group and pos == "noun" and pagetitle.endswith("a"):
  #            if contains_any(existing_poses, ["participle form", "adjective form"]):
  #              for existing_section, existing_section_pos in existing_sections:
  #                if existing_section_pos in ["participle form", "adjective form"]:
  #                  parsed = blib.parse_text(subsections[k])
  #                  for t in parsed.filter_templates():
  #                    tn = tname(t)
  #                    def getp(param):
  #                      return getparam(t, param)
  #                    if tn == "it-noun" and getp("m") or tn == "female equivalent of":
  #                      pagemsg("Likely female equivalent noun in section %s, grouping with %s in section %s; defn is %s" % (
  #                        k, existing_section_pos, existing_section, ";".join(blib.find_defns(subsections[k], "it"))))
  #                      ok_to_group = True
  #                      break
  #                  if ok_to_group:
  #                    break
  #                  else:
  #                    pagemsg("Likely non-female-equivalent noun in section %s, not grouping with %s in section %s; defn is %s" % (
  #                      k, existing_section_pos, existing_section, ";".join(blib.find_defns(subsections[k], "it"))))
  #          if not ok_to_group and ((
  #              (pos in ["participle", "past participle", "adjective", "adverb", "noun", "interjection",
  #                  "preposition", "conjunction"]
  #                and contains_any(existing_poses, ["participle", "past participle", "adjective", "adverb", "noun",
  #                  "interjection", "preposition", "conjunction"])
  #              or pos in ["participle form", "past participle form", "adjective form", "noun form"]
  #                and contains_any(existing_poses, ["participle form", "past participle form", "adjective form", "noun form"]))
  #              and lemma in existing_lemmas)
  #              or contains_any(existing_poses, [pos]) and lemma in existing_lemmas):
  #            existing_sections_text = ",".join(
  #              "%s:%s" % (existing_section, existing_section_pos) for existing_section, existing_section_pos in existing_sections)
  #            pagemsg("Grouping %s section %s with %s section(s) %s" % (pos, k, ",".join(existing_poses), existing_sections_text))
  #            ok_to_group = True
  #
  #          if ok_to_group:
  #            existing_poses.append(pos)
  #            existing_sections.append((k, pos))
  #            existing_lemmas.append(lemma)
  #            last_etym_section = etym_section_no
  #            break
  #
  #        else: # no break
  #          pagemsg("Creating new %s etym section %s for lemma %s" % (pos, k, lemma))
  #          split_etym_sections.append(([pos], [lemma], [(k, pos)]))
  #          last_etym_section = len(split_etym_sections) - 1
  #
  #    if len(split_etym_sections) <= 1:
  #      text_for_etym_sections.append(sectext)
  #    else:
  #      first = True
  #      for existing_poses, existing_lemmas, existing_sections in split_etym_sections:
  #        etym_section_parts = []
  #        if first:
  #          etym_section_parts.append(goes_at_top_of_first_etym_section)
  #          if not goes_at_top_of_first_etym_section.endswith("\n\n"):
  #            etym_section_parts.append("\n")
  #          first = False
  #        else:
  #          etym_section_parts.append("\n")
  #        for goes_in_all_sec in goes_in_all_at_top:
  #          etym_section_parts.append(subsections[goes_in_all_sec - 1])
  #          etym_section_parts.append(subsections[goes_in_all_sec])
  #        for existing_section, existing_section_pos in existing_sections:
  #          etym_section_parts.append(subsections[existing_section - 1])
  #          etym_section_parts.append(subsections[existing_section])
  #        etym_section_text = "".join(etym_section_parts)
  #        if not is_etym_section:
  #          # Indent all subsections by one level.
  #          etym_section_text = re.sub("^=(.*)=$", r"==\1==", etym_section_text, 0, re.M)
  #        text_for_etym_sections.append(etym_section_text)
  #      if is_etym_section:
  #        this_notes.append("split ==Etymology %s== into %s sections" % (secno, len(split_etym_sections)))
  #      else:
  #        this_notes.append("split into %s Etymology sections" % len(split_etym_sections))
  #
  #  if pagetitle in no_split_etym:
  #    pagemsg("Not splitting etymologies because page listed in no_split_etym")
  #  else:
  #    # Anagrams and such go after all etym sections and remain as such even if we start with non-etym-split text
  #    # and end with multiple etym sections.
  #    subsections_at_level_3 = re.split("(^===[^=\n]+===\n)", secbody, 0, re.M)
  #    for last_included_sec in range(len(subsections_at_level_3) - 1, 0, -2):
  #      if not re.search(r"^===\s*(References|See also|Derived terms|Related terms|Further reading|Anagrams)\s*=== *\n",
  #          subsections_at_level_3[last_included_sec - 1]):
  #        break
  #    text_after_etym_sections = "".join(subsections_at_level_3[last_included_sec + 1:])
  #    text_to_split_into_etym_sections = "".join(subsections_at_level_3[:last_included_sec + 1])
  #
  #    has_etym_1 = "==Etymology 1==" in text_to_split_into_etym_sections
  #
  #    try:
  #      if not has_etym_1:
  #        process_etym_section(1, text_to_split_into_etym_sections, is_etym_section=False)
  #        if len(text_for_etym_sections) <= 1:
  #          secbody = text_to_split_into_etym_sections + text_after_etym_sections
  #        else:
  #          secbody_parts = text_before_etym_sections
  #          for k, text_for_etym_section in enumerate(text_for_etym_sections):
  #            secbody_parts.append("===Etymology %s===\n" % (k + 1))
  #            secbody_parts.append(text_for_etym_section)
  #          secbody = "".join(secbody_parts) + text_after_etym_sections
  #          notes.extend(this_notes)
  #      else:
  #        etym_sections = re.split("(^===Etymology [0-9]+===\n)", text_to_split_into_etym_sections, 0, re.M)
  #        if len(etym_sections) < 5:
  #          pagemsg("WARNING: Something wrong, saw 'Etymology 1' but didn't see two etym sections")
  #        else:
  #          for k in range(2, len(etym_sections), 2):
  #            process_etym_section(k // 2, etym_sections[k], is_etym_section=True)
  #          if text_before_etym_sections:
  #            pagemsg("WARNING: Internal error: Should see empty text_before_etym_sections but saw: %s" %
  #                text_before_etym_sections)
  #          else:
  #            secbody_parts = [etym_sections[0]]
  #            for k, text_for_etym_section in enumerate(text_for_etym_sections):
  #              secbody_parts.append("===Etymology %s===\n" % (k + 1))
  #              secbody_parts.append(text_for_etym_section)
  #            secbody = "".join(secbody_parts) + text_after_etym_sections
  #            notes.extend(this_notes)
  #
  #    except BreakException:
  #      # something went wrong, do nothing
  #      pass

  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)

  # Replace {{label|de|... with {{lb|de|...
  newtext = text.replace("{{label|de|", "{{lb|de|")
  if newtext != text:
    notes.append("replace {{label|de}} with {{lb|de}}")
    text = newtext

  # Double newline needs to follow {{head|...}}.
  newtext = re.sub(r"^(\{\{head\|.*\}\}\n)(.)", r"\1\n\2", text, 0, re.M)
  if newtext != text:
    notes.append("add missing newline after {{head|...}}")
    text = newtext

  return text, notes

parser = blib.create_argparser("Clean up German verb forms",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang German' and has no ==German== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

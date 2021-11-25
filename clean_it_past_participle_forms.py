#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site
import infltags

"""
Examples of past participle forms to convert:

1. [[abbigliata]]:

===Participle===
{{head|it|past participle form}}

# {{feminine singular of|it|abbagliato}}


should be (i.e. add gender to headword)


===Participle===
{{head|it|past participle form|g=f-s}}

# {{feminine singular of|it|abbagliato}}



2. [[abalienati]]:

===Verb===
{{head|it|past participle form|g=m-p}}

# {{masculine plural of|it|abalienato}}


should be (i.e. ==Verb== -> ==Participle==)


===Participle===
{{head|it|past participle form|g=m-p}}

# {{masculine plural of|it|abalienato}}


3. [[abbigliati]]:

===Verb===
{{head|it|verb form|g=m}}

# {{plural of|it|abbagliato}}

===Anagrams===
* {{anagrams|it|a=aaabbgiilt|abbigliata}}

[[Category:Italian past participle forms]]


should be (i.e. ==Verb== -> ==Participle==, 'verb form' -> 'past participle form', g=m -> g=m-p, {{plural of}} ->
  {{masculine plural of}}, remove explicit category)


===Participle===
{{head|it|past participle form|g=m-p}}

# {{masculine plural of|it|abbagliato}}

===Anagrams===
* {{anagrams|it|a=aaabbgiilt|abbigliata}}


3a. [[abbattute]]:


===Verb===
{{head|it|verb form|g=f}}

# {{plural of|it|abbattuto}}

[[Category:Italian past participle forms]]


should be


===Participle===
{{head|it|past participle form|g=f-p}}

# {{feminine plural of|it|abbattuto}}


4. [[abbigliate]]:

===Verb===
{{head|it|verb form|cat2=past participle forms}}

# {{inflection of|it|abbagliare||2|p|pres|ind//sub|;|2|p|impr}}
# {{feminine plural of|it|abbagliato}}


should be (i.e. split etyms)


===Etymology 1===

====Verb====
{{head|it|verb form}}

# {{inflection of|it|abbagliare||2|p|pres|ind//sub|;|2|p|impr}}

===Etymology 2===

====Verb====
{{head|it|past participle form|g=f-p}}

# {{feminine plural of|it|abbagliato}}


4a. [[abolite]]:


==Italian==

===Verb===
{{head|it|verb form|cat2=past participle forms}}

# {{inflection of|it|abolire||2|p|pres|indc|;|2|p|impr}}
# {{plural of|it|abolito}}

===Anagrams===
* {{anagrams|it|a=abeilot|bietola|ilobate|obliate}}


should be


===Etymology 1===

====Verb====
{{head|it|verb form}}

# {{inflection of|it|abolire||2|p|pres|indc|;|2|p|impr}}

===Etymology 2===

====Verb====
{{head|it|past participle form|g=f-p}}

# {{feminine plural of|it|abolito}}

===Anagrams===
* {{anagrams|it|a=abeilot|bietola|ilobate|obliate}}


5. [[abbacciata]]:

===Pronunciation===
{{it-pr|abbacchiàta}}

===Participle===
{{head|it|past participle form}}

# {{feminine singular of|it|abbacchiato}}

===Anagrams===
* {{anagrams|it|a=aaaabbcchit|abbatacchia}}


should be (i.e. add g=f-s, preserve Pronunciation and Anagrams)


===Pronunciation===
{{it-pr|abbacchiàta}}

===Participle===
{{head|it|past participle form|g=f-s}}

# {{feminine singular of|it|abbacchiato}}

===Anagrams===
* {{anagrams|it|a=aaaabbcchit|abbatacchia}}


6. [[abbacchiati]]:


===Verb===
{{head|it|past participle form|g=m-p}}

# {{masculine plural of|it|abbacchiato}}

===Verb===
{{head|it|verb form}}

# {{inflection of|it|abbacchiarsi||2|s|impr}}


should be (i.e. ==Verb== -> ==Participle==, split etym when existing imperative verb present)


===Etymology 1===

====Participle====
{{head|it|past participle form|g=m-p}}

# {{masculine plural of|it|abbacchiato}}

===Etymology 2===

====Verb====
{{head|it|verb form}}

# {{inflection of|it|abbacchiarsi||2|s|impr}}


7. [[abbadata]]:


==Italian==

===Verb===
{{head|it|past participle form}}

# {{feminine singular past participle of|it|abbadare|nocat=1}}


should be ('feminine singular past participle of' -> 'feminine singular of' with change of lemma and removal of nocat=1)


==Italian==

===Participle===
{{head|it|past participle form|g=f-s}}

# {{feminine singular of|it|abbadato}}


8. [[abbadate]]:


==Italian==

===Verb===
{{head|it|verb form}}

# {{inflection of|it|abbadare||2|p|pres|indc|;|2|p|impr}}

===Participle===
{{head|it|past participle form}}

# {{feminine plural past participle of|it|abbadare|nocat=1}}


should be


==Italian==

===Etymology 1===

====Verb====
{{head|it|verb form}}

# {{inflection of|it|abbadare||2|p|pres|indc|;|2|p|impr}}

===Etymology 2===

====Participle====
{{head|it|past participle form|g=f-p}}

# {{feminine plural of|it|abbadare}}


9. [[abbaluginata]]:


==Italian==

===Participle===
{{head|it|past participle form}}

# {{feminine singular past participle of|it|abbaluginare}}

===Adjective===
{{head|it|adjective form}}

# {{adj form of|it|abbaluginato||f|s}}


should be


==Italian==

===Participle===
{{head|it|past participle form|g=f-s}}

# {{feminine singular of|it|abbaluginare}}

===Adjective===
{{head|it|adjective form}}

# {{adj form of|it|abbaluginato||f|s}}


10. [[abbaluginate]]:


==Italian==

===Participle===
{{head|it|past participle form}}

# {{feminine plural past participle of|it|abbaluginare}}

===Adjective===
{{head|it|adjective form}}

# {{adj form of|it|abbaluginato||f|p}}


should be


==Italian==

===Etymology 1===

====Verb====
{{head|it|verb form}}

# {{inflection of|it|abbaluginare||2|p|pres|indc|;|2|p|impr}}

===Etymology 2===

====Participle====
{{head|it|past participle form|g=f-p}}

# {{feminine plural of|it|abbaluginato}}

====Adjective====
{{head|it|adjective form}}

# {{adj form of|it|abbaluginato||f|p}}


11. [[abbarbicati]]:


===Verb===
{{head|it|verb form|cat2=past participle forms}}

# {{masculine plural of|it|abbarbicato}}
# {{inflection of|it|abbarbicarsi||2|s|impr}}


should be


===Etymology 1===

====Participle====
{{head|it|past participle form|g=m-p}}

# {{masculine plural of|it|abbarbicato}}

===Etymology 2===

====Verb====
{{head|it|verb form}}

# {{inflection of|it|abbarbicarsi||2|s|impr}}


11a. [[affaticati]]:


===Verb===
{{head|it|verb form|g=m}}

# {{plural of|it|affaticato}}
# {{inflection of|it|affaticarsi||2|s|impr}}

[[Category:Italian past participle forms]]


should be


===Etymology 1===

====Participle====
{{head|it|past participle form|g=m-p}}

# {{masculine plural of|it|affaticato}}

===Etymology 2===

====Verb====
{{head|it|verb form}}

# {{inflection of|it|affaticarsi||2|s|impr}}



12. [[abbassata]]:


==Italian==

===Pronunciation===
{{it-pr|abbassàta}}

===Etymology 1===
{{suf|it|abbassare|ata}}

====Noun====
{{it-noun|f}}

# the action of [[lower]]ing; the effect of having lowered
# the [[downwards]] movement of a [[loom]]'s [[heddle]]s
# {{lb|it|figure roller skating}} an [[exercise]] performed while standing on a single foot

====References====
* {{R:it:Trec}}

===Etymology 2===
{{nonlemma}}

====Participle====
{{head|it|past participle form}}

# {{feminine singular of|it|abbassato}}

{{C|it|Weaving}}


maybe can't handle multiple Etymology sections at first?


13. [[abrase]]:


===Verb===
{{head|it|verb form|cat2=past participle forms}}

# {{inflection of|it|abradere||3|s|phis}}

===Noun===
{{head|it|noun form|g=f-p}}

# {{plural of|it|abraso}}

===Anagrams===
* {{anagrams|it|a=aabers|basare|baserà}}


should be


...


14. [[abrasi]]:


==Italian==

===Verb===
{{head|it|verb form}}

# {{inflection of|it|abradere||1|s|phis}}

===Participle===
{{head|it|past participle form}}

# {{masculine plural of|it|abraso}}

===Anagrams===
* {{anagrams|it|a=aabirs|basirà|brasai}}


should be


...


15. [[accese]]:


===Pronunciation===
{{it-pr|accése,#accé[s]e<ref:{{R:it:DiPI|acceso}}>}}

===Verb===
{{head|it|verb form|cat2=past participle forms}}

# {{inflection of|it|accendere||3|s|phis}}
# {{feminine plural of|it|acceso}}

===References===
<references />


should be


...


16. [[alienate]]:


===Adjective===
{{head|it|adjective form|g=f-p}}

# {{feminine plural of|it|alienato}}

===Noun===
{{head|it|noun form|g=f}}

# {{plural of|it|alienata}}

===Verb===
{{head|it|verb form}}

# {{inflection of|it|alienare||2|p|pres|ind|;|2|p|imp|;|f|p|past|part}}

===Anagrams===
* {{anagrams|it|a=aaeeilnt|aleniate|aneliate}}

[[Category:Italian past participle forms]]


should be


===Etymology 1===

====Verb====
{{head|it|verb form}}

# {{inflection of|it|alienare||2|p|pres|indc|;|2|p|impr}}

===Etymology 2===

====Participle====
{{head|it|past participle form|g=f-p}}

# {{feminine plural of|it|alienato}}

====Adjective====
{{head|it|adjective form|g=f-p}}

# {{adj form of|it|alienato||f|p}}

===Etymology 3===

====Noun====
{{head|it|noun form|g=f}}

# {{plural of|it|alienata}}

===Anagrams===
* {{anagrams|it|a=aaeeilnt|aleniate|aneliate}}



17. [[alzati]]:


==Italian==

===Verb===
{{head|it|past participle form|g=m-p}}

# {{masculine plural past participle of|it|alzare|nocat=1}}

===Verb===
{{head|it|combined form}}

# {{n-g|Compound of imperative (tu form) of}} '''[[alzare]]''' ''and'' '''[[ti]]'''; [[get up]]!


should be


...
"""

participle_inflections = [
  {"inflection": {"f", "s"}, "name": "feminine singular", "ending": "a", "gender": "f-s"},
  {"inflection": {"m", "p"}, "name": "masculine plural", "ending": "i", "gender": "m-p"},
  {"inflection": {"f", "p"}, "name": "feminine plural", "ending": "e", "gender": "f-p"},
]

participle_form_names_to_properties = {props["name"]: props for props in participle_inflections}
participle_ending_to_properties = {props["ending"]: props for props in participle_inflections}

class BreakException(Exception):
  pass

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Italian", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  def verify_lang(t, lang=None):
    lang = lang or getparam(t, "1")
    if lang != "it":
      pagemsg("WARNING: Saw {{%s}} for non-Italian language: %s" % (tname(t), unicode(t)))
      raise BreakException()

  def verify_verb_lemma(t, term):
    if not re.search("(re|rsi)$", term):
      pagemsg("WARNING: Term %s doesn't look like an infinitive: %s" % (term, unicode(t)))
      raise BreakException()

  def verify_past_participle(t, term):
    if not re.search("[ts]o$", term):
      pagemsg("WARNING: Term %s doesn't look like a past participle: %s" % (term, unicode(t)))
      raise BreakException()

  def verify_past_participle_inflection(t, name, ending):
    if not re.search("[ts]%s$" % ending, pagetitle):
      pagemsg("WARNING: Found %s past participle form but page title doesn't have the correct form: %s" % (
        name, unicode(t)))
      raise BreakException()

  def verify_form_for_correct_lemma(t, pplemma):
    should_be_lemma = pagetitle[:-1] + "o"
    if should_be_lemma != pplemma:
      pagemsg("WARNING: Found past participle form for incorrect lemma %s, should be %s: %s" % (
        pplemma, should_be_lemma, unicode(t)))
      raise BreakException()

  def check_unrecognized_params(t, allowed_params):
    for param in t.params:
      pn = pname(param)
      pv = unicode(param.value)
      if pn not in allowed_params:
        pagemsg("WARNING: Saw unrecognized param %s=%s: %s" % (pn, pv, unicode(t)))
        raise BreakException()

  for k in xrange(2, len(subsections), 2):
    if re.search("==(Verb|Participle)==", subsections[k - 1]):
      # Make sure that we're dealing with a potential participle
      maybe_saw_participle = True
      parsed = blib.parse_text(subsections[k])
      for t in parsed.filter_templates():
        tn = tname(t)
        def getp(param):
          return getparam(t, param)

        if (tn == "head" and getp("1") == "it" and getp("2") in ["verb form", "past participle form", "past participle"]
            or tn == "it-pp"):
          maybe_saw_participle = True
          break

      if not maybe_saw_participle:
        continue

      this_sec_notes = []
      newsubsecheader = subsections[k - 1]
      newsubseck = subsections[k]
      try:
        # First split out any participle forms from {{inflection of}}
        parsed = blib.parse_text(newsubseck)
        for t in parsed.filter_templates():
          tn = tname(t)
          def getp(param):
            return getparam(t, param)

          def handle_past_participle(term):
            normalized_forms.append("{{past participle of|it|%s}}" % term)

          def handle_participle_inflection(term, desc, ending):
            normalized_forms.append("{{%s of|it|%s}}" % (desc, term))

          def handle_participle_inflection_for_verb(term, desc, ending):
            verify_verb_lemma(t, term)
            verify_past_participle_inflection(t, desc, ending)
            normalized_forms.append("{{%s of|it|%s}}" % (desc, pagetitle[:-1] + "o"))

          if tn in infltags.generic_inflection_of_templates:
            addltemp = None
            addltemp_arg = None
            removed_tag_set = None
            tags, params, lang, term, tr, alt = (
              infltags.extract_tags_and_nontag_params_from_inflection_of(t, this_sec_notes)
            )
            verify_lang(t, lang)
            if params or tr or alt:
              pagemsg("WARNING: Saw extra parameters in {{%s}}, skipping: %s" % (tn, unicode(t)))
              raise BreakException()
            tag_sets = infltags.split_tags_into_tag_sets(tags)
            filtered_tag_sets = []
            did_remove = False
            for tag_set in tag_sets:
              newtemp = None
              tag_set_set = {"part" if tag == "ptcp" else tag for tag in tag_set}
              if any(re.search("[123]", tag) for tag in tag_set):
                filtered_tag_sets.append(tag_set)
              elif tag_set_set == {"p"}:
                # We will convert this again to {{masculine/feminine plural of}}, which will verify any issues
                newtemp = "plural of"
              elif tag_set_set == {"past", "part"} or tag_set_set == {"m", "s", "past", "part"}:
                # We will verify any issues below for the converted template
                newtemp = "past participle of"
              else:
                for inflection in participle_inflections:
                  infl_tags = inflection["inflection"]
                  name = inflection["name"]
                  ending = inflection["ending"]
                  if tag_set_set == infl_tags:
                    # We will verify any issues below for the converted template
                    newtemp = "%s of" % name
                    break
                  elif tag_set_set == infl_tags | {"past", "part"}:
                    verify_past_participle_inflection(t, name, ending)
                    # We will convert this again to {{masculine/feminine plural of}} or {{feminine singular of}},
                    # which will verify any issues
                    newtemp = "%s past participle of" % name
                    break
                else: # no break
                  pagemsg("WARNING: Unrecognized non-personal tag set %s: %s" % ("|".join(tag_set), unicode(t)))
                  raise BreakException()
              if newtemp:
                if addltemp:
                  pagemsg("WARNING: Saw more than one past participle form in {{%s}}: {{%s|it|%s}} and {{%s|it|%s}}" % (
                    tn, addltemp, addltemp_arg, newtemp, term))
                  raise BreakException()
                addltemp = newtemp
                addltemp_arg = term
                removed_tag_set = tag_set

            if addltemp and not filtered_tag_sets:
              blib.set_template_name(t, addltemp)
              del t.params[:]
              t.add("1", "it")
              t.add("2", addltemp_arg)
              this_sec_notes.append("replace {{%s}} with {{%s}}" % (tn, addltemp))
              newsubseck = unicode(parsed)
            elif filtered_tag_sets and not addltemp:
              new_tags = infltags.combine_tag_set_group(filtered_tag_sets)
              if new_tags != tags:
                infltags.put_back_new_inflection_of_params(t, this_sec_notes, new_tags, params, lang, term, tr, alt)
                this_sec_notes.append("clean {{%s}}" % tn)
                newsubseck = unicode(parsed)
            elif addltemp and filtered_tag_sets:
              new_tags = infltags.combine_tag_set_group(filtered_tag_sets)
              m = re.search(r"\A(.*)^([^\n]*)%s([^\n]*)\n(.*)\Z" % re.escape(unicode(t)), newsubseck, re.S | re.M)
              if not m:
                pagemsg("WARNING: Something wrong, can't find %s in <<%s>>" % (unicode(t), newsubseck))
                raise BreakException()
              before_lines, before_on_line, after_on_line, after_lines = m.groups()
              infltags.put_back_new_inflection_of_params(t, this_sec_notes, new_tags, params, lang, term, tr, alt)
              newsubseck = "%s%s%s%s\n%s{{%s|it|%s}}%s\n%s" % (
                before_lines, before_on_line, unicode(t), after_on_line, before_on_line, addltemp, addltemp_arg,
                after_on_line, after_lines)
              notes.append("remove %s from {{%s}} and replace with {{%s}}" % ("|".join(removed_tag_set), tn,
                addltemp))
            else:
              pagemsg("WARNING: Something wrong, no tag sets remain and no new templates added: %s" % unicode(t))
              raise BreakException()

        # Now replace {{masculine/feminine plural past participle of}}, {{feminine singular past participle of}} and
        # {{plural of}} with regular past participle inflection templates.
        parsed = blib.parse_text(newsubseck)

        for t in parsed.filter_templates():
          tn = tname(t)
          def getp(param):
            return getparam(t, param)

          if tn in ["feminine singular past participle of", "masculine plural past participle of",
              "feminine plural past participle of"]:
            name = tn.replace(" past participle of", "")
            nameprops = participle_form_names_to_properties[name]
            verify_past_participle_inflection(t, name, nameprops["ending"])
            verify_lang(t)
            check_unrecognized_params(t, ["1", "2", "nocat"])
            rmparam(t, "nocat")
            blib.set_template_name(t, "%s of" % name)
            t.add("2", pagetitle[:-1] + "o")
            this_sec_notes.append("convert {{%s|INF}} to {{%s of|PP}}" % (tn, name))
            newsubseck = unicode(parsed)

          if tn == "plural of":
            verify_lang(t)
            verify_past_participle(t, getp("2"))
            if not re.search("[ts][ei]$", pagetitle):
              pagemsg("WARNING: Found plural past participle form but page title doesn't have the correct form" % desc)
              raise BreakException()
            verify_form_for_correct_lemma(t, getp("2"))
            if pagetitle.endswith("e"):
              newtn = "feminine plural of"
            else:
              newtn = "masculine plural of"
            rmparam(t, "nocat")
            blib.set_template_name(t, newtn)
            this_sec_notes.append("convert {{plural of}} to {{%s}}" % newtn)
            newsubseck = unicode(parsed)

          if tn in ["past participle of", "feminine singular of", "masculine plural of", "feminine plural of"]:
            verify_lang(t)
            if tn == "past participle of":
              verify_past_participle(t, pagetitle)
              verify_verb_lemma(t, getp("2"))
            else:
              name = tn[:-3] # remove " of"
              props = participle_form_names_to_properties[name]
              verify_past_participle(t, getp("2"))
              verify_past_participle_inflection(t, name, props["ending"])
              verify_form_for_correct_lemma(t, getp("2"))
            if getp("nocat"):
              rmparam(t, "nocat")
              this_sec_notes.append("remove nocat=1 from {{%s}}" % tn)
              newsubseck = unicode(parsed)

        # Now split {{inflection of}} and {{masculine/feminine plural of}}/{{feminine singular of}} under the same
        # header.
        parsed = blib.parse_text(newsubseck)

        saw_inflection_of = False
        saw_pp_form_of = False
        head_template = None
        for t in parsed.filter_templates():
          tn = tname(t)
          def getp(param):
            return getparam(t, param)
          if tn in infltags.generic_inflection_of_templates:
            saw_inflection_of = True
          if tn in ["feminine singular of", "masculine plural of", "feminine plural of"]:
            saw_pp_form_of = True
          if tn == "head":
            verify_lang(t)
            if getp("2") not in ["verb form", "past participle form", "past participle"]:
              pagemsg("WARNING: Saw strange headword POS in likely past participle form subsection: %s" % unicode(t))
              raise BreakException()
            if head_template:
              pagemsg("WARNING: Saw two head templates %s and %s in likely past participle form subsection" % (
                unicode(head_template), unicode(t)))
              raise BreakException()
            head_template = t
          if tn == "it-pp":
            if head_template:
              pagemsg("WARNING: Saw two head templates %s and %s in likely past participle form subsection" % (
                unicode(head_template), unicode(t)))
              raise BreakException()
            head_template = t

        if not head_template:
          pagemsg("WARNING: Didn't see head template in likely past participle form subsection: <<%s>>" % newsubseck)
          raise BreakException()

        if saw_inflection_of and saw_pp_form_of:
          if tname(head_template) == "it-pp":
            pagemsg("WARNING: Saw {{inflection of}} and past participle form under {{it-pp}}: <<%s>>" % newsubseck)
            raise BreakException()
          lines = newsubseck.rstrip("\n").split("\n")
          headword_line = None
          lines_for_inflection_of = []
          lines_for_pp_form = []
          last_line_is_pp_form = False
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
              if last_line_is_pp_form:
                lines_for_pp_form.append(line)
              else:
                lines_for_inflection_of.append(line)
            elif not line:
              last_line_is_pp_form = False
              lines_for_inflection_of.append(line)
            elif not line.startswith("#"):
              pagemsg("WARNING: Saw non-definition line in definition subsection: %s" % line)
              last_line_is_pp_form = False
              lines_for_inflection_of.append(line)
            elif re.search(r"\{\{\s*(%s)\s*\|" % "|".join(infltags.generic_inflection_of_templates), line):
              # An {{inflection of}} line
              last_line_is_pp_form = False
              lines_for_inflection_of.append(line)
            elif re.search(r"\{\{\s*(masculine plural|feminine plural|feminine singular) of\s*\|", line):
              # A past participle form-of line
              last_line_is_pp_form = True
              lines_for_pp_form.append(line)
            else:
              pagemsg("WARNING: Saw strange definition line in definition subsection: %s" % line)
              last_line_is_pp_form = False
              lines_for_inflection_of.append(line)

          if not headword_line:
            pagemsg("WARNING: Something wrong, didn't see headword line in subsection: <<%s>>" % newsubseck)
            raise BreakException()
          if headword_line != unicode(head_template):
            pagemsg("WARNING: Additional text on headword line besides headword template: %s" % headword_line)
            raise BreakException()
          if getparam(head_template, "2") == "past participle":
            pagemsg("WARNING: {{inflection of}} with {{head|it|past participle}}: %s" % headword_line)
            raise BreakException()
          check_unrecognized_params(head_template, ["1", "2", "head", "g"])
          head_template_head = getparam(head_template, "head")
          if head_template_head:
            head_template_head = "|head=%s" % head_template_head
          headword_line_1 = "{{head|it|verb form%s}}" % head_template_head
          pagetitle_ending = pagetitle[-1]
          if pagetitle_ending not in participle_ending_to_properties:
            pagemsg("WARNING: Something wrong, page title doesn't end in past participle form ending")
            raise BreakException()
          headword_line_2 = "{{head|it|past participle form%s|g=%s}}" % (
            head_template_head, participle_ending_to_properties[pagetitle_ending]["gender"])
          
          newsubsecheader = newsubsecheader.replace("Participle", "Verb")
          newsubseck_lines = (
            [headword_line_1] + lines_for_inflection_of
            + ["", newsubsecheader.replace("Verb", "Participle").rstrip("\n"), headword_line_2, ""]
            + lines_for_pp_form
          )
          newsubseck = "\n".join(newsubseck_lines) + "\n\n"
          this_sec_notes.append("split verb form and past participle form into two subsections")

############################# not finished

      except BreakException:
        # something went wrong, go to next subsection
        continue

      subsections[k] = newsubseck
      subsections[k - 1] = newsubsecheader
      notes.extend(this_sec_notes)

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)
  return text, notes

parser = blib.create_argparser("Clean up Italian past participle forms",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang Italian' and has no ==Italian== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

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

no_split_etym = {
  "corse",
  "fessa",
  "fesse",
  "perite",
  "provviste",
}

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

  def check_unrecognized_params(t, allowed_params, no_break=False):
    for param in t.params:
      pn = pname(param)
      pv = unicode(param.value)
      if pn not in allowed_params:
        pagemsg("WARNING: Saw unrecognized param %s=%s: %s" % (pn, pv, unicode(t)))
        if not no_break:
          raise BreakException()
        else:
          return False
    return True

  for k in range(2, len(subsections), 2):
    if re.search("==(Verb|Participle)==", subsections[k - 1]):
      # Make sure that we're dealing with a potential participle
      maybe_saw_participle = True
      parsed = blib.parse_text(subsections[k])
      for t in parsed.filter_templates():
        tn = tname(t)
        def getp(param):
          return getparam(t, param)

        if (tn == "head" and getp("1") == "it" and getp("2") in [
          "verb form", "participle form", "past participle form", "participle", "past participle"]
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
                made_a_change = True
                newsubseck = unicode(parsed)
              elif filtered_tag_sets and not addltemp:
                new_tags = infltags.combine_tag_set_group(filtered_tag_sets)
                if new_tags != tags:
                  infltags.put_back_new_inflection_of_params(t, this_sec_notes, new_tags, params, lang, term, tr, alt)
                  this_sec_notes.append("clean {{%s}}" % tn)
                  made_a_change = True
                  newsubseck = unicode(parsed)
              elif addltemp and filtered_tag_sets:
                new_tags = infltags.combine_tag_set_group(filtered_tag_sets)
                m = re.search(r"\A(.*)^([^\n]*)%s([^\n]*)\n(.*)\Z" % re.escape(unicode(t)), newsubseck, re.S | re.M)
                if not m:
                  pagemsg("WARNING: Something wrong, can't find %s in <<%s>>" % (unicode(t), newsubseck))
                  raise BreakException()
                before_lines, before_on_line, after_on_line, after_lines = m.groups()
                infltags.put_back_new_inflection_of_params(t, this_sec_notes, new_tags, params, lang, term, tr, alt)
                this_sec_notes.append("remove %s from {{%s}} and replace with {{%s}}" % ("|".join(removed_tag_set), tn,
                  addltemp))
                made_a_change = True
                newsubseck = "%s%s%s%s\n%s{{%s|it|%s}}%s\n%s" % (
                  before_lines, before_on_line, unicode(t), after_on_line, before_on_line, addltemp, addltemp_arg,
                  after_on_line, after_lines)
              else:
                pagemsg("WARNING: Something wrong, no tag sets remain and no new templates added: %s" % unicode(t))
                raise BreakException()
              
              if made_a_change:
                # Break the for-loop over templates. Re-parse and start again from the top.
                break

          if not made_a_change:
            # Break the 'while True' loop.
            break

        # Now replace {{masculine/feminine plural past participle of}}, {{feminine singular past participle of}} and
        # {{plural of}} with regular past participle inflection templates.
        parsed = blib.parse_text(newsubseck)

        actual_lemmas_seen = set()
        lemmas_seen = set()
        def add_lemma(lemma):
          actual_lemmas_seen.add(lemma)
          lemma = re.sub("rsi$", "re", lemma)
          lemmas_seen.add(lemma)

        for t in parsed.filter_templates():
          tn = tname(t)
          def getp(param):
            return getparam(t, param)

          if tn in ["feminine singular past participle of", "masculine plural past participle of",
              "feminine plural past participle of"]:
            verify_lang(t)
            check_unrecognized_params(t, ["1", "2", "nocat"])
            name = tn.replace(" past participle of", "")
            nameprops = participle_form_names_to_properties[name]
            if name == "feminine singular" and pagetitle.endswith("te"):
              # Known error; correct for it.
              pagemsg("Converting known erroneous 'feminine singular' to 'feminine plural': %s" %
                  unicode(t))
              name = "feminine plural"
              this_sec_notes.append("convert known erroneous 'feminine singular' to 'feminine plural'")
            else:
              verify_past_participle_inflection(t, name, nameprops["ending"])
            if getp("2").endswith("ato"):
              # Blah. Tons of SemperBlottoBot errors of this sort. Ignore them.
              pagemsg("Ignoring known error with past participle in place of infinitive: %s" % unicode(t))
              add_lemma(re.sub("ato$", "are", getp("2")))
            else:
              verify_verb_lemma(t, getp("2"))
              add_lemma(getp("2"))
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
              add_lemma(getp("2"))
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

        if len(lemmas_seen) > 1:
          pagemsg("WARNING: Saw past participles of multiple lemmas %s: <<%s>>" % (",".join(lemmas_seen), newsubseck))

        # Now remove {{past participle of}} for reflexive verbs when the non-reflexive equivalent also exists.
        parsed = blib.parse_text(newsubseck)
        templates_to_remove = []
        for t in parsed.filter_templates():
          tn = tname(t)
          def getp(param):
            return getparam(t, param)
          if tn == "past participle of":
            lemma = getp("2")
            if not check_unrecognized_params(t, ["1", "2"], no_break=True):
              continue
            if lemma.endswith("rsi") and re.sub("rsi$", "re", lemma) in actual_lemmas_seen:
              templates_to_remove.append((t, lemma))
        for t, lemma in templates_to_remove:
          newnewsubseck, did_replace = blib.replace_in_text(newsubseck, "# %s\n" % unicode(t), "", pagemsg,
            no_found_repl_check=True)
          if did_replace:
            this_sec_notes.append("remove past participle defn for reflexive %s because equivalent non-reflexive defn already exists" % lemma)
            newsubseck = newnewsubseck

        # Now split {{inflection of}} and {{masculine/feminine plural of}}/{{feminine singular of}} under the same
        # header. Also correct header POS and headword POS as needed, add gender to past participle form headword
        # lines, and convert {{head|it|past participle}} to {{it-pp}}.
        parsed = blib.parse_text(newsubseck)

        saw_inflection_of = False
        saw_pp_of = False
        saw_pp_form_of = False
        head_template = None
        for t in parsed.filter_templates():
          tn = tname(t)
          def getp(param):
            return getparam(t, param)
          if tn in infltags.generic_inflection_of_templates:
            saw_inflection_of = True
          if tn == "past participle of":
            saw_pp_of = True
          if tn in ["feminine singular of", "masculine plural of", "feminine plural of"]:
            saw_pp_form_of = True
          if tn == "head":
            verify_lang(t)
            if getp("2") not in ["verb form", "participle form", "past participle form", "participle", "past participle"]:
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

        if saw_pp_of:
          if saw_inflection_of or saw_pp_form_of:
            pagemsg("WARNING: Saw {{inflection of}} or past participle form along with {{past participle of}}: <<%s>>" % newsubseck)
            raise BreakException()
          if tname(head_template) == "head":
            check_unrecognized_params(head_template, ["1", "2", "head", "g"])
            pos = getparam(head_template, "2")
            if pos in ["participle", "past participle"]:
              head_param = getparam(head_template, "head")
              if head_param:
                pagemsg("WARNING: Template has head=%s, not converting to {{it-pp}}: %s" %
                  (head_param, unicode(head_template)))
              else:
                del head_template.params[:]
                blib.set_template_name(head_template, "it-pp")
                this_sec_notes.append("convert {{head|it|%s}} to {{it-pp}}" % pos)
                newsubseck = unicode(parsed)
            else:
              pagemsg("WARNING: Head template has strange POS for participle: %s" % unicode(head_template))
              raise BreakException()
          if "Verb" in newsubsecheader:
            newsubsecheader = newsubsecheader.replace("Verb", "Participle")
            this_sec_notes.append("correct ==Verb== to ==Participle== for participle")

        elif saw_inflection_of and saw_pp_form_of:
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
          if getparam(head_template, "2") in ["participle", "past participle"]:
            pagemsg("WARNING: {{inflection of}} with {{head|it|%s}}: %s" % (
              getparam(head_template, "2"), headword_line))
            raise BreakException()
          check_unrecognized_params(head_template, ["1", "2", "head", "g", "cat2"])
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

        elif saw_pp_form_of:
          if tname(head_template) == "it-pp":
            pagemsg("WARNING: Saw past participle form under {{it-pp}}: <<%s>>" % newsubseck)
            raise BreakException()
          check_unrecognized_params(head_template, ["1", "2", "head", "g", "cat2"])
          pos = getparam(head_template, "2")
          if pos in ["participle", "past participle"]:
            pagemsg("WARNING: Head template has strange POS for participle form: %s" % unicode(head_template))
            raise BreakException()
          if pos in ["verb form", "participle form"]:
            head_template.add("2", "past participle form")
            this_sec_notes.append("convert {{head|it|%s}} to {{head|it|past participle form}} for participle form" % pos)
            newsubseck = unicode(parsed)
          if head_template.has("cat2"):
            rmparam(head_template, "cat2")
            this_sec_notes.append("remove cat2=from headword template for participle form")
            newsubseck = unicode(parsed)
          pagetitle_ending = pagetitle[-1]
          if pagetitle_ending not in participle_ending_to_properties:
            pagemsg("WARNING: Something wrong, page title doesn't end in past participle form ending")
            raise BreakException()
          should_be_gender = participle_ending_to_properties[pagetitle_ending]["gender"]
          existing_gender = getparam(head_template, "g")
          if not existing_gender:
            head_template.add("g", should_be_gender)
            this_sec_notes.append("add g=%s to {{head|it|past participle form}} for participle form" % should_be_gender)
            newsubseck = unicode(parsed)
          else:
            head_template.add("g", should_be_gender)
            this_sec_notes.append("correct g=%s to g=%s in {{head|it|past participle form}} for participle form" % (
              existing_gender, should_be_gender))
            newsubseck = unicode(parsed)
          if "Verb" in newsubsecheader:
            newsubsecheader = newsubsecheader.replace("Verb", "Participle")
            this_sec_notes.append("correct ==Verb== to ==Participle== for participle form")

      except BreakException:
        # something went wrong, go to next subsection
        continue

      subsections[k] = newsubseck
      subsections[k - 1] = newsubsecheader
      notes.extend(this_sec_notes)

  secbody = "".join(subsections)

  # Remove duplicate lines, which may happen e.g. when converting the following:

  # {{inflection of|it|affrettare||f|s|past|part}}
  # {{inflection of|it|affrettarsi||f|s|past|part}}

  # which becomes

  # {{feminine singular of|it|affrettato}}
  # {{feminine singular of|it|affrettato}}

  newsecbody = blib.rsub_repeatedly(r"^(#.*\n)\1", r"\1", secbody, 0, re.M)
  if newsecbody != secbody:
    notes.append("remove duplicate lines")
    secbody = newsecbody

  # Now split etym sections as needed.

  def extract_pos_and_lemma(subsectext, lemma_pos, head_lemma_poses, head_nonlemma_poses, special_templates, allowable_form_of_templates):
    parsed = blib.parse_text(subsectext)
    pos = None
    lemma = None
    for t in parsed.filter_templates():
      tn = tname(t)
      def getp(param):
        return getparam(t, param)
      if tn == "head":
        verify_lang(t)
        if pos:
          pagemsg("WARNING: Saw two headwords: <<%s>>" % subsectext)
          raise BreakException()
        pos = getp("2")
        if pos in head_lemma_poses:
          lemma = True
        elif pos in head_nonlemma_poses:
          pass
        else:
          pagemsg("WARNING: Strange pos=%s for %s: <<%s>" % (pos, lemma_pos, subsectext))
          raise BreakException()
      if tn in special_templates:
        if pos:
          pagemsg("WARNING: Saw two headwords: <<%s>>" % subsectext)
          raise BreakException()
        pos = special_templates[tn]
        if not pos.endswith(" form"):
          lemma = True
      if tn in allowable_form_of_templates or tn in infltags.generic_inflection_of_templates:
        verify_lang(t)
        if pos is None:
          pagemsg("WARNING: Didn't see headword template in %s section: <<%s>>" % (lemma_pos, subsectext))
          raise BreakException()
        if lemma is True:
          pagemsg("WARNING: Saw form-of template %s in lemma %s section: <<%s>>" % (unicode(t), lemma_pos, subsectext))
          raise BreakException()
        if lemma:
          pagemsg("WARNING: Saw two form-of templates in lemma %s section, second is %s: <<%s>>" %
            (lemma_pos, unicode(t), subsectext))
        lemma = getp("2")
    if lemma is None:
      pagemsg("WARNING: Unable to locate lemma in nonlemma %s section: <<%s>>" % (lemma_pos, subsectext))
      raise BreakException()
    return pos, lemma

  def contains_any(lst, items):
    return any(item in lst for item in items)

  text_before_etym_sections = []
  text_for_etym_sections = []
  this_notes = []

  def process_etym_section(secno, sectext, is_etym_section):
    split_etym_sections = []
    goes_in_all_at_top = []
    goes_at_top_of_first_etym_section = ""
    last_etym_section = None
    subsections = re.split("(^==+[^=\n]+==+\n)", sectext, 0, re.M)
    if not is_etym_section:
      text_before_etym_sections.append(subsections[0])
    else:
      goes_at_top_of_first_etym_section = subsections[0]
    for k in range(2, len(subsections), 2):
      pos = None
      lemma = None
      if "=Pronunciation=" in subsections[k - 1]:
        if is_etym_section:
          goes_in_all_at_top.append(k)
        else:
          text_before_etym_sections.append(subsections[k - 1])
          text_before_etym_sections.append(subsections[k])
      elif "=Etymology=" in subsections[k - 1]:
        if is_etym_section:
          pagemsg("WARNING: Saw =Etymology= in etym section")
          raise BreakException()
        goes_at_top_of_first_etym_section = subsections[k]
      elif "=Alternative forms=" in subsections[k - 1]:
        # If =Alternative forms= at top, treat like =Pronunciation=; otherwise, append to
        # end of last etym section.
        if last_etym_section is None:
          if is_etym_section:
            goes_in_all_at_top.append(k)
          else:
            text_before_etym_sections.append(subsections[k - 1])
            text_before_etym_sections.append(subsections[k])
        else:
          existing_poses, existing_lemmas, existing_sections = split_etym_sections[last_etym_section]
          existing_sections.append((k, None))
      elif "=Adjective=" in subsections[k - 1]:
        pos, lemma = extract_pos_and_lemma(subsections[k], "adjective", {"adjective"}, {"adjective form"},
            {"it-adj": "adjective", "it-adj-sup": "adjective", "it-adj-form": "adjective form"},
            {"adj form of", "plural of", "masculine plural of", "feminine singular of", "feminine plural of"})
      elif "=Participle=" in subsections[k - 1]:
        pos, lemma = extract_pos_and_lemma(subsections[k], "participle", {"participle", "present participle", "past participle"},
            {"participle form", "past participle form"},
            {"it-pp": "past participle"},
            {"masculine plural of", "feminine singular of", "feminine plural of"})
      elif "=Noun=" in subsections[k - 1]:
        pos, lemma = extract_pos_and_lemma(subsections[k], "noun", {"noun"}, {"noun form"},
            {"it-noun": "noun", "it-plural noun": "noun"}, {"noun form of", "plural of"})
      elif "=Verb=" in subsections[k - 1]:
        # FIXME, handle {{it-compound of}}
        pos, lemma = extract_pos_and_lemma(subsections[k], "verb", {"verb"}, {"verb form"},
            {"it-verb": "verb"}, {"verb form of"})
      elif "=Adverb=" in subsections[k - 1]:
        pos, lemma = extract_pos_and_lemma(subsections[k], "adverb", {"adverb"}, [],
            {"it-adv": "adverb"}, [])
      elif "=Interjection=" in subsections[k - 1]:
        pos, lemma = extract_pos_and_lemma(subsections[k], "interjection", {"interjection"}, [],
            {}, [])
      elif "=Preposition=" in subsections[k - 1]:
        pos, lemma = extract_pos_and_lemma(subsections[k], "preposition", {"preposition"}, [],
            {}, [])
      elif "=Conjunction=" in subsections[k - 1]:
        pos, lemma = extract_pos_and_lemma(subsections[k], "conjunction", {"conjunction"}, [],
            {}, [])
      elif re.search(r"=\s*(Synonyms|Antonyms|Hyponyms|Hypernyms|Coordinate terms|Derived terms|Related terms|Descendants|Usage notes|References|Further reading|See also|Conjugation|Declension|Inflection)\s*=", subsections[k - 1]):
        if last_etym_section is None:
          pagemsg("WARNING: Saw section header %s without preceding lemma or non-lemma form" %
              subsections[k - 1].strip())
          raise BreakException()
        existing_poses, existing_lemmas, existing_sections = split_etym_sections[last_etym_section]
        existing_sections.append((k, None))
      else:
        pagemsg("WARNING: Unrecognized section header: %s" % subsections[k - 1].strip())
        raise BreakException()

      if pos:
        for etym_section_no, (existing_poses, existing_lemmas, existing_sections) in enumerate(split_etym_sections):
          ok_to_group = False
          if pos in ["participle form", "past participle form", "adjective form"] and pagetitle.endswith("a"):
            if contains_any(existing_poses, ["noun"]):
              for existing_section, existing_section_pos in existing_sections:
                if existing_section_pos == "noun":
                  parsed = blib.parse_text(subsections[existing_section])
                  for t in parsed.filter_templates():
                    tn = tname(t)
                    def getp(param):
                      return getparam(t, param)
                    if tn == "it-noun" and getp("m") or tn == "female equivalent of":
                      pagemsg("Grouping %s in section %s with likely female equivalent noun in section %s; defn is %s" % (
                        pos, k, existing_section, ";".join(blib.find_defns(subsections[existing_section], "it"))))
                      ok_to_group = True
                      break
                  if ok_to_group:
                    break
                  else:
                    pagemsg("Not grouping %s in section %s with likely non-female-equivalent noun in section %s; defn is %s" % (
                      pos, k, existing_section, ";".join(blib.find_defns(subsections[existing_section], "it"))))
          if not ok_to_group and pos == "noun" and pagetitle.endswith("a"):
            if contains_any(existing_poses, ["participle form", "adjective form"]):
              for existing_section, existing_section_pos in existing_sections:
                if existing_section_pos in ["participle form", "adjective form"]:
                  parsed = blib.parse_text(subsections[k])
                  for t in parsed.filter_templates():
                    tn = tname(t)
                    def getp(param):
                      return getparam(t, param)
                    if tn == "it-noun" and getp("m") or tn == "female equivalent of":
                      pagemsg("Likely female equivalent noun in section %s, grouping with %s in section %s; defn is %s" % (
                        k, existing_section_pos, existing_section, ";".join(blib.find_defns(subsections[k], "it"))))
                      ok_to_group = True
                      break
                  if ok_to_group:
                    break
                  else:
                    pagemsg("Likely non-female-equivalent noun in section %s, not grouping with %s in section %s; defn is %s" % (
                      k, existing_section_pos, existing_section, ";".join(blib.find_defns(subsections[k], "it"))))
          if not ok_to_group and ((
              (pos in ["participle", "past participle", "adjective", "adverb", "noun", "interjection",
                  "preposition", "conjunction"]
                and contains_any(existing_poses, ["participle", "past participle", "adjective", "adverb", "noun",
                  "interjection", "preposition", "conjunction"])
              or pos in ["participle form", "past participle form", "adjective form", "noun form"]
                and contains_any(existing_poses, ["participle form", "past participle form", "adjective form", "noun form"]))
              and lemma in existing_lemmas)
              or contains_any(existing_poses, [pos]) and lemma in existing_lemmas):
            existing_sections_text = ",".join(
              "%s:%s" % (existing_section, existing_section_pos) for existing_section, existing_section_pos in existing_sections)
            pagemsg("Grouping %s section %s with %s section(s) %s" % (pos, k, ",".join(existing_poses), existing_sections_text))
            ok_to_group = True

          if ok_to_group:
            existing_poses.append(pos)
            existing_sections.append((k, pos))
            existing_lemmas.append(lemma)
            last_etym_section = etym_section_no
            break

        else: # no break
          pagemsg("Creating new %s etym section %s for lemma %s" % (pos, k, lemma))
          split_etym_sections.append(([pos], [lemma], [(k, pos)]))
          last_etym_section = len(split_etym_sections) - 1

    if len(split_etym_sections) <= 1:
      text_for_etym_sections.append(sectext)
    else:
      first = True
      for existing_poses, existing_lemmas, existing_sections in split_etym_sections:
        etym_section_parts = []
        if first:
          etym_section_parts.append(goes_at_top_of_first_etym_section)
          if not goes_at_top_of_first_etym_section.endswith("\n\n"):
            etym_section_parts.append("\n")
          first = False
        else:
          etym_section_parts.append("\n")
        for goes_in_all_sec in goes_in_all_at_top:
          etym_section_parts.append(subsections[goes_in_all_sec - 1])
          etym_section_parts.append(subsections[goes_in_all_sec])
        for existing_section, existing_section_pos in existing_sections:
          etym_section_parts.append(subsections[existing_section - 1])
          etym_section_parts.append(subsections[existing_section])
        etym_section_text = "".join(etym_section_parts)
        if not is_etym_section:
          # Indent all subsections by one level.
          etym_section_text = re.sub("^=(.*)=$", r"==\1==", etym_section_text, 0, re.M)
        text_for_etym_sections.append(etym_section_text)
      if is_etym_section:
        this_notes.append("split ==Etymology %s== into %s sections" % (secno, len(split_etym_sections)))
      else:
        this_notes.append("split into %s Etymology sections" % len(split_etym_sections))

  if pagetitle in no_split_etym:
    pagemsg("Not splitting etymologies because page listed in no_split_etym")
  else:
    # Anagrams and such go after all etym sections and remain as such even if we start with non-etym-split text
    # and end with multiple etym sections.
    subsections_at_level_3 = re.split("(^===[^=\n]+===\n)", secbody, 0, re.M)
    for last_included_sec in range(len(subsections_at_level_3) - 1, 0, -2):
      if not re.search(r"^===\s*(References|See also|Derived terms|Related terms|Further reading|Anagrams)\s*=== *\n",
          subsections_at_level_3[last_included_sec - 1]):
        break
    text_after_etym_sections = "".join(subsections_at_level_3[last_included_sec + 1:])
    text_to_split_into_etym_sections = "".join(subsections_at_level_3[:last_included_sec + 1])

    has_etym_1 = "==Etymology 1==" in text_to_split_into_etym_sections

    try:
      if not has_etym_1:
        process_etym_section(1, text_to_split_into_etym_sections, is_etym_section=False)
        if len(text_for_etym_sections) <= 1:
          secbody = text_to_split_into_etym_sections + text_after_etym_sections
        else:
          secbody_parts = text_before_etym_sections
          for k, text_for_etym_section in enumerate(text_for_etym_sections):
            secbody_parts.append("===Etymology %s===\n" % (k + 1))
            secbody_parts.append(text_for_etym_section)
          secbody = "".join(secbody_parts) + text_after_etym_sections
          notes.extend(this_notes)
      else:
        etym_sections = re.split("(^===Etymology [0-9]+===\n)", text_to_split_into_etym_sections, 0, re.M)
        if len(etym_sections) < 5:
          pagemsg("WARNING: Something wrong, saw 'Etymology 1' but didn't see two etym sections")
        else:
          for k in range(2, len(etym_sections), 2):
            process_etym_section(k // 2, etym_sections[k], is_etym_section=True)
          if text_before_etym_sections:
            pagemsg("WARNING: Internal error: Should see empty text_before_etym_sections but saw: %s" %
                text_before_etym_sections)
          else:
            secbody_parts = [etym_sections[0]]
            for k, text_for_etym_section in enumerate(text_for_etym_sections):
              secbody_parts.append("===Etymology %s===\n" % (k + 1))
              secbody_parts.append(text_for_etym_section)
            secbody = "".join(secbody_parts) + text_after_etym_sections
            notes.extend(this_notes)

    except BreakException:
      # something went wrong, do nothing
      pass

  if "{{head|it|past participle form" in secbody:
    newsectail = re.sub(r"\[\[(?:Category|category|CAT):\s*Italian past participle forms\s*\]\]\n?", "", sectail)
    if newsectail != sectail:
      notes.append("remove redundant explicit 'Italian past participle forms' category")
      sectail = newsectail
    newsecbody = re.sub(r"\|cat2=past participle forms([|}])", r"\1", secbody)
    if newsecbody != secbody:
      notes.append("remove redundant explicit '|cat2=past participle forms'")
      secbody = newsecbody
  if re.search(r"\[\[(?:Category|category|CAT):\s*Italian past participle forms\s*\]\]", secbody + sectail):
    pagemsg("WARNING: Explicit category 'Italian past participle forms' still remains")
  if re.search(r"cat2\s*=\s*past participle forms", secbody + sectail):
    pagemsg("WARNING: Explicit 'cat2=past participle forms' still remains")

  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)

  # Condense 3+ newlines; may have been added when removing redundant categories.
  newtext = re.sub(r"\n\n+", "\n\n", text)
  if newtext != text:
    notes.append("condense 3+ newlines")
    text = newtext
  return text, notes

parser = blib.create_argparser("Clean up Italian past participle forms",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang Italian' and has no ==Italian== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site
import infltags

class BreakException(Exception):
  pass

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if not args.partial_page:
    retval = blib.find_modifiable_lang_section(text, "Italian", pagemsg)
    if retval is None:
      return
    sections, j, secbody, sectail, has_non_lang = retval
  else:
    sections = [text]
    j = 0
    secbody = text
    sectail = ""

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  for k in xrange(2, len(subsections), 2):
    if re.search("==(Verb|Participle)==", subsections[k - 1]):
      parsed = blib.parse_text(subsections[k])
      normalized_forms = []
      this_sec_notes = []
      try:
        for t in parsed.filter_templates():
          tn = tname(t)
          def getp(param):
            return getparam(t, param)

          def verify_lang(lang):
            if lang != "it":
              pagemsg("WARNING: Saw 'inflection of' for non-Italian language: %s" % unicode(t))
              raise BreakException()

          def verify_verb_lemma(term):
            if not re.search("(re|rsi)$", term):
              pagemsg("WARNING: Term %s doesn't look like an infinitive: %s" % (term, unicode(t)))
              raise BreakException()

          def verify_past_participle(term):
            if not re.search("[ts]o$", term):
              pagemsg("WARNING: Term %s doesn't look like a past participle: %s" % (term, unicode(t)))
              raise BreakException()

          def verify_past_participle_inflection(desc, ending):
            if not re.search("[ts]%s$" % ending, pagetitle):
              pagemsg("WARNING: Found %s past participle form but page title doesn't have the correct form" % desc)
              raise BreakException()

          def verify_form_for_correct_lemma(pplemma):
            should_be_lemma = pagetitle[:-1] + "o"
            if should_be_lemma != pplemma:
              pagemsg("WARNING: Found past participle form for incorrect lemma %s, should be %s" % (
                pplemma, should_be_lemma))
              raise BreakException()

          def handle_past_participle(term):
            verify_verb_lemma(term):
            if not re.search("[ts]o$", pagetitle):
              pagemsg("WARNING: Found past participle but page title doesn't have the correct form")
              raise BreakException()
            normalized_forms.append("{{past participle of|it|%s}}" % term)

          def handle_participle_inflection(term, desc, ending):
            verify_past_participle(term)
            verify_past_participle_inflection(desc, ending)
            verify_form_for_correct_lemma(term)
            normalized_forms.append("{{%s of|it|%s}}" % (desc, term))

          def handle_participle_inflection_for_verb(term, desc, ending):
            verify_verb_lemma(term)
            verify_past_participle_inflection(desc, ending)
            normalized_forms.append("{{%s of|it|%s}}" % (desc, pagetitle[:-1] + "o"))

          def handle_plural_of(term):
            verify_past_participle(term)
            if not re.search("[ts][ei]$", pagetitle):
              pagemsg("WARNING: Found plural past participle form but page title doesn't have the correct form" % desc)
              raise BreakException()
            verify_form_for_correct_lemma(term)
            if pagetitle.endswith("e"):
              normalized_forms.append("{{feminine plural of|it|%s}}" % term)
              break
            else:
              normalized_forms.append("{{masculine plural of|it|%s}}" % term)
              break

          participle_inflections = [
            [{"f", "s"}, "feminine singular", "a"],
            [{"m", "p"}, "masculine plural", "i"],
            [{"f", "p"}, "feminine plural", "e"],
          ]

          if tn == "head":
            verify_lang(getp("1"))
            if getp("2") not in ["verb form", "past participle form"]:
              pagemsg("WARNING: Skipping unknown POS: %s" % unicode(t))
            FIXME

          elif tn in infltags.inflection_of_templates:
            tags, params, lang, term, tr, alt = (
              infltags.extract_tags_and_nontag_params_from_inflection_of(t, this_sec_notes)
            )
            verify_lang(lang)
            tag_sets = infltags.split_tags_into_tag_sets(tags)
            filtered_tag_sets = []
            did_remove = False
            for tag_set in tag_sets:
              if any(re.search("[123]", tag) for tag in tag_set):
                filtered_tag_sets.append(tag_set)
              elif tag_set == {"p"}:
                handle_plural_of(term)
                did_remove = True
              elif tag_set == {"past", "part"} or tag_set == {"m", "s", "past", "part"}:
                handle_past_participle(term)
                did_remove = True
              else:
                tag_set = set(tag_set)
                for infl_tags, desc, ending in participle_inflections:
                  if tag_set == infl_tags:
                    handle_participle_inflection(term, desc, ending)
                    break
                  elif tag_set == infl_tags | {"past", "part"}:
                    handle_participle_inflection_for_verb(term, desc, ending)
                    break
                else: # no break
                  pagemsg("WARNING: Unrecognized non-personal tag set %s: %s" % ("|".join(tag_set), unicode(t)))
                  raise BreakException()
                did_remove = True
            new_tags = infltags.combine_tag_set_group(filtered_tag_sets)
            if did_remove or new_tags != tags:
              infltags.put_back_new_inflection_of_params(t, this_sec_notes, new_tags, params, lang, term, tr, alt)
              if did_remove:
                this_sec_notes.append("remove participle or participle form tags from {{%s}}" % tn)
              else:
                this_sec_notes.append("clean {{%s}}" % tn)

          elif tn == "past participle of":
            verify_lang(getp("1"))
            handle_past_participle(getp("2"))
          elif tn == "plural of":
            verify_lang(getp("1"))
            handle_plural_of(getp("2"))
          else:
            for infl_tags, desc, ending in participle_inflections:
              if tn == "%s of" % desc:
                verify_lang(getp("1"))
                handle_participle_inflection(getp("2"))
              elif tn == "%s past participle of" % desc:
                verify_lang(getp("1"))
                handle_participle_inflection_for_verb(getp("2"))
            else: # no break
              pagemsg("WARNING: Unrecognized template: %s" % unicode(t))
              raise BreakException()

        if len(normalized_forms) > 1:
          pagemsg("WARNING: Saw multiple past participles or past participle forms: %s" %
              ",".join(normalized_forms))
          raise BreakException


      
      except BreakException:
        # something went wrong, go to next subsection
        continue




def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace title")
    return

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    def getp(param):
      return getparam(t, param)
    if tn == "it-pp":
      origt = unicode(t)
      if getp("2") == "-":
        rmparam(t, "2")
        t.add("inv", "1")
      rmparam(t, "1")
      notes.append("convert {{it-pp}} to new form")
      if origt != unicode(t):
        pagemsg("Replaced %s with %s" % (origt, unicode(t)))

  return unicode(parsed), notes

parser = blib.create_argparser("Convert {{it-pp}} templates to new format",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang Italian' and has no ==Italian== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_refs=["Template:it-pp"])

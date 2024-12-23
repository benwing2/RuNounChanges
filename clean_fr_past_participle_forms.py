#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

class BreakException(Exception):
  pass

pp_to_irregular = {
  "du": "dû",
  #"cru": "crû", only applies to [[croître]] not [[croire]]
  "mu": "mû",
}

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "French", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  def verify_lang(t, lang=None):
    lang = lang or getparam(t, "1")
    if lang != "fr":
      pagemsg("WARNING: Saw {{%s}} for non-French language: %s" % (tname(t), str(t)))
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

  def verify_verb_lemma(t, term):
    if not re.search("(re|er|ir)$", term):
      pagemsg("WARNING: Term %s doesn't look like an infinitive: %s" % (term, str(t)))
      raise BreakException()

  def verify_past_participle_inflection(t, name, ending):
    if not re.search("[éiïust]%s$" % ending, pagetitle):
      pagemsg("WARNING: Found %s past participle form but page title doesn't have the correct form: %s" % (
        name, str(t)))
      raise BreakException()

  try:
    parsed = blib.parse_text(secbody)
    for t in parsed.filter_templates():
      tn = tname(t)
      def getp(param):
        return getparam(t, param)

      if tn in ["feminine singular past participle of", "masculine plural past participle of",
          "feminine plural past participle of"]:
        verify_lang(t)
        check_unrecognized_params(t, ["1", "2", "nocat"])
        name = tn.replace(" past participle of", "")
        if name == "feminine singular":
          expected_ending = "e"
        elif name == "masculine plural":
          expected_ending = "s"
        elif name == "feminine plural":
          expected_ending = "es"
        else:
          assert False
        verify_past_participle_inflection(t, name, expected_ending)
        verify_verb_lemma(t, getp("2"))
        rmparam(t, "nocat")
        blib.set_template_name(t, "%s of" % name)
        pp = pagetitle[:-len(expected_ending)]
        pp = pp_to_irregular.get(pp, pp)
        t.add("2", pp)
        notes.append("convert {{%s|fr|INF}} to {{%s of|fr|PP}}" % (tn, name))
    secbody = str(parsed)

  except BreakException:
    # something went wrong, do nothing
    pass

  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)
  return text, notes

parser = blib.create_argparser("Clean up French past participle forms",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang French' and has no ==French== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

class BreakException(Exception):
  pass

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Galician", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  def verify_lang(t, lang=None):
    lang = lang or getparam(t, "1")
    if lang != "gl":
      pagemsg("WARNING: Saw {{%s}} for non-Galician language: %s" % (tname(t), str(t)))
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
    if not re.search("([aeiíoóô]r)$", term):
      pagemsg("WARNING: Term %s doesn't look like an infinitive: %s" % (term, str(t)))
      raise BreakException()

  def verify_past_participle_inflection(t, name, ending):
    if not re.search("[dt]%s$" % ending, pagetitle):
      pagemsg("WARNING: Found %s past participle form but page title doesn't have the correct form: %s" % (
        name, str(t)))
      raise BreakException()

  try:
    parsed = blib.parse_text(secbody)
    for t in parsed.filter_templates():
      tn = tname(t)
      def getp(param):
        return getparam(t, param)

      if tn in ["inflection of", "infl of", "gl-verb form of"]:
        if tn == "gl-verb form of":
          check_unrecognized_params(t, "1")
        else:
          check_unrecognized_params(t, ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"])
          verify_lang(t)
        if pagetitle.endswith("a"):
          name = "feminine singular"
        elif pagetitle.endswith("os"):
          name = "masculine plural"
        elif pagetitle.endswith("as"):
          name = "feminine plural"
        else:
          pagemsg("WARNING: Unrecognized ending, not -a, -os or -as: %s" % str(t))
          raise BreakException()
        m = re.search("^(.*)([ao]s?)$", pagetitle)
        assert m
        base, expected_ending = m.groups()
        pp = base + "o"
        verify_past_participle_inflection(t, name, expected_ending)
        if tn == "gl-verb form of":
          inf = re.sub("^(.*)<.*?>$", r"\1", getp("1"))
        else:
          inf = getp("2")
        verify_verb_lemma(t, inf)
        del t.params[:]
        blib.set_template_name(t, "%s of" % name)
        t.add("1", "gl")
        t.add("2", pp)
        notes.append("convert {{%s%s|INF}} to {{%s of|gl|PP}}" % (tn, "|gl" if tn != "gl-verb form of" else "", name))
      elif tn in ["feminine singular past participle of", "masculine plural past participle of",
          "feminine plural past participle of"]:
        verify_lang(t)
        check_unrecognized_params(t, ["1", "2", "nocat"])
        name = tn.replace(" past participle of", "")
        if name == "feminine singular":
          expected_ending = "a"
        elif name == "masculine plural":
          expected_ending = "os"
        elif name == "feminine plural":
          expected_ending = "as"
        else:
          assert False
        pp = re.sub("^([ao]s?)$", "", pagetitle) + "o"
        verify_past_participle_inflection(t, name, expected_ending)
        verify_verb_lemma(t, getp("2"))
        rmparam(t, "nocat")
        blib.set_template_name(t, "%s of" % name)
        t.add("2", pp)
        notes.append("convert {{%s|gl|INF}} to {{%s of|gl|PP}}" % (tn, name))
    secbody = str(parsed)

  except BreakException:
    # something went wrong, do nothing
    pass

  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)
  return text, notes

parser = blib.create_argparser("Clean up Galician past participle forms",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang Galician' and has no ==Galician== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

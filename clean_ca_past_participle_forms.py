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

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Catalan", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  def verify_lang(t, lang=None):
    lang = lang or getparam(t, "1")
    if lang != "ca":
      pagemsg("WARNING: Saw {{%s}} for non-Catalan language: %s" % (tname(t), str(t)))
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
    if not re.search("([aeiïu]r(-se)?|re('s)?)$", term):
      pagemsg("WARNING: Term %s doesn't look like an infinitive: %s" % (term, str(t)))
      raise BreakException()

  try:
    parsed = blib.parse_text(secbody)
    for t in parsed.filter_templates():
      tn = tname(t)
      def getp(param):
        return getparam(t, param)

      if tn in ["inflection of", "infl of", "ca-verb form of"]:
        if tn == "ca-verb form of":
          check_unrecognized_params(t, "1")
        else:
          check_unrecognized_params(t, ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"])
          verify_lang(t)
        if pagetitle.endswith("a"):
          name = "feminine singular"
        elif pagetitle.endswith("es"):
          name = "feminine plural"
        elif re.search("([ot]s)$", pagetitle):
          name = "masculine plural"
        else:
          pagemsg("WARNING: Unrecognized ending, not -a, -es or -os/-ts: %s" % str(t))
          raise BreakException()
        m = re.search("^(.*)(a|[eot]s)$", pagetitle)
        assert m
        base, expected_ending = m.groups()
        if expected_ending == "ts":
          expected_ending = "s"
          base += "t"
        if re.search(".(c|m|pr|p|t)es$", base):
          base = base[:-2] + "ès"
        elif re.search(".(cl)os$", base):
          base = base[:-2] + "òs"
        elif re.search(".(f)os$", base):
          base = base[:-2] + "ós"
        elif base.endswith("s"):
          pagemsg("WARNING: Unhandled past participle ending in -s: %s" % str(t))
          raise BreakException()
        pp = re.sub("d$", "t", base)
        if tn == "ca-verb form of":
          inf = re.sub("^(.*)<.*?>$", r"\1", getp("1"))
        else:
          inf = getp("2")
        verify_verb_lemma(t, inf)
        del t.params[:]
        blib.set_template_name(t, "%s of" % name)
        t.add("1", "ca")
        t.add("2", pp)
        notes.append("convert {{%s%s|INF}} to {{%s of|ca|PP}}" % (tn, "|ca" if tn != "ca-verb form of" else "", name))
    secbody = str(parsed)

  except BreakException:
    # something went wrong, do nothing
    pass

  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)
  return text, notes

parser = blib.create_argparser("Clean up Catalan past participle forms",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang Catalan' and has no ==Catalan== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

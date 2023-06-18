#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

prefix_templates = ["pre", "prefix"]
suffix_templates = ["suf", "suffix"]
confix_templates = ["con", "confix"]
compound_templates = ["com", "compound"]

templates_to_convert = prefix_templates + suffix_templates + confix_templates + compound_templates + ["affix"]

hyphens = {
  "ar": "ـ",
  "fa": "ـ",
  "he": "־",
  "yi": "־",
}

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    lang = getparam(t, "1")
    sc = getparam(t, "sc")

    def get_hyphen(paramno):
      partsc = getparam(t, "sc%s" % (paramno - 1)) or getparam(t, "sc")
      if partsc == "Latn":
        return "-"
      partlang = getparam(t, "lang%s" % (paramno - 1)) or getparam(t, "1")
      return hyphens.get(partlang, "-")

    def make_suffix(paramno):
      langhyph = get_hyphen(paramno)
      def make_suffix_1(param, hyph):
        val = getparam(t, param)
        if val and not val.startswith(hyph) and not val.startswith("*" + hyph):
          if val.startswith("*"):
            val = "*" + hyph + val[1:]
          else:
            val = hyph + val
          t.add(param, val)
      make_suffix_1(str(paramno), langhyph)
      make_suffix_1("alt%s" % (paramno - 1), langhyph)
      make_suffix_1("tr%s" % (paramno - 1), "-")
      make_suffix_1("ts%s" % (paramno - 1), "-")

    def make_prefix(paramno):
      langhyph = get_hyphen(paramno)
      def make_prefix_1(param, hyph):
        val = getparam(t, param)
        if val and not val.endswith(hyph):
          val = val + hyph
          t.add(param, val)
      make_prefix_1(str(paramno), langhyph)
      make_prefix_1("alt%s" % (paramno - 1), langhyph)
      make_prefix_1("tr%s" % (paramno - 1), "-")
      make_prefix_1("ts%s" % (paramno - 1), "-")

    def make_non_affix(paramno, circumflex_if_empty=True):
      hyph = get_hyphen(paramno)
      val = getparam(t, str(paramno))
      if (circumflex_if_empty and not val) or val.startswith(hyph) or val.startswith("*" + hyph) or val.endswith(hyph):
        val = "^" + val
        t.add(str(paramno), val)

    if tn in compound_templates:
      for i in range(2, 31):
        make_non_affix(i, circumflex_if_empty=False)

    if tn in suffix_templates:
      make_non_affix(2)
      for i in range(3, 31):
        make_suffix(i)

    if tn in prefix_templates:
      if (not getparam(t, "3") and not getparam(t, "alt2") and not getparam(t, "tr2") and
          not getparam(t, "ts2")):
        # If only a prefix, make the next term into a bare ^ for compatibility.
        make_prefix(2)
        make_non_affix(3)
      else:
        for i in range(30, 2, -1):
          if (getparam(t, str(i)) or getparam(t, "alt%s" % (i - 1)) or
              getparam(t, "tr%s" % (i - 1)) or getparam(t, "ts%s" % (i - 1))):
            make_non_affix(i)
            break
        for j in range(2, i):
          make_prefix(j)

    if tn in confix_templates:
      make_prefix(2)
      if (getparam(t, "4") or getparam(t, "alt3") or getparam(t, "tr3") or getparam(t, "ts3")):
        make_non_affix(3)
        make_suffix(4)
      else:
        make_suffix(3)

    if tn in templates_to_convert:
      # Formerly we converted full templates to {{affix}} and abbreviated templates to {{af}}.
      blib.set_template_name(t, "af")
      notes.append("convert {{%s}} to {{af}}" % tn)

    if str(t) != origt:
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Convert *fix templates to {{af}}",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:%s" % template for template in templates_to_convert])

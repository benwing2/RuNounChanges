#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

prefix_templates = ["pre", "prefix"]
suffix_templates = ["suf", "suffix"]
confix_templates = ["con", "confix"]

abbreviated_templates_to_convert = ["pre", "suf", "con"]
full_templates_to_convert = ["prefix", "suffix", "confix"]

templates_to_move_lang = prefix_templates + suffix_templates + confix_templates + [
  "circumfix",
  "infix",
  "com", "compound"
]

hyphens = {
  "ar": u"ـ",
  "fa": u"ـ",
  "he": u"־",
  "yi": u"־",
}

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)
    if tn in templates_to_move_lang:
      lang = getparam(t, "lang")
      if lang:
        # Fetch all params.
        params = []
        for param in t.params:
          pname = unicode(param.name)
          if pname.strip() != "lang":
            params.append((pname, param.value, param.showkey))
        # Erase all params.
        del t.params[:]
        t.add("1", lang)
        # Put remaining parameters in order.
        for name, value, showkey in params:
          if re.search("^[0-9]+$", name):
            t.add(str(int(name) + 1), value, showkey=showkey, preserve_spacing=False)
          else:
            t.add(name, value, showkey=showkey, preserve_spacing=False)
        notes.append("move lang= to 1= in {{%s}}" % tn)

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

    def make_non_affix(paramno):
      hyph = get_hyphen(paramno)
      val = getparam(t, str(paramno))
      if not val or val.startswith(hyph) or val.startswith("*" + hyph) or val.endswith(hyph):
        val = "^" + val
        t.add(str(paramno), val)

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

    if tn in abbreviated_templates_to_convert:
      blib.set_template_name(t, "af")
      notes.append("convert {{%s}} to {{af}}" % tn)
    elif tn in full_templates_to_convert:
      blib.set_template_name(t, "affix")
      notes.append("convert {{%s}} to {{affix}}" % tn)

    if unicode(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, unicode(t)))

  return unicode(parsed), notes

parser = blib.create_argparser("Clean up *fix-related templates, moving lang= to 1= and renaming some to use {{affix}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in templates_to_move_lang:
  msg("Processing references to Template:%s" % template)
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)

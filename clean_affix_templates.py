#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

arabic_charset = "؀-ۿݐ-ݿࢠ-ࣿﭐ-﷽ﹰ-ﻼ"
hebrew_charset = "\u0590-\u05FF\uFB1D-\uFB4F"
tatweel = "ـ"
maqqef = "־"
zwnj = "\u200C"

prefix_templates = ["pre", "prefix"]
suffix_templates = ["suf", "suffix"]
confix_templates = ["con", "confix"]
circumfix_templates = ["circumfix"]
compound_templates = ["com", "compound"]

templates_to_convert = (prefix_templates + suffix_templates + confix_templates + compound_templates +
                        circumfix_templates + ["affix"])


def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  user_specified_templates_to_do = set(templates_to_convert) if not args.templates_to_do else set(args.templates_to_do.split(","))
  langcodes_to_do = None if not args.langcodes_to_do else set(args.langcodes_to_do.split(","))
  notes = []

  parsed = blib.parse_text(text)

  saw_circumfix = False

  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param)
    origt = str(t)
    tn = tname(t)
    lang = getp("1")
    sc = getp("sc")

    def get_display_hyphen(val, param):
      if re.search("[%s]" % arabic_charset, val):
        pagemsg("Saw Arabic chars in %s=%s, assuming tatweel is correct hyphen: %s" % (param, val, str(t)))
        return tatweel
      if re.search("[%s]" % hebrew_charset, val):
        pagemsg("Saw Hebrew chars in %s=%s, assuming maqqef is correct hyphen: %s" % (param, val, str(t)))
        return maqqef
      return "-"

    def get_template_hyphens(val, param, nowarn=False):
      if re.search("[%s]" % arabic_charset, val):
        if not nowarn:
          pagemsg("Saw Arabic chars in %s=%s, assuming tatweel is correct hyphen: %s" % (param, val, str(t)))
        return "[" + tatweel + zwnj + "-]"
      if re.search("[%s]" % hebrew_charset, val):
        if not nowarn:
          pagemsg("Saw Hebrew chars in %s=%s, assuming maqqef is correct hyphen: %s" % (param, val, str(t)))
        return "[" + maqqef + "]"
      return "[-]"

    def make_affix(paramno, is_prefix):
      def make_affix_2(val, param, hyph=None):
        link = None
        display = None
        m = re.search(r"^\[\[([^\[\]|]*)\|([^\[\]|]*)\]\]$", val)
        if m:
          link, display = m.groups()
        else:
          m = re.search(r"^\[\[([^\[\]|]*)\]\]$", val)
          if m:
            link = m.group(1)
            display = m.group(1)
        if link:
          if link == display:
            return make_affix_2(link, param + ".link", hyph)
          else:
            link = make_affix_2(link, param + ".link", hyph)
            display = make_affix_2(display, param + ".display", hyph)
            if link == display:
              return link
            else:
              return "[[%s|%s]]" % (link, display)
        if "[[" in val:
          pagemsg("WARNING: Embedded link in %s=%s, can't convert to %s: %s" % (
            param, val, "prefix" if is_prefix else "suffix", str(t)))
          return val
        dhyph = hyph or get_display_hyphen(val, param)
        thyph_re = hyph and "[%s]" % hyph or get_template_hyphens(val, param)
        if val:
          if is_prefix:
            if not re.search(thyph_re + "$", val):
              val = val + dhyph
          else:
            if not re.search(r"^\*?" + thyph_re, val):
              if val.startswith("*"):
                val = "*" + dhyph + val[1:]
              else:
                val = dhyph + val
        return val
      def make_affix_1(param, hyph=None):
        origval = getp(param)
        val = make_affix_2(origval, param, hyph)
        if val and origval != val:
          t.add(param, val)
      param = str(paramno)
      val = getp(param)
      if "<" in val:
        changed = False
        try:
          inline_mod = blib.parse_inline_modifier(val)
          if not inline_mod.mainval:
            pagemsg("WARNING: No main value associated with inline modifier: %s=%s: %s" % (param, val, str(t)))
          else:
            newval = make_affix_2(inline_mod.mainval, param + ".main")
            if newval != inline_mod.mainval:
              inline_mod.mainval = newval
              changed = True
            def frob_inline_modifier(mod, hyph=None):
              nonlocal changed
              modval = inline_mod.get_modifier(mod)
              if modval:
                new_modval = make_affix_2(modval, param + "." + mod, hyph)
                if new_modval != modval:
                  inline_mod.set_modifier(mod, new_modval)
                  changed = True
            frob_inline_modifier("alt")
            frob_inline_modifier("tr", "-")
            frob_inline_modifier("ts", "-")
            if changed:
              t.add(param, inline_mod.reconstruct_param())
        except blib.ParseException as e:
          pagemsg("WARNING: Parse exception processing %s=%s: %s: %s" % (param, val, str(e), str(t)))
      else:
        make_affix_1(param)
        make_affix_1("alt%s" % (paramno - 1))
        make_affix_1("tr%s" % (paramno - 1), "-")
        make_affix_1("ts%s" % (paramno - 1), "-")

    def make_suffix(paramno):
      make_affix(paramno, is_prefix=False)

    def make_prefix(paramno):
      make_affix(paramno, is_prefix=True)

    # For the specified numbered parameter, make sure it's interpreted as a non-affix in {{af}}. This means prepending
    # a circumflex if it looks like an affix. But if it's empty, do this only if circumflex_if_empty is True (not set
    # in conjunction with {{compound}}), and if it looks like an infix (hyphens on both sides), add circumflex only if
    # circumflex_if_infix is True (not set in conjunction with {{compound}}, which interprets infixes as such rather
    # than as non-affixes).
    def make_non_affix(paramno, circumflex_if_empty=True, circumflex_if_infix=True):
      val = getp(str(paramno))
      thyph_re = get_template_hyphens(val, str(paramno), nowarn=True)
      if circumflex_if_empty and not val:
        val = "^" + val
      elif (re.search(r"^\*?" + thyph_re, val) or re.search(thyph_re + "$", val)) and (
        circumflex_if_infix or not re.search(r"^\*?" + thyph_re + ".*" + thyph_re + "$", val)
      ):
        val = "^" + val
      if val:
        t.add(str(paramno), val)

    if tn in user_specified_templates_to_do:
      if langcodes_to_do and lang.strip() not in langcodes_to_do:
        pagemsg("Skipping template because lang code '%s' not among --langcodes-to-do: %s" % (lang.strip(), str(t)))
        continue
      if tn in compound_templates:
        for i in range(2, 31):
          make_non_affix(i, circumflex_if_empty=False, circumflex_if_infix=False)

      if tn in suffix_templates:
        make_non_affix(2)
        for i in range(3, 31):
          make_suffix(i)

      if tn in prefix_templates:
        if (not getp("3") and not getp("alt2") and not getp("tr2") and
            not getp("ts2")):
          # If only a prefix, make the next term into a bare ^ for compatibility.
          make_prefix(2)
          make_non_affix(3)
        else:
          for i in range(30, 2, -1):
            if (getp(str(i)) or getp("alt%s" % (i - 1)) or
                getp("tr%s" % (i - 1)) or getp("ts%s" % (i - 1))):
              make_non_affix(i)
              break
          for j in range(2, i):
            make_prefix(j)

      if tn in confix_templates:
        make_prefix(2)
        if (getp("4") or getp("alt3") or getp("tr3") or getp("ts3")):
          make_non_affix(3)
          make_suffix(4)
        else:
          make_suffix(3)

      if tn in circumfix_templates:
        saw_circumfix = True
        must_continue = False
        for param in t.params:
          pn = pname(param)
          if pn not in ["1", "2", "3", "4", "alt1", "alt2", "alt3", "tr1", "tr2", "tr3", "ts1", "ts2", "ts3", "t2",
                        "gloss2", "pos2", "pos3", "id2", "id3", "lit2", "lit", "nocat"]:
            pagemsg("WARNING: Unrecognized param %s=%s in %s" % (pn, str(param.value), origt))
            must_continue = True
            break
        if must_continue:
          continue

        p2 = getp("2")
        p4 = getp("4")
        if not p2 or not p4:
          pagemsg("WARNING: Circumfix template doesn't have both 2= and 4=: %s" % origt)
          continue
        if "<" in p2 or "<" in p4:
          pagemsg("WARNING: Can't handle inline modifiers in circumfix portions of circumfix template yet: %s" % origt)
          continue
        if "[" in p2 or "[" in p4:
          pagemsg("WARNING: Can't handle brackets in circumfix portions of circumfix template yet: %s" % origt)
          continue
        if getp("alt1") and not getp("alt3") or getp("alt3") and not getp("alt1"):
          pagemsg("WARNING: Circumfix template has alt1= but not alt3= or vice-versa: %s" % origt)
          continue
        if getp("tr1") and not getp("tr3") or getp("tr3") and not getp("tr1"):
          pagemsg("WARNING: Circumfix template has trl= but not tr3= or vice-versa: %s" % origt)
          continue
        if getp("ts1") and not getp("ts3") or getp("ts3") and not getp("ts1"):
          pagemsg("WARNING: Circumfix template has tsl= but not ts3= or vice-versa: %s" % origt)
          continue

        make_prefix(2)
        make_suffix(4)
        p2 = getp("2")
        p3 = getp("3")
        p4 = getp("4")
        alt1 = getp("alt1")
        alt2 = getp("alt2")
        alt3 = getp("alt3")
        tr1 = getp("tr1")
        tr2 = getp("tr2")
        tr3 = getp("tr3")
        ts1 = getp("ts1")
        ts2 = getp("ts2")
        ts3 = getp("ts3")
        t2 = getp("t2") or getp("gloss2")
        pos2 = getp("pos2")
        pos3 = getp("pos3")
        id2 = getp("id2")
        id3 = getp("id3")
        lit2 = getp("lit2")
        lit = getp("lit")
        nocat = getp("nocat")

        del t.params[:]
        t.add("1", lang)
        t.add("2", p3)
        if alt2:
          t.add("alt1", alt2)
        if tr2:
          t.add("tr1", tr2)
        if ts2:
          t.add("ts1", ts2)
        if t2:
          t.add("t1", t2)
        if id2:
          t.add("id1", id2)
        if pos2:
          t.add("pos1", pos2)
        if lit2:
          t.add("lit1", lit2)
        t.add("3", "%s %s" % (p2, p4))
        if alt1:
          t.add("alt2", "%s %s" % (alt1, alt3))
        if tr1:
          t.add("tr2", "%s %s" % (tr1, tr3))
        if ts1:
          t.add("ts2", "%s %s" % (ts1, ts3))
        if pos3:
          t.add("pos2", pos3)
        if id3:
          t.add("id2", id3)
        if lit:
          t.add("lit", lit)
        if nocat:
          t.add("nocat", nocat)

      if tn in templates_to_convert:
        # Formerly we converted full templates to {{affix}} and abbreviated templates to {{af}}.
        blib.set_template_name(t, "af")
        notes.append("convert {{%s|%s}} to {{af|%s}}" % (tn, lang, lang))

      if str(t) != origt:
        pagemsg("Replaced %s with %s" % (origt, str(t)))

  text = str(parsed)
  m = re.search(r"^.*\{\{af(fix)?\|.*\{\{af(fix)?\|.*$", text, re.M)
  if m:
    pagemsg("WARNING: Saw two occurrences of {{affix}} on the same line: %s" % m.group(0))
  return text, notes

parser = blib.create_argparser("Convert *fix templates to {{af}}",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--templates-to-do", help="Comma-separated list of templates to do; if unspecified, do all")
parser.add_argument("--langcodes-to-do", help="Comma-separated list of langcodes to do; if unspecified, do all")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:%s" % template for template in templates_to_convert])

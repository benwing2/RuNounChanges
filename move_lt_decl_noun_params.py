#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(pageindex, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (pageindex, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Lithuanian", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  parsed = blib.parse_text(secbody)
  for t in parsed.filter_templates():
    tn = tname(t)
    def getp(param):
      return getparam(t, param)
    if tn == "lt-decl-noun-stress":
      origt = str(t)
      p2 = getp("2")
      p4 = getp("4")
      p6 = getp("6")
      p8 = getp("8")
      p10 = getp("10")
      p12 = getp("12")
      p14 = getp("14")
      p16 = getp("16")
      p18 = getp("18")
      p20 = getp("20")
      p22 = getp("22")
      p24 = getp("24")
      p26 = getp("26")
      p28 = getp("28")
      must_continue = False
      for param in t.params:
        pn = pname(param)
        if not re.search("^[0-9]+$", pn) or int(pn) < 1 or int(pn) > 28:
          pagemsg("WARNING: Unrecognized parameter %s=%s in {{lt-decl-noun-stress}}" % (pn, str(param.value).strip()))
          must_continue = True
          break
      if must_continue:
        continue
      del t.params[:]
      t.add("1", p2, preserve_spacing=False)
      t.add("2", p4, preserve_spacing=False)
      t.add("3", p6, preserve_spacing=False)
      t.add("4", p8, preserve_spacing=False)
      t.add("5", p10, preserve_spacing=False)
      t.add("6", p12, preserve_spacing=False)
      t.add("7", p14, preserve_spacing=False)
      t.add("8", p16, preserve_spacing=False)
      t.add("9", p18, preserve_spacing=False)
      t.add("10", p20, preserve_spacing=False)
      t.add("11", p22, preserve_spacing=False)
      t.add("12", p24, preserve_spacing=False)
      t.add("13", p26, preserve_spacing=False)
      t.add("14", p28, preserve_spacing=False)
      blib.set_template_name(t, "lt-decl-noun")
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      notes.append("convert {{lt-decl-noun-stress}} to {{lt-decl-noun}}")

    if tn == "lt-decl-noun-unc-stress":
      origt = str(t)
      p2 = getp("2")
      p4 = getp("4")
      p6 = getp("6")
      p8 = getp("8")
      p10 = getp("10")
      p12 = getp("12")
      p14 = getp("14")
      must_continue = False
      for param in t.params:
        pn = pname(param)
        if not re.search("^[0-9]+$", pn) or int(pn) < 1 or int(pn) > 14:
          pagemsg("WARNING: Unrecognized parameter %s=%s in {{lt-decl-noun-stress}}" % (pn, str(param.value).strip()))
          must_continue = True
          break
      if must_continue:
        continue
      del t.params[:]
      t.add("1", p2, preserve_spacing=False)
      t.add("2", p4, preserve_spacing=False)
      t.add("3", p6, preserve_spacing=False)
      t.add("4", p8, preserve_spacing=False)
      t.add("5", p10, preserve_spacing=False)
      t.add("6", p12, preserve_spacing=False)
      t.add("7", p14, preserve_spacing=False)
      blib.set_template_name(t, "lt-decl-noun-unc")
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      notes.append("convert {{lt-decl-noun-unc-stress}} to {{lt-decl-noun-unc}}")

    if tn == "lt-decl-noun":
      origt = str(t)
      p1 = getp("1")
      p2 = getp("2")
      p3 = getp("3")
      p4 = getp("4")
      p5 = getp("5")
      p6 = getp("6")
      p7 = getp("7")
      p8 = getp("8")
      p9 = getp("9")
      p10 = getp("10")
      p11 = getp("11")
      p12 = getp("12")
      p13 = getp("13")
      p14 = getp("14")
      if (p1.strip() == "-" and p3.strip() == "-" and p5.strip() == "-" and p7.strip() == "-" and p9.strip() == "-" and
          p11.strip() == "-" and p13.strip() == "-"):
        must_continue = False
        for param in t.params:
          pn = pname(param)
          if not re.search("^[0-9]+$", pn) or int(pn) < 1 or int(pn) > 14:
            pagemsg("WARNING: Unrecognized parameter %s=%s in {{lt-decl-noun-stress}}" % (pn, str(param.value).strip()))
            must_continue = True
            break
        if must_continue:
          continue
        del t.params[:]
        t.add("1", p2, preserve_spacing=False)
        t.add("2", p4, preserve_spacing=False)
        t.add("3", p6, preserve_spacing=False)
        t.add("4", p8, preserve_spacing=False)
        t.add("5", p10, preserve_spacing=False)
        t.add("6", p12, preserve_spacing=False)
        t.add("7", p14, preserve_spacing=False)
        t.add("pl", "1")
        blib.set_template_name(t, "lt-decl-noun-unc")
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("convert plural-only {{lt-decl-noun}} to {{lt-decl-noun-unc}}")

  secbody = str(parsed)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)

  return text, notes

parser = blib.create_argparser("Convert {{lt-decl-noun-stress}} to {{lt-decl-noun}}", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
                           default_cats=["Lithuanian noun inflection-table templates"])

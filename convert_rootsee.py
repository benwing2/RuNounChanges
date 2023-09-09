#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, site

blib.getLanguageData()

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param)
    tn = tname(t)
    origt = str(t)
    if tn == "rootsee-old":
      must_continue = False
      for param in t.params:
        pn = pname(param)
        if pn not in ["1", "2", "3", "t", "id", "sc"]:
          # ignore sc=
          pagemsg("WARNING: Unrecognized param %s=%s in %s" % (pn, str(param.value), str(t)))
          must_continue = True
          break
      if must_continue:
        continue
      source = ""
      dest = getp("1")
      root = getp("2")
      arg3 = getp("3")
      id = getp("t") or getp("id")
      if arg3 in ["ine-pro", "PIE"]:
        source = "ine"
      elif dest in ["ine-pro", "PIE"]:
        dest = ""
      elif dest in ["nv", "ar", "mt", "akk", "tzm", "he", "pi"]:
        source = ""
      else:
        source = "ine"
      del t.params[:]
      if dest or source or root:
        t.add("1", dest)
      if source or root:
        t.add("2", source)
      if root:
        t.add("3", root)
      if id:
        t.add("id", id)
      blib.set_template_name(t, "rootsee")
      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("convert {{rootsee-old}} to {{rootsee}} in new format")
    tn = tname(t)
    if tn == "PIE root see":
      for param in t.params:
        pn = pname(param)
        if pn not in ["1", "head", "id"]:
          pagemsg("WARNING: Unrecognized param %s=%s in %s" % (pn, str(param.value), str(t)))
          break
      else: # no break
        root = getp("1") or getp("head")
        id = getp("id")
        del t.params[:]
        if root:
          t.add("1", "")
          t.add("2", "")
          t.add("3", root)
        if id:
          t.add("id", id)
        blib.set_template_name(t, "rootsee")
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("convert {{PIE root see}} to {{rootsee}}")
    tn = tname(t)
    if tn == "rootsee":
      must_continue = False
      for param in t.params:
        pn = pname(param)
        if pn not in ["1", "2", "3", "id"]:
          pagemsg("WARNING: Unrecognized param %s=%s in %s" % (pn, str(param.value), str(t)))
          must_continue = True
          break
      if must_continue:
        continue
      origt = str(t)
      dest = getp("1")
      source = getp("2")
      root = getp("3")
      id = getp("id")
      m = re.search("^(?:Reconstruction|Appendix):(.*)/(.*?)$", pagetitle)
      if m:
        default_lang, default_root = m.groups()
        default_root = re.sub("-$", "", default_root)
        if default_lang in blib.languages_byCanonicalName:
          default_source = blib.languages_byCanonicalName[default_lang]["code"]
        else:
          pagemsg("WARNING: Unable to find language %s" % default_lang)
          continue
      else:
        default_source = ""
        default_root = pagetitle
        default_root = re.sub("^.*?:", "", default_root)
        default_root = re.sub("^.*/", "", default_root)
        default_root = re.sub("-$", "", default_root)
      if dest and not source:
        source = dest
      if not dest and source == default_source:
        source = ""
      if source == dest:
        source = ""
      if root == default_root:
        root = ""
      del t.params[:]
      if dest or source or root:
        t.add("1", dest)
      if source or root:
        t.add("2", source)
      if root:
        t.add("3", root)
      if id:
        t.add("id", id)
      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("remove defaulted params from {{rootsee}}")

  return str(parsed), notes

parser = blib.create_argparser("Convert {{rootsee-old}}, {{rootsee}} and {{PIE root see}} to new-format {{rootsee}} and optimize params",
                               include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

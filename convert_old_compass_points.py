#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname
from convert_col_top_topN_to_col import simplify_link, convert_one_line

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  list_helper_2_t = None
  dont_remove_list_helper = False
  hypernym = None
  saw_compass = False
  converted_compass = False

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    def getp(param):
      return getparam(t, param).strip()
    if tn == "list helper 2":
      if list_helper_2_t:
        pagemsg("WARNING: Saw {{list helper 2}} twice, can't handle")
        return
      list_helper_2_t = t
      must_continue = False
      for param in t.params:
        pn = pname(param)
        if pn not in ["title", "list", "hypernym", "cat"]:
          pagemsg("WARNING: Unrecognized param %s=%s: %s" % (pn, str(param.value), str(t)))
          must_continue = True
          break
      if must_continue:
        continue
      title = getp("title")
      if blib.remove_links(title) != "compass points":
        pagemsg("WARNING: Unrecognized title in {{list helper 2}}, can't handle: %s" % origt)
        dont_remove_list_helper = True
        continue
      if getp("list"):
        pagemsg("WARNING: Non-empty list= in {{list helper 2}}, can't handle: %s" % origt)
        dont_remove_list_helper = True
        continue
      hypernym = getp("hypernym")

    if tn == "compass":
      if saw_compass:
        pagemsg("WARNING: Saw {{compass}} twice, not removing {{list helper 2}} if present")
        dont_remove_list_helper = True
      saw_compass = True
      must_continue = False
      for param in t.params:
        pn = pname(param)
        if not re.search("^(n|ne|nw|s|se|sw|w|e)[0-9]*(|alt|tr)$", pn) and pn != "lang" and pn != "1":
          pagemsg("WARNING: Unrecognized param %s=%s: %s" % (pn, str(param.value), str(t)))
          must_continue = True
          break
      if must_continue:
        continue
      lang = getp("lang") or getp("1")
      if not lang:
        pagemsg("WARNING: Found {{compass}} without language code: %s" % origt)
        continue
      if lang not in blib.languages_byCode:
        pagemsg("WARNING: Unknown language code %s in {{compass}}: %s" % (lang, origt))
        continue
      langname = blib.languages_byCode[lang]["canonicalName"]
      def process_direction(direc):
        terms = []
        for i in range(1, 20):
          param = "%s%s" % (direc, "" if i == 1 else i)
          term = getp(param)
          alt = getp(param + "alt")
          tr = getp(param + "tr")
          tr = re.sub("^''(.*)''$", r"\1", tr)
          tr = re.sub(r"^\[\[(.*)\]\]$", r"\1", tr)
          if alt:
            term = simplify_link(False, term, alt, None, lang, langname, pagemsg, expand_text)
            if tr:
              term = "%s<tr:%s>" % (term, tr)
          else:
            els, this_notes = convert_one_line(term, False, lang, langname, pagemsg, expand_text)
            if type(els) is str:
              pagemsg("WARNING: %s" % els)
            elif els is not None:
              if tr and len(els) > 1:
                pagemsg("WARNING: Multiple elements and translit in %s=, can't handle: %s" % (direc, origt))
                return None, []
              term = ",".join(els)
            if tr:
              if "<tr:" in term:
                pagemsg("WARNING: Saw external %str= and internal translit as well, can't handle: %s" % (
                  param, origt))
                return None, []
              term = "%s<tr:%s>" % (term, tr)
          if term:
            terms.append(term)
        return ",".join(terms), this_notes

      this_notes = []

      if hypernym:
        hypernym_els, this_this_notes = convert_one_line(hypernym, True, lang, langname, pagemsg, expand_text)
        if type(hypernym_els) is str or hypernym_els is None:
          pagemsg("WARNING: %s: hypernym=%s" % (hypernym_els or "Can't parse hypernym", hypernym))
          dont_remove_list_helper = True
          hypernym = None
        else:
          hypernym = ",".join(hypernym_els)

      directions = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
      direcparams = {}
      must_continue = False
      for direc in directions:
        val, this_this_notes = process_direction(direc)
        if val is None:
          must_continue = True
          break
        if val:
          this_notes.extend(this_this_notes)
          direcparams[direc] = val
      if must_continue:
        continue

      del t.params[:]
      t.name = "#invoke:topic list" # not blib.set_template_name(), which preserves whitespace
      t.add("1", "compass\n")
      if hypernym:
        t.add("hypernym", hypernym + "\n", preserve_spacing=False)
      for direc in directions:
        if direc in direcparams:
          t.add(direc, direcparams[direc] + "\n", preserve_spacing=False)
      notes.append("convert {{compass}} to [[Module:topic list]] compass invocation")
      notes.extend(this_notes)
      converted_compass = True

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  text = str(parsed)
  if list_helper_2_t and not dont_remove_list_helper and converted_compass:
    newtext, changed = blib.replace_in_text(text, re.escape(str(list_helper_2_t)) + "\n*", "", pagemsg,
                                            abort_if_warning=True, is_re = True)
    if changed:
      text = newtext
      notes.append("remove {{list helper 2}}, incorporating any hypernym into [[Module:topic list]] compass invocation")

  return text, notes

parser = blib.create_argparser("Convert old-style {{compass}} calls to use [[Module:topic list]]",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

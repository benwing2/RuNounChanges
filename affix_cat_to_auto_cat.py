#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

blib.getData()

possible_hyphens = u"-־ـ\u200c"
def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  pagemsg("Processing")

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "autocat":
      blib.set_template_name(t, "auto cat")
      notes.append("{{autocat}} -> {{auto cat}}")
    elif tn in ["prefix cat", "suffix cat", "circumfix cat", "infix cat", "interfix cat"]:
      m = re.search("^Category:(.*) ([a-z]+) ([a-z]+fix)ed with (.*)$", pagetitle)
      if not m:
        pagemsg("WARNING: Can't parse page title")
        continue
      langname, pos, affixtype, term_and_id = m.groups()
      m = re.search(r"^(.*?) \((.*)\)$", term_and_id)
      if m:
        term, id = m.groups()
      else:
        term, id = term_and_id, ""
      t_lang = getparam(t, "1")
      t_term = getparam(t, "2")
      t_alt = getparam(t, "3")
      t_pos = getparam(t, "pos")
      t_id = getparam(t, "id")
      t_tr = getparam(t, "tr")
      t_sort = getparam(t, "sort")
      t_sc = getparam(t, "sc")
      if langname not in blib.languages_byCanonicalName:
        pagemsg("WARNING: Unrecognized language name: %s" % langname)
        continue
      if blib.languages_byCanonicalName[langname]["code"] != t_lang:
        pagemsg("WARNING: Auto-determined code %s for language name %s != manually specified %s" % (
          blib.languages_byCanonicalName[langname]["code"], langname, t_lang))
        continue
      if tn[:-4] != affixtype:
        pagemsg("WARNING: Auto-determined affix type %s != manually specified %s" % (affixtype, tn[:-4]))
        continue

      def add_missing_hyphens(alt):
        hyph_c = "([" + possible_hyphens + "])"
        m = re.search(r"^(\*)(.*)$", alt)
        if m:
          althyp, altbase = m.groups()
        else:
          althyp, altbase = "", alt
        m = re.search(r"^(\*)(.*)$", term)
        if m:
          termhyp, termbase = m.groups()
        else:
          termhyp, termbase = "", term
        if affixtype == "suffix":
          m = re.search("^" + hyph_c, termbase)
          if m:
            initial_hyphen = m.group(1)
            if not altbase.startswith(initial_hyphen):
              alt = althyp + initial_hyphen + altbase
        elif affixtype == "prefix":
          m = re.search(hyph_c + "$", termbase)
          if m:
            final_hyphen = m.group(1)
            if not altbase.endswith(final_hyphen):
              alt = althyp + altbase + final_hyphen
        elif affixtype in ["infix", "interfix"]:
          m = re.search("^" + hyph_c + ".*" + hyph_c + "$", termbase)
          if m:
            initial_hyphen, final_hyphen = m.groups()
            if not altbase.startswith(initial_hyphen):
              altbase = initial_hyphen + altbase
            if not altbase.endswith(final_hyphen):
              altbase = altbase + final_hyphen
            alt = althyp + altbase
        return alt

      orig_t_term = t_term
      t_term = add_missing_hyphens(t_term)
      already_checked_t_alt = False
      if t_term != term:
        manual_entry_name = expand_text("{{#invoke:languages/templates|makeEntryName|%s|%s}}" % (t_lang, t_term))
        if manual_entry_name != term:
          pagemsg("WARNING: Can't match manually specified term %s (originally %s, entry name %s) to auto-determined term %s" % (
            t_term, orig_t_term, manual_entry_name, term))
          continue
        if t_alt:
          pagemsg("WARNING: Manually specified term %s has extra diacritics and alt=%s also specified, skipping" % (
            t_term, t_alt))
          continue
        t_alt = t_term
        already_checked_t_alt = True
      if t_id != id:
        pagemsg("WARNING: Auto-determined ID %s != manually specified %s" % (id, t_id))
        continue
      if (pos == "words" and t_pos not in ["", "word", "words"] or
          pos != "words" and t_pos != pos and t_pos + "s" != pos and (not t_pos.endswith("x") or t_pos + "es" != pos)):
        pagemsg("WARNING: Auto-determined pos %s doesn't match manually specified %s" % (pos, t_pos))
        continue
      if t_alt and not already_checked_t_alt:
        orig_t_alt = t_alt
        t_alt = add_missing_hyphens(t_alt)
        manual_entry_name = expand_text("{{#invoke:languages/templates|makeEntryName|%s|%s}}" % (t_lang, t_alt))
        if manual_entry_name != term:
          pagemsg("WARNING: Can't match manually specified alt %s (originally %s, entry name %s) to auto-determined term %s" % (
            t_alt, orig_t_alt, manual_entry_name, term))
          continue
      if t_sort:
        auto_entry_name = expand_text("{{#invoke:languages/templates|makeEntryName|%s|%s}}" % (t_lang, term))
        autosort = expand_text("{{#invoke:languages/templates|getByCode|%s|makeSortKey|%s}}" % (t_lang, auto_entry_name))
        manual_entry_name = expand_text("{{#invoke:languages/templates|makeEntryName|%s|%s}}" % (t_lang, add_missing_hyphens(t_sort)))
        manual_sort = expand_text("{{#invoke:languages/templates|getByCode|%s|makeSortKey|%s}}" % (t_lang, manual_entry_name))
        if manual_sort != autosort:
          pagemsg("Keeping sort key %s because canonicalized sort key %s based on it not same as canonicalized sort key %s based on term %s" % (
            t_sort, manual_sort, autosort, term))
        else:
          pagemsg("Discarding sort key %s because canonicalized sort key %s based on it same as canonicalized sort key based on term %s" % (
            t_sort, manual_sort, term))
          t_sort = ""

      must_continue = False
      all_existing_params = ["1", "2", "3", "tr", "pos", "id", "tr", "sc", "sort"]
      for param in t.params:
        pn = pname(param)
        if pn not in all_existing_params:
          pagemsg("WARNING: Unrecognized param %s=%s in affix cat: %s" % (pn, str(param.value), str(t)))
          must_continue = True
          break
      if must_continue:
        continue
      for param in all_existing_params:
        rmparam(t, param)
      blib.set_template_name(t, "auto cat")
      if t_alt:
        if t_alt == term:
          pagemsg("Not adding alt=%s because it's the same as the term" % t_alt)
        else:
          t.add("alt", t_alt)
      if t_tr:
        t.add("tr", t_tr)
      if t_sort:
        t.add("sort", t_sort)
      if t_sc:
        t.add("sc", t_sc)
      notes.append("convert {{%s}} to {{auto cat}}" % tn)

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Convert affix cat usages to {{auto cat}}",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

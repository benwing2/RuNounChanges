#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

global_params = [
  "bor", "lbor", "slb", "translit", "der", "clq", "cal", "calq", "calque", "pclq", "sml", "unc", "nolb", "sclb"
]
global_params_at_end = ["q", "alts"]
item_params = ["alt", "g", "gloss", "t", "id", "lit", "pos", "tr", "ts", "sc"]

def process_text_on_page(index, pagetitle, pagetext):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if not args.stdin:
    pagemsg("Processing")

  notes = []

  parsed = blib.parse_text(pagetext)
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in ["desc", "desctree", "descendant", "descendants tree"]:
      terms = blib.fetch_param_chain(t, "2")
      comma_in_terms = any("," in term for term in terms)
      if not comma_in_terms:
        continue
      must_continue = False
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if re.search("[a-z][0-9]", pn):
          pagemsg("WARNING: comma in terms but saw term-specific param %s=%s, skipping: %s" % (pn, pv, str(t)))
          must_continue = True
          break
        if "<" in pv:
          pagemsg("WARNING: Saw less-than in param %s=%s, skipping: %s" % (pn, pv, str(t)))
          must_continue = True
          break
        # g= is short enough and commonly occurs with nested params, so allow it to be split
        if pn != "g" and pn in item_params:
          pagemsg("WARNING: Saw term-specific item param %s=%s, skipping: %s" % (pn, pv, str(t)))
          must_continue = True
          break
      if must_continue:
        continue
      g = getparam(t, "g")
      new_terms = []
      can_remove_g = False
      for j, term in enumerate(terms):
        if ", " in term:
          if "[" not in term:
            pagemsg("WARNING: Saw multiple terms in a single param '%s' but no links, please verify it's OK to split: %s" % (term, str(t)))
          this_new_terms = re.split("([,;]) +", term)
          terms_to_append = []
          must_continue = False
          for i, new_term in enumerate(this_new_terms):
            if i % 2 == 1:
              continue
            left_q = None
            right_q = None
            term_g = None
            m = re.search(r"^\{\{(?:q|i|qual|qualifier)\|([^{}]*)\}\} +(.*)$", new_term)
            if m:
              left_q, new_term = m.groups()
            if not left_q:
              m = re.search(r"^\(([^()\[\]]*)\) +(.*)$", new_term)
              if m:
                left_q, new_term = m.groups()
            m = re.search(r"^(.*) +\{\{(?:q|i|qual|qualifier)\|([^{}]*)\}\}$", new_term)
            if m:
              new_term, right_q = m.groups()
            m = re.search(r"^(.*) +\{\{g\|([^{}]*)\}\}$", new_term)
            if m:
              new_term, term_g = m.groups()
              term_g = term_g.replace("|", ",")
            new_term = blib.remove_redundant_links(new_term)
            if "[" in new_term:
              pagemsg("WARNING: Still saw bracket in term '%s' after removing redundant ones: %s" % (new_term, str(t)))
            if "{" in new_term:
              pagemsg("WARNING: Still saw braces in term '%s' after removing qualifiers, not splitting: %s" % (new_term, str(t)))
              new_terms.append(term)
              must_continue = True
              break
            if left_q:
              new_term += "<q:%s>" % left_q
            if right_q:
              new_term += "<qq:%s>" % right_q
            if g and j == 0:
              if term_g:
                pagemsg("WARNING: Saw both overall g= and term-specific {{g|....}}, can't handle, not splitting: %s" % (new_term, str(t)))
                new_terms.append(term)
                must_continue = True
                break
              new_term += "<g:%s>" % g
            if term_g:
              new_term += "<g:%s>" % term_g
            if i > 0 and this_new_terms[i - 1] == ";":
              terms_to_append.append(";")
            if left_q and j + i > 0 and not (i > 0 and this_new_terms[i - 1] == ";"):
              # If there's a left qualifier, put a semicolon before the term unless we're the first term or we already
              # put a semicolon before the term.
              terms_to_append.append(";")
            terms_to_append.append(new_term)
            if right_q and (j < len(terms) - 1 or i < len(this_new_terms) - 1) and not (
                i < len(this_new_terms) - 1 and this_new_terms[i + 1] == ";"):
              # If there's a right qualifier, put a semicolon after the term unless we're the last term or there's
              # already a semicolon after the term.
              terms_to_append.append(";")
          if must_continue:
            continue
          new_terms.extend(terms_to_append)
          if j == 0:
            # If we're dealing with the first numbered param (corresponding to g=), and we got this far (i.e. didn't
            # terminate early due to a brace in the param value), we can remove g= as we've appended it to each split
            # term.
            can_remove_g = True
      blib.set_param_chain(t, new_terms, "2")
      if origt != str(t):
        notes.append("split nested terms in {{%s}}" % tn)
      if can_remove_g and t.has("g"):
        rmparam(t, "g")
        if g:
          notes.append("move g= to inline modifier on individual term(s) in {{%s}}" % tn)
        else:
          notes.append("remove redundant g= in {{%s}}" % tn)
      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Split multiple terms in a single param in {{desc}} into multiple params",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

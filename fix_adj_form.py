#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Fix up short adjective forms when possible, canonicalizing existing
# 'inflection of' and converting raw inflection to 'inflection of'

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping page")
    return

  text = str(page.text)
  notes = []
  already_canonicalized = False
  found_short_inflection_of = False
  warned_about_short = False

  foundrussian = False
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in range(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections, skipping page")
        return
      foundrussian = True

      # Try to canonicalize existing 'inflection of'
      parsed = blib.parse_text(sections[j])
      for t in parsed.filter_templates():
        if str(t.name) == "inflection of" and getparam(t, "lang") == "ru":
          # Fetch the numbered params starting with 3
          numbered_params = []
          for i in range(3,20):
            numbered_params.append(getparam(t, str(i)))
          while len(numbered_params) > 0 and not numbered_params[-1]:
            del numbered_params[-1]
          # Now canonicalize
          numparamstr = "/".join(numbered_params)
          canon_params = []
          while True:
            m = (re.search(r"^([mfn])/(?:s|\(singular\))/short(?: form|)$", numparamstr) or
                 re.search(r"^(?:s|\(singular\))/([mfn])/short(?: form|)$", numparamstr) or
                 re.search(r"^short(?: form|)/([mfn])/(?:s|\(singular\))$", numparamstr) or
                 re.search(r"^short(?: form|)/(?:s|\(singular\))/([mfn])$", numparamstr) or
                 re.search(r"^([mfn])/short(?: form|)/(?:s|\(singular\))$", numparamstr) or
                 re.search(r"^(?:s|\(singular\))/short(?: form|)/([mfn])$", numparamstr) or
                 re.search(r"^([mfn])/short(?: form|)$", numparamstr) or
                 re.search(r"^short(?: form|)/([mfn])$", numparamstr)
                 )
            if m:
              found_short_inflection_of = True
              canon_params = ["short", m.group(1), "s"]
              break
            m = (re.search(r"^(?:p|\(plural\))/short(?: form|)$", numparamstr) or
                 re.search(r"^short(?: form|)/(?:p|\(plural\))$", numparamstr)
                 )
            if m:
              found_short_inflection_of = True
              canon_params = ["short", "p"]
              break
            if "short" in numbered_params or "short form" in numbered_params:
              found_short_inflection_of = True
              warned_about_short = True
              pagemsg("WARNING: Apparent short-form 'inflection of' but can't canonicalize: %s" %
                  str(t))
            break
          if canon_params:
            origt = str(t)
            # Fetch param 1 and param 2. Erase all numbered params.
            # Put back param 1 and param 2 (this will put them after lang=ru),
            # then the replacements for the higher params.
            param1 = getparam(t, "1")
            param2 = getparam(t, "2")
            for i in range(19,0,-1):
              rmparam(t, str(i))
            t.add("1", param1)
            t.add("2", param2)
            for i, param in enumerate(canon_params):
              t.add(str(i+3), param)
            newt = str(t)
            if origt != newt:
              pagemsg("Replaced %s with %s" % (origt, newt))
              notes.append("canonicalized 'inflection of' for %s" % "/".join(canon_params))
            else:
              pagemsg("Apparently already canonicalized: %s" % newt)
              already_canonicalized = True
      sections[j] = str(parsed)

      # Try to add 'inflection of' to raw-specified singular inflection
      def add_sing_inflection_of(m):
        prefix = m.group(1)
        gender = {"masculine":"m", "male":"m", "feminine":"f", "female":"f",
            "neuter":"n", "neutral":"n"}[m.group(2).lower()]
        lemma = m.group(3)
        retval = prefix + "{{inflection of|lang=ru|%s||short|%s|s}}" % (lemma, gender)
        pagemsg("Replaced <%s> with %s" % (m.group(0), retval))
        notes.append("converted raw to 'inflection of' for short/%s/s" % gender)
        return retval
      newsec = re.sub(r"(# |\()'*(?:short |)(?:form of |)(masculine|male|feminine|female|neuter|neutral) (?:short |)(?:singular |)(?:short |)(?:form of|of|for)'* '*(?:\[\[|\{\{[lm]\|ru\|)(.*?)(?:\]\]|\}\})'*", add_sing_inflection_of,
          sections[j], 0, re.I)
      if newsec != sections[j]:
        found_short_inflection_of = True
      sections[j] = newsec

      if "short" in sections[j] and not found_short_inflection_of:
        m = re.search("^(.*short.*)$", sections[j], re.M)
        warned_about_short = True
        pagemsg("WARNING: Apparent raw-text short inflection, not converted: %s" %
            (m and m.group(1) or "Can't get line?"))

  if not notes and not already_canonicalized:
    pagemsg("Skipping, no short form found%s" % (
      warned_about_short and " (warning issued)" or " (no warning)"))

  return "".join(sections), notes

parser = blib.create_argparser("Add 'inflection of' for raw short adjective forms and canonicalize existing 'inflection of'",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian adjective forms"])

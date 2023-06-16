#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname
from collections import defaultdict

seen_projects = defaultdict(int)

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if blib.page_should_be_ignored(pagetitle):
    return

  if not args.stdin:
    pagemsg("Processing")

  notes = []
  subs = []
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = str(t)
    def getp(param):
      return getparam(t, param)
    tn = tname(t)
    textparts = []
    if tn == "projectlinks":
      sc = getp("sc").strip()
      for i in range(1, 10):
        project = getp(str(i)).strip()
        if project:
          page = getp("page%s" % i).strip()
          label = getp("label%s" % i).strip()
          lang = getp("lang%s" % i).strip()
          textparts.append("* {{projectlink|%s%s%s%s%s}}" % (project, "|%s" % page if page or label else "",
            "|%s" % label if label else "", "|lang=%s" % lang if lang else "", "|sc=%s" % sc if sc else""))
      subs.append((str(t), "\n".join(textparts)))
      notes.append("replace {{projectlinks}} with multiple calls to {{projectlink}}")

  for subfrom, subto in subs:
    text, replaced = blib.replace_in_text(text, subfrom, subto, pagemsg)
    if not replaced:
      return

  # If {{projectlinks}} preceded by *, we would get two of them, so remove one.
  text = re.sub(r"^\* *(\* \{\{projectlink)", r"\1", text, 0, re.M)

  return text, notes

parser = blib.create_argparser(u"Rewrite {{projectlinks}} using {{projectlink}}", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True, default_refs=["Template:projectlinks"])

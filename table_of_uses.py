#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errmsg, errandmsg, site

parser = blib.create_argparser(u"List pages, lemmas and/or non-lemmas")
parser.add_argument('--tempfile', help="Templates and aliases to do")
parser.add_argument('--include-refs', help="Include column for template references",
    action="store_true")
parser.add_argument('--ref-namespaces', help="List of namespaces to restrict references to")
parser.add_argument('--include-disposition', help="Include column for disposition",
    action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)
ref_namespaces = args.ref_namespaces and args.ref_namespaces.decode("utf-8").split(",") or None

msg('{|class="wikitable"')
msg("! Aliased template !! Canonical template !! #Uses%s%s" %
  (" !! Refs" if args.include_refs else "",
   " !! Suggested disposition" if args.include_disposition else ""))
for lineno, ref_and_aliases in blib.iter_items_from_file(args.tempfile):
  split_refs = re.split(",", ref_and_aliases)
  mainref = "Template:%s" % split_refs[0]
  aliases = split_refs[1:]
  refs = [(mainref, None)]
  for alias in aliases:
    refs.append(("Template:%s" % alias, mainref))
  for alias, mainref in refs:
    def errandpagemsg(txt):
      errandmsg("Page %s %s: %s" % (lineno, alias, txt))
    errmsg("Processing references to: %s" % alias)
    exists = blib.safe_page_exists(pywikibot.Page(site, alias), errandpagemsg)
    def maybe_strikethru(txt):
      return txt if exists else "<s>%s</s>" % txt
    template_refs = list(blib.references(alias, start, end, namespaces=ref_namespaces))
    num_refs = len(template_refs)
    msg("|-")
    msg("| %s || %s || %s%s%s" % (
      maybe_strikethru("[[%s]]" % alias if mainref else "'''[[%s]]'''" % alias),
      "[[%s]]" % mainref if mainref else "'''[[%s]]'''" % alias,
      num_refs,
      " || %s" % ", ".join("[[%s]]" % unicode(ref.title()) for i, ref in template_refs) if args.include_refs else "",
      " || ?" if args.include_disposition else ""))
msg("|}")

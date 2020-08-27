#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

import find_regex

hindi_head_templates = [
  "hi-adj",
  "hi-adj form",
  "hi-adv",
  "hi-con",
  "hi-det",
  "hi-diacritical mark",
  "hi-interj",
  "hi-noun",
  "hi-noun form",
  "hi-num",
  "hi-num-card",
  "hi-particle",
  "hi-perfect participle",
  "hi-phrase",
  "hi-post",
  "hi-prefix",
  "hi-prep",
  "hi-pron",
  "hi-pron form",
  "hi-proper noun",
  "hi-proverb",
  "hi-suffix",
  "hi-verb",
  "hi-verb form",
]

def process_page_text(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = unicode(t)
    if tn in hindi_head_templates:
      maxtr = 1
      for i in range(1, 10):
        if getparam(t, "tr" if i == 1 else "tr%s" % i):
          maxtr = i
      for i in range(1, maxtr + 1):
        trparam = "tr" if i == 1 else "tr%s" % i
        tr = getparam(t, trparam)
        if tr:
          pagemsg("Manual translit tr=%s in %s, not checking" % (tr, unicode(t)))
        else:
          headparam = "head" if i == 1 else "head%s" % i
          head = getparam(t, headparam)
          if head:
            head = blib.remove_links(head)
          else:
            head = pagetitle
          newtr = expand_text("{{xlit|hi|%s}}" % head)
          oldtr = expand_text("{{#invoke:User:Benwing2/hi-translit|tr|%s}}" % head)
          if newtr and oldtr:
            if newtr == oldtr:
              pagemsg("Auto translit %s same in new and old: %s" % (newtr, unicode(t)))
            else:
              pagemsg("WARNING: Different translit, new=%s, old=%s: %s" % (newtr, oldtr, unicode(t)))

def process_page(page, index):
  pagetitle = unicode(page.title())
  text = unicode(page.text)
  return process_page_text(index, pagetitle, text)

def process_find_regex_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  newtext, notes = process_page_text(index, pagetitle, text)
  pagemsg("------- begin text --------")
  msg(text.rstrip('\n'))
  msg("------- end text --------")

parser = blib.create_argparser("Remove redundant translit from Hindi headwords and check translit against phonetic respelling",
  include_pagefile=True)
parser.add_argument('--direcfile', help="File containing output from find_regex.py.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.direcfile:
  lines = codecs.open(args.direcfile, "r", "utf-8")

  pagename_and_text = find_regex.yield_text_from_find_regex(lines, args.verbose)
  for index, (pagename, text) in blib.iter_items(pagename_and_text, start, end,
      get_name=lambda x:x[0]):
    process_find_regex_page(index, pagename, text)
blib.do_pagefile_cats_refs(args, start, end, process_page, default_cats=["Hindi lemmas"])

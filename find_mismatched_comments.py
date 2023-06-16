#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  text_and_comments = re.split("(<!--|-->)", text)
  grouped_text_and_comments = []
  for i in range(1, len(text_and_comments), 2):
    preceding_text = text_and_comments[i - 1][-20:].replace("\n", r"\n")
    following_text = text_and_comments[i + 1][:20].replace("\n", r"\n")
    grouped_text_and_comments.append((preceding_text + text_and_comments[i] + following_text, text_and_comments[i]))
  num_open_comments = len([x for x in grouped_text_and_comments if x[1] == "<!--"])
  num_close_comments = len([x for x in grouped_text_and_comments if x[1] == "-->"])
  warnings = []
  if num_open_comments != num_close_comments:
    warnings.append("%s open comments but %s close comments" % (num_open_comments, num_close_comments))
  for i, (near_text, comment) in enumerate(grouped_text_and_comments):
    should_see = "<!--" if i % 2 == 0 else "-->"
    if comment != should_see:
      warnings.append("Saw <nowiki>%s</nowiki> at position %s but expected <nowiki>%s</nowiki>, near text '<nowiki>%s</nowiki>'" %
          (comment, i, should_see, near_text))
      break
    if comment == "<!--" and i == len(grouped_text_and_comments) - 1:
      warnings.append("Saw final unclosed <nowiki>%s</nowiki> at position %s, near text '<nowiki>%s</nowiki>'" %
          (comment, i, near_text))
      break
  if warnings:
    pagemsg("WARNING: %s" % "; ".join(warnings))

parser = blib.create_argparser("Find mismatched comments",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, stdin=True)

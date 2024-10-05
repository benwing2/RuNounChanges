#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, tname, pname

pages_to_delete = []

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, args.langname, pagemsg)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  if has_non_lang:
    sections[j - 1] = ""
    sections[j] = ""
    pagemsg("Delete entry for %s on page with other languages" % args.langname)
    notes.append("delete %s entry%s" % (args.langname, ": %s" % args.comment if args.comment else ""))
    text = "".join(sections)
    return text, notes

  pagemsg("Mark page for deletion")
  pages_to_delete.append(pagetitle)
  return

parser = blib.create_argparser("Delete entries for a given language.",
    include_pagefile=True, include_stdin=True)
parser.add_argument('--langname', help="Language name of language entries to delete.", required=True)
parser.add_argument('--comment', help="Comment to add to page when modifying.")
parser.add_argument('--output-pages-to-delete', help="File to write pages to delete.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(
    args, start, end, process_text_on_page, edit=True, stdin=True,
    default_cats=["%s lemmas" % args.langname, "%s non-lemma forms" % args.langname])

msg("The following pages need to be deleted:")
for page in pages_to_delete:
  msg(page)
if args.output_pages_to_delete:
  with open(args.output_pages_to_delete, "w", encoding="utf-8") as fp:
    for page in pages_to_delete:
      print(page, file=fp)

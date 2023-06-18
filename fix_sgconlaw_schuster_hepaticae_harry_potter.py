#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

templates = [
  "RQ:Schuster Hepaticae",
  "RQ:Harry Potter"
]

def rsub_repeatedly(fr, to, text):
  while True:
    newtext = re.sub(fr, to, text)
    if newtext == text:
      return text
    text = newtext

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  text = str(page.text)

  newtext = rsub_repeatedly(r"\n(:?#+)\* \{\{RQ:Schuster Hepaticae V\|(.*)\}\}:?\n\1\*: (.*)(\n|$)",
      r"\n\1* {{RQ:Schuster Hepaticae|volume=V|page=\2|text=\3}}\4",
      text)
  if newtext != text:
    notes.append("rename {{RQ:Schuster Hepaticae V}} to {{RQ:Schuster Hepaticae|volume=V}}")
    text = newtext

  newtext = rsub_repeatedly(r"\n(:?#+)\* \{\{RQ:Harry Potter\|([^|\n}]*)\|([^|\n}]*)((?:\|.*?)?)\}\}:?\n\1\*: (.*)\n\1\*:: (.*)(\n|$)",
      r"\n\1* {{RQ:mul:Rowling Harry Potter|\3|\2\4|text=\5|t=\6}}\7",
      text)
  if newtext != text:
    notes.append("rename {{RQ:Harry Potter}} to {{RQ:mul:Rowling Harry Potter}}")
    text = newtext

  newtext = rsub_repeatedly(r"\n(:?#+)\* \{\{RQ:Harry Potter\|([^|\n}]*)\|([^|\n}]*)((?:\|.*?)?)\}\}:?\n\1\*: \{\{(?:ux|quote)\|.*?\|(.*?)\|(?:t=)?(.*?)\}\}(\n|$)",
      r"\n\1* {{RQ:mul:Rowling Harry Potter|\3|\2\4|text=\5|t=\6}}\7",
      text)
  if newtext != text:
    notes.append("rename {{RQ:Harry Potter}} to {{RQ:mul:Rowling Harry Potter}}")
    text = newtext

  return text, notes

parser = blib.create_argparser("Rename {{RQ:Schuster Hepaticae V}} and {{RQ:Harry Potter}} templates")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in templates:
  msg("Processing references to Template:%s" % template)
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)

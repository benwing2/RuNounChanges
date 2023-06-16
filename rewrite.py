#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import blib, re, codecs
import pywikibot
from arabiclib import reorder_shadda

def process_page(page, index, refrom, reto, pagetitle_sub, comment, lang_only,
    warn_on_no_replacement, verbose, do_reorder_shadda):
  pagetitle = str(page.title())
  def pagemsg(txt):
    blib.msg("Page %s %s: %s" % (index, pagetitle, txt))
  if verbose:
    blib.msg("Processing %s" % pagetitle)
  #blib.msg("From: [[%s]], To: [[%s]]" % (refrom, reto))
  text = str(page.text)
  origtext = text
  if do_reorder_shadda:
    text = reorder_shadda(text)
  zipped_fromto = zip(refrom, reto)
  def replace_text(text):
    for fromval, toval in zipped_fromto:
      if pagetitle_sub:
        fromval = fromval.replace(pagetitle_sub, re.escape(pagetitle))
        toval = toval.replace(pagetitle_sub, pagetitle)
      text = re.sub(fromval, toval, text, 0, re.M)
    return text
  if not lang_only:
    text = replace_text(text)
  else:
    sec_to_replace = None
    foundlang = False
    sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

    for j in range(2, len(sections), 2):
      if sections[j-1] == "==%s==\n" % lang_only:
        if foundlang:
          pagemsg("WARNING: Found multiple %s sections, skipping page" % lang_only)
          if warn_on_no_replacement:
            pagemsg("WARNING: No replacements made")
          return
        foundlang = True
        sec_to_replace = j
        break

    if sec_to_replace is None:
      if warn_on_no_replacement:
        pagemsg("WARNING: No replacements made")
      return
    sections[sec_to_replace] = replace_text(sections[sec_to_replace])
    text = "".join(sections)
  if warn_on_no_replacement and text == origtext:
    pagemsg("WARNING: No replacements made")
  return text, comment or "replace %s" % (", ".join("%s -> %s" % (f, t) for f, t in zipped_fromto))

pa = blib.create_argparser("Search and replace on pages", include_pagefile=True)
pa.add_argument("-f", "--from", help="From regex, can be specified multiple times",
    metavar="FROM", dest="from_", required=True, action="append")
pa.add_argument("-t", "--to", help="To regex, can be specified multiple times",
    required=True, action="append")
pa.add_argument("--comment", help="Specify the change comment to use")
pa.add_argument('--pagetitle', help="Value to substitute page title with")
pa.add_argument('--lang-only', help="Only replace in the specified language section")
pa.add_argument('--reorder-shadda', help="Reorder shadda + short vowel to fix Unicode bug")
pa.add_argument('--warn-on-no-replacement', action="store_true",
  help="Warn if no replacements made")
args = pa.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

from_ = list(args.from_)
to = list(args.to)

if len(from_) != len(to):
  raise ValueError("Same number of --from and --to arguments must be specified")

def do_process_page(page, index, parsed):
  return process_page(page, index, from_, to, args.pagetitle, args.comment, args.lang_only,
    args.warn_on_no_replacement, args.verbose, args.reorder_shadda)
blib.do_pagefile_cats_refs(args, start, end, do_process_page, edit=True)

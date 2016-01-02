#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose, warn_on_no_change=False):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  if "===Etymology 1===" in text:
    pagemsg("WARNING: Skipping page because ===Etymology 1===")
    return

  origtext = text
  notes = []

  def fix_indent(text, header, lto):
    lto_text = "=" * lto
    newtext = re.sub("^===+%s===+$" % header,
        "%s%s%s" % (lto_text, header, lto_text), text, 0, re.M)
    if newtext != text:
      notes.append("fix %s indentation" % header)
    return newtext

  foundrussian = False
  sections = re.split("(^==[^=\n]*==\n)", text, 0, re.M)

  for j in xrange(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections, skipping page")
        return
      foundrussian = True

    sections[j] = fix_indent(sections[j], "Pronunciation", 3)
    sections[j] = fix_indent(sections[j], "Alternative forms", 3)
    sections[j] = fix_indent(sections[j], "Declension", 4)
    sections[j] = fix_indent(sections[j], "Conjugation", 4)

  text = "".join(sections)

  if origtext != text:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (origtext, text))
    assert notes
    comment = "; ".join(notes)
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)
  elif warn_on_no_change:
    pagemsg("WARNING: No changes")

parser = blib.create_argparser(u"Fix indentation of Pronunciation, Declension, Conjugation, Alternative forms sections")
parser.add_argument("--pagefile",
    help="""List of pages to process.""")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

if args.pagefile:
  lines = [x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")]
  for i, line in blib.iter_items(lines, start, end):
    m = re.search("^Page [0-9]+ (.*?): WARNING: .*?$", line)
    if not m:
      msg("WARNING: Can't process line: %s" % line)
    else:
      page = m.group(1)
      process_page(i, pywikibot.Page(site, page), args.save, args.verbose,
          warn_on_no_change=True)
else:
  for cat in ["Russian lemmas", "Russian non-lemma forms"]:
    msg("Processing category %s" % cat)
    for i, page in blib.cat_articles(cat, start, end):
      process_page(i, page, args.save, args.verbose) 

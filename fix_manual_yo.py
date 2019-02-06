#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  pagemsg("Processing")

  text = unicode(page.text)
  newtext = text

  newtext = re.sub(ur"\{\{ru-noun form\|[^|=]*\|([^|=]*)\|tr=.*?\}\}\n\n# \{\{alternative (?:form|spelling) of\|(.*?)\|lang=ru\}\}\n\n\[\[Category:Russian spellings with е instead of ё\]\]",
      ur"{{ru-pos-alt-ё|\2|noun form|g=\1}}", newtext)
  newtext = re.sub(ur"\{\{head\|ru\|([^|=]*)\|.*?g=(.*?)(?:\|.*?)?\}\}\n\n# \{\{alternative (?:form|spelling) of\|(.*?)\|lang=ru\}\}\n\n\[\[Category:Russian spellings with е instead of ё\]\]",
      ur"{{ru-pos-alt-ё|\3|\1|g=\2}}", newtext)

  if newtext != text:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, newtext))
    comment = u"Replaced manual alt-ё specification with {{ru-pos-alt-ё}}"
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = newtext
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)
  elif u"[[Category:Russian spellings with е instead of ё]]" in text:
    pagemsg(u"WARNING: Unable to match manual alt-ё form")

parser = blib.create_argparser(u"Replace manual alt-ё specification with {{ru-pos-alt-ё}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in [u"Russian spellings with е instead of ё"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)

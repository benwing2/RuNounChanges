#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  parsed = blib.parse(page)

  proper_noun_headword = None
  surname_template = None
  ru_adj11_template = None

  for t in parsed.filter_templates():
    tname = unicode(t.name)
    if tname == "ru-proper noun":
      if proper_noun_headword:
        pagemsg("WARNING: Multiple ru-proper noun headwords, skipping")
        return
      proper_noun_headword = t
    if tname == "surname":
      if surname_template:
        pagemsg("WARNING: Multiple surname templates, skipping")
        return
      surname_template = t
    if tname == "ru-adj11":
      if ru_adj11_template:
        pagemsg("WARNING: Multiple ru-adj11 templates, skipping")
        return
      ru_adj11_template = t

  if not ru_adj11_template:
    pagemsg("WARNING: Something wrong, can't find ru-adj11 template, skipping")
    return
  accented_name = getparam(ru_adj11_template, "3")
  orig_ru_adj11_template = unicode(ru_adj11_template)
  rmparam(ru_adj11_template, "4")
  rmparam(ru_adj11_template, "3")
  rmparam(ru_adj11_template, "2")
  rmparam(ru_adj11_template, "1")
  remaining_params = [x for x in ru_adj11_template.params]
  ru_adj11_template.name = "ru-decl-adj"
  del ru_adj11_template.params[:]
  ru_adj11_template.add("1", accented_name)
  ru_adj11_template.params.extend(remaining_params)
  pagemsg("Replacing %s with %s" % (orig_ru_adj11_template, unicode(ru_adj11_template)))

  if not surname_template:
    pagemsg("WARNING: Can't find surname template")
  else:
    orig_surname_template = unicode(surname_template)
    if not surname_template.has("dot"):
      surname_template.add("dot", ":")
      pagemsg("Replacing %s with %s" % (orig_surname_template, unicode(surname_template)))

  if not proper_noun_headword:
    pagemsg("WARNING: Can't find proper noun headword template")
  else:
    orig_proper_noun_headword = unicode(proper_noun_headword)
    rmparam(proper_noun_headword, "4")
    rmparam(proper_noun_headword, "3")
    rmparam(proper_noun_headword, "2")
    rmparam(proper_noun_headword, "1")
    remaining_params = [x for x in proper_noun_headword.params]
    proper_noun_headword.name = "ru-proper noun+"
    del proper_noun_headword.params[:]
    proper_noun_headword.add("1", accented_name)
    proper_noun_headword.add("2", "+")
    proper_noun_headword.add("a", "an")
    proper_noun_headword.add("n", "both")
    proper_noun_headword.params.extend(remaining_params)
    pagemsg("Replacing %s with %s" % (orig_proper_noun_headword, unicode(proper_noun_headword)))

  newtext = unicode(parsed)

  newtext = re.sub(r"\n\n\n*\[\[Category:ru:Names]]\n\n\n*", "\n\n", newtext)
  newtext = re.sub(r"\[\[Category:ru:Names]]\n", "", newtext)
  newtext = re.sub(r"(\{\{surname\|.*)\.\n", r"\1\n", newtext)

  if newtext != text:
    if verbose:
      pagemsg("Replacing <<%s>> with <<%s>>" % (text, newtext))
    comment = "Convert ru-adj11 to ru-decl-adj and fix up associated templates"
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = newtext
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)
  else:
    pagemsg("Skipping")

parser = blib.create_argparser("Fix uses of ru-adj11")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for temp in ["ru-adj11"]:
  msg("Processing references to Template:%s" % temp)
  for i, page in blib.references("Template:" + temp, start, end):
    process_page(i, page, args.save, args.verbose)

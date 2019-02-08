#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

import rulib

quote_templates = ["quote-book", "quote-hansard", "quote-journal",
  "quote-news", "quote-newsgroup", "quote-song", "quote-us-patent",
  "quote-video", "quote-web", "quote-wikipedia"]

quote_templates_text_param_6 = ["quote-book", "quote-newsgroup", "quote-song",
  "quote-us-patent", "quote-web"]
quote_templates_text_param_7 = ["quote-journal", "quote-news", "quote-video"]
quote_templates_text_param_8 = ["quote-hansard"]

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  pagemsg("Processing")

  text = unicode(page.text)
  newtext = text
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)
    # pagemsg("tn=%s" % unicode(tn))
    if tn in quote_templates:
      text_param = None
      if tn in quote_templates_text_param_6:
        text_param = "6"
      elif tn in quote_templates_text_param_7:
        text_param = "7"
      elif tn in quote_templates_text_param_8:
        text_param = "8"
      textval = ""
      if text_param:
        textval = getparam(t, text_param)
      if not textval:
        text_param = "text"
        textval = getparam(t, text_param)
      if not textval:
        text_param = "passage"
        textval = getparam(t, text_param)
      # pagemsg("%s=%s" % (text_param, textval))
      textval = textval.strip()
      if re.search(r"^\{\{ja-usex\|.*\}\}$", textval, re.S):
        rmparam(t, text_param)
        newnewtext = re.sub(r"(\n#+\*) *%s" % re.escape(origt),
          r"\1 %s\1: %s" % (unicode(t), textval), newtext)
        if newtext == newnewtext:
          pagemsg("WARNING: Can't find quote template in text: %s" % origt)
        else:
          newtext = newnewtext
          notes.append("move ja-usex call outside of %s call" % tn)
      elif "{{ja-usex|" in textval:
        pagemsg("WARNING: Found {{ja-usex| embedded in quote text but not whole param: %s" %
            origt)

  if newtext != text:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, newtext))
    assert notes
    comment = "; ".join(blib.group_notes(notes))
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = newtext
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser(u"Move ja-usex calls outside of quote-*")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in ["ja-usex"]:
  temppage = "Template:" + template
  msg("Processing %s" % temppage)
  for i, page in blib.references(temppage, start, end):
    process_page(i, page, args.save, args.verbose)

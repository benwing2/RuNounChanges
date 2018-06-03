#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Replace "{{bor|...|withtext=1}}" with "Borrowed from {{bor|...}}" when
# at beginning of line or sentence, possibly after a bullet or number
# sign.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  origtext = unicode(page.text)
  text = origtext
  text = re.sub(
    r"""(^(?:<[^<>]*?>)?[*#:]*\s*|     # beginning of line, possibly after
                                       # bullet/number/indent symbol or HTML
         \.(?:<[^<>]*?>)?\s+|          # or, after a period (marking end of
                                       # sentence), possibly followed by HTML
         ^\{\{rfe\|[^|{}]*?\||         # or, within {{rfe|LANG|...}}
         ^\{\{defdate\|[^|{}]*?\}\}\s* # or, after {{defdate|...}} at beginning
                                       # of line
        )
        (\{\{(?:bor|borrowing|borrowed) # beginning of template
         (?:\|(?:[^{}]|\{\{[^{}]*?\}\})*?)? # text before the |withtext=;
                                            # optional but must begin with |
                                            # allows one nested {{...}}
        )
        \|withtext=(?:1|[Yy]|[Yy]es)        # withtext= param
        ((?:\|(?:[^{}]|\{\{[^{}]*?\}\})*?)? # text after the |withtext=;
                                            # optional but must begin with |
                                            # allows one nested {{...}}
        )
        \}\}""",
    r"\1Borrowed from \2\3}}", text, 0, re.M | re.X)

  if text != origtext:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (origtext, text))
    comment = "Remove withtext= from {{bor}}/{{borrowed}}/{{borrowing}}"
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)
  else:
    pagemsg("WARNING: Unable to remove withtext=1")

parser = blib.create_argparser(u"Replace withtext= in {{bor}} with 'Borrowed from {{bor}}'")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.cat_articles("bor with withtext", start, end):
  process_page(i, page, args.save, args.verbose)

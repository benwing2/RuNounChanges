#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Replace "{{bor|...|withtext=1}}" with "Borrowed from {{bor|...}}" when
# at beginning of line or sentence, possibly after a bullet or number
# sign.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  origtext = str(page.text)
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
    return text, "Remove withtext= from {{bor}}/{{borrowed}}/{{borrowing}}"
  else:
    pagemsg("WARNING: Unable to remove withtext=1")

parser = blib.create_argparser("Replace withtext= in {{bor}} with 'Borrowed from {{bor}}'",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["bor with withtext"])

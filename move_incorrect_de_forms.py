#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser(u"Delete obsolete pages")
parser.add_argument('--pagefile', help="File of ///-separated pairs of base declensions to move")
parser.add_argument('--comment', help="Comment to use when deleting")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pages_to_move = [x.rstrip('\n').split("///") for x in codecs.open(args.pagefile, "r", "utf-8")]

comment = args.comment or "Move erroneously-created non-lemma form"

endings = ["e", "en", "er", "em", "es"]

for i, (frombase, tobase) in blib.iter_items(pages_to_move, start, end, get_name=lambda x: x[1]):
  for ending in endings:
    page = pywikibot.Page(site, frombase + ending)
    def pagemsg(txt):
      msg("Page %s %s: %s" % (i, unicode(page.title()), txt))
    topagename = tobase + ending
    if page.exists():
      if pywikibot.Page(site, topagename).exists():
        pagemsg("WARNING: Destination page %s already exists, not moving" %
            topagename)
      else:
        pagemsg("Moving to %s (comment=%s)" % (topagename, comment))
        if args.save:
          try:
            page.move(topagename, reason=comment, movetalk=True, noredirect=True)
          except pywikibot.PageRelatedError as error:
            pagemsg("Error moving: %s" % error)

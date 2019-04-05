#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser(u"Delete obsolete pages")
parser.add_argument('--pagefile', help="Pages to delete")
parser.add_argument('--delete-docs', help="Delete documentation pages of templates", action="store_true")
parser.add_argument('--comment', help="Comment to use when deleting")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pages_to_delete = [x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")]

comment = args.comment or "Delete obsolete page"
doc_comment = "Delete documentation page of " + re.sub("^([Dd]elete|[Rr]emove) ", "", comment)

for i, pagename in blib.iter_items(pages_to_delete, start, end):
  page = pywikibot.Page(site, pagename)
  if page.exists():
    msg("Deleting %s (comment=%s)" % (page.title(), comment))
    page.delete('%s (content was "%s")' % (comment, unicode(page.text)))
  if args.delete_docs:
    doc_page = pywikibot.Page(site, "%s/documentation" % pagename)
    if doc_page.exists():
      msg("Deleting %s (comment=%s)" % (doc_page.title(), doc_comment))
      doc_page.delete('%s (content was "%s")' % (doc_comment, unicode(doc_page.text)))

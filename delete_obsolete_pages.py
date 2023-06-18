#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse
from pywikibot.data.api import APIError

import blib
from blib import getparam, rmparam, msg, errandmsg, site

parser = blib.create_argparser("Delete obsolete pages")
parser.add_argument('--pagefile', help="Pages to delete", required=True)
parser.add_argument('--delete-docs', help="Delete documentation pages of templates", action="store_true")
parser.add_argument('--comment', help="Comment to use when deleting")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pages_to_delete = list(blib.yield_items_from_file(args.pagefile))

comment = args.comment or "Delete obsolete page"
doc_comment = "Delete documentation page of " + re.sub("^([Dd]elete|[Rr]emove) ", "", comment)

def delete_page(page, comment):
  for i in range(11):
    try:
      page.delete(comment)
      return
    except APIError as e:
      if i == 10:
        raise e
      errandmsg("APIError, try #%s: %s" % (i + 1, e))

for i, pagename in blib.iter_items(pages_to_delete, start, end):
  page = pywikibot.Page(site, pagename)
  if page.exists():
    msg("Deleting %s (comment=%s)" % (page.title(), comment))
    delete_page(page, '%s (content was "%s")' % (comment, str(page.text)))
    errandmsg("Page [[%s]] deleted" % page.title())
  if args.delete_docs:
    doc_page = pywikibot.Page(site, "%s/documentation" % pagename)
    if doc_page.exists():
      msg("Deleting %s (comment=%s)" % (doc_page.title(), doc_comment))
      delete_page(doc_page, '%s (content was "%s")' % (doc_comment, str(doc_page.text)))
      errandmsg("Page [[%s]] deleted" % doc_page.title())

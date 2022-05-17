#!/usr/bin/env python
# -*- coding: utf-8 -*-

import blib, re, codecs
from blib import msg, errmsg, site
import pywikibot
from arabiclib import reorder_shadda

def rename_pages(refrom, reto, refs, pages_and_refs, cats, pages, pagefile,
    from_to_pagefile, comment, filter_pages, save, verbose, startFrom, upTo):
  def rename_one_page(page, totitle, index):
    pagetitle = unicode(page.title())
    def pagemsg(txt):
      msg("Page %s %s: %s" % (index, pagetitle, txt))
    def errandpagemsg(txt):
      msg("Page %s %s: %s" % (index, pagetitle, txt))
      errmsg("Page %s %s: %s" % (index, pagetitle, txt))
    zipped_fromto = zip(refrom, reto)
    def replace_text(text):
      for fromval, toval in zipped_fromto:
        text = re.sub(fromval, toval, text)
      return text
    this_comment = comment or "rename based on regex %s" % (
      ", ".join("%s -> %s" % (f, t) for f, t in zipped_fromto)
    )
    if not totitle:
      totitle = replace_text(totitle)
    if totitle == pagetitle:
      pagemsg("WARNING: Regex doesn't match, not renaming to same name")
    else:
      new_page = pywikibot.Page(site, totitle)
      if new_page.exists():
        errandpagemsg("Destination page %s already exists, not moving" %
          totitle)
      elif save:
        try:
          page.move(totitle, reason=this_comment, movetalk=True, noredirect=True)
          errandpagemsg("Renamed to %s" % totitle)
        except pywikibot.PageRelatedError as error:
          errandpagemsg("Error moving to %s: %s" % (totitle, error))
      else:
        pagemsg("Would rename to %s (comment=%s)" % (totitle, this_comment))

  def yield_pages():
    if pages:
      for index, page in blib.iter_items(pages, startFrom, upTo):
        yield index, pywikibot.Page(blib.site, page), None
    if pagefile:
      lines = [x.strip() for x in codecs.open(pagefile, "r", "utf-8")]
      for index, page in blib.iter_items(lines, startFrom, upTo):
        yield index, pywikibot.Page(blib.site, page), None
    if from_to_pagefile:
      lines = [x.strip() for x in codecs.open(from_to_pagefile, "r", "utf-8")]
      for index, line in blib.iter_items(lines, startFrom, upTo):
        if " ||| " not in line:
          msg("WARNING: Saw bad line in --from-to-pagefile: %s" % line)
          continue
        frompage, topage = line.split(" ||| ")
        yield index, pywikibot.Page(blib.site, frompage), topage
    if refs:
      for ref in refs:
        for index, page in blib.references(ref, startFrom, upTo, only_template_inclusion=False):
          yield index, page, None
    if pages_and_refs:
      for page_and_refs in pages_and_refs:
        for index, page in blib.references(page_and_refs, startFrom, upTo, only_template_inclusion=False, include_page=True):
          yield index, page, None
    if cats:
      for cat in cats:
        for index, page in blib.cat_articles(cat, startFrom, upTo):
          yield index, page, None

  for index, page, totitle in yield_pages():
    pagetitle = unicode(page.title())
    if filter_pages and not re.search(filter_pages, pagetitle):
      msg("Skipping %s because doesn't match --filter-pages regex %s" %
          (pagetitle, filter_pages))
    elif not page.exists():
      msg("Skipping %s because page doesn't exist" % pagetitle)
    else:
      if verbose:
        msg("Processing %s" % pagetitle)
      rename_one_page(page, totitle, index)


pa = blib.init_argparser("Rename pages")
pa.add_argument("-f", "--from", help="From regex, can be specified multiple times",
    metavar="FROM", dest="from_", action="append")
pa.add_argument("-t", "--to", help="To regex, can be specified multiple times",
    action="append")
pa.add_argument("-r", "--references", "--refs",
    help="Do pages with references to these pages (comma-separated)")
pa.add_argument("--pages-and-refs", help="Comma-separated list of pages to do, along with references to those pages")
pa.add_argument("-c", "--categories", "--cats",
    help="Do pages in these categories (comma-separated)")
pa.add_argument("--comment", help="Specify the change comment to use")
pa.add_argument('--filter-pages', help="Regex to use to filter page names.")
pa.add_argument('--pages', help="List of pages to rename, comma-separated.")
pa.add_argument('--pagefile', help="File containing pages to rename.")
pa.add_argument('--from-to-pagefile', help="File containing pairs of from/to pages to rename, separated by ' ||| '.")
params = pa.parse_args()
startFrom, upTo = blib.parse_start_end(params.start, params.end)

if (not params.references and not params.pages_and_refs
    and not params.categories and not params.pages and not params.pagefile
    and not params.from_to_pagefile):
  raise ValueError("--references, --categories, --pages, pages-and-refs, --pagefile or --from-to-pagefile must be present")

references = params.references and params.references.decode("utf-8").split(",") or []
pages_and_refs = params.pages_and_refs and params.pages_and_refs.decode("utf-8").split(",") or []
categories = params.categories and params.categories.decode("utf-8").split(",") or []
from_ = [x.decode("utf-8") for x in params.from_] if params.from_ else []
to = [x.decode("utf-8") for x in params.to] if params.to else []
pages = params.pages and params.pages.decode("utf-8").split(",") or []
pagefile = params.pagefile and params.pagefile.decode("utf-8")
from_to_pagefile = params.from_to_pagefile and params.from_to_pagefile.decode("utf-8")
comment = params.comment and params.comment.decode("utf-8")
filter_pages = params.filter_pages and params.filter_pages.decode("utf-8")

if len(from_) != len(to):
  raise ValueError("Same number of --from and --to arguments must be specified")

rename_pages(from_, to, references, pages_and_refs, categories, pages, pagefile,
    from_to_pagefile, comment, filter_pages, params.save, params.verbose,
    startFrom, upTo)

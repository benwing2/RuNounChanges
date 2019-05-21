#!/usr/bin/env python
#coding: utf-8

#    delete.py is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

import blib, re, codecs
from blib import msg, errmsg, site
import pywikibot
from arabiclib import reorder_shadda

def delete_pages(refs, page_and_refs, cat, pages, pagefile,
    comment, filter_pages, save, verbose, startFrom, upTo):
  if pages:
    pages = ((index, pywikibot.Page(site, page)) for index, page in blib.iter_items(pages, startFrom, upTo))
  elif pagefile:
    lines = [x.strip() for x in codecs.open(pagefile, "r", "utf-8")]
    pages = ((index, pywikibot.Page(site, page)) for index, page in blib.iter_items(lines, startFrom, upTo))
  elif refs:
    pages = blib.references(refs, startFrom, upTo, only_template_inclusion=False)
  elif page_and_refs:
    pages = blib.references(page_and_refs, startFrom, upTo, only_template_inclusion=False, include_page=True)
  else:
    pages = blib.cat_articles(cat, startFrom, upTo)
  for index, page in pages:
    pagetitle = unicode(page.title())
    def pagemsg(txt):
      msg("Page %s %s: %s" % (index, pagetitle, txt))
    def errandpagemsg(txt):
      msg("Page %s %s: %s" % (index, pagetitle, txt))
      errmsg("Page %s %s: %s" % (index, pagetitle, txt))
    if filter_pages and not re.search(filter_pages, pagetitle):
      pagemsg("Skipping because doesn't match --filter-pages regex %s" %
          filter_pages)
    else:
      if verbose:
        pagemsg("Processing")
      this_comment = comment or 'delete page'
      if page.exists():
        if save:
          page.delete('%s (content was "%s")' % (this_comment, unicode(page.text)))
          errandpagemsg("Deleted (comment=%s)" % this_comment)
        else:
          pagemsg("Would delete (comment=%s)" % this_comment)
      else:
        pagemsg("Skipping, page doesn't exist")

pa = blib.init_argparser("Rename pages")
pa.add_argument("-r", "--references", "--refs",
    help="Do pages with references to this page")
pa.add_argument("--page-and-refs", help="Do page and references to this page")
pa.add_argument("-c", "--category", "--cat",
    help="Do pages in this category")
pa.add_argument("--comment", help="Specify the change comment to use")
pa.add_argument('--filter-pages', help="Regex to use to filter page names.")
pa.add_argument('--pages', help="List of pages to delete, comma-separated.")
pa.add_argument('--pagefile', help="File containing pages to delete.")
params = pa.parse_args()
startFrom, upTo = blib.parse_start_end(params.start, params.end)

if not params.references and not params.page_and_refs and not params.category and not params.pages and not params.pagefile:
  raise ValueError("--references, --category, --pages, page-and-refs or --pagefile must be present")

references = params.references and params.references.decode("utf-8")
page_and_refs = params.page_and_refs and params.page_and_refs.decode("utf-8")
category = params.category and params.category.decode("utf-8")
pages = params.pages and re.split(",", params.pages.decode("utf-8"))
comment = params.comment and params.comment.decode("utf-8")
filter_pages = params.filter_pages and params.filter_pages.decode("utf-8")

delete_pages(references, page_and_refs, category, pages, params.pagefile,
    comment, filter_pages, params.save, params.verbose, startFrom, upTo)

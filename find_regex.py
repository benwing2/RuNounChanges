#!/usr/bin/env python
#coding: utf-8

#    find_regex.py is free software: you can redistribute it and/or modify
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

# Find pages that need definitions among a set list (e.g. most frequent words).

import blib, re, codecs
import pywikibot

import blib
from blib import getparam, rmparam, msg, site

def process_page(regex, index, page, filter_pages, verbose,
    include_non_mainspace, russian_only):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if verbose:
    pagemsg("Processing")

  if not include_non_mainspace and ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping page")
    return

  if filter_pages and not re.search(filter_pages, pagetitle):
    pagemsg("Skipping because doesn't match --filter-pages regex %s" %
        filter_pages)
    return

  text = unicode(page.text)

  if not russian_only:
    text_to_search = text
  else:
    text_to_search = None
    foundrussian = False
    sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

    for j in xrange(2, len(sections), 2):
      if sections[j-1] == "==Russian==\n":
        if foundrussian:
          pagemsg("WARNING: Found multiple Russian sections, skipping page")
          return
        foundrussian = True
        text_to_search = sections[j]
        break

  if text_to_search and re.search(regex, text_to_search, re.M):
    pagemsg("Found match for regex: %s" % regex)
    if verbose:
      if not text_to_search.endswith("\n"):
        text_to_search += "\n"
      pagemsg("-------- begin text ---------\n%s-------- end text --------" % text_to_search)

def yield_pages_in_cats(cats, startFrom, upTo):
  for cat in cats:
    for index, page in blib.cat_articles(cat, startFrom, upTo):
      yield index, page

def search_pages(regex, refs, cat, pages, pagefile, filter_pages, verbose,
    startFrom, upTo, include_non_mainspace, russian_only):
  if pages:
    pages = ((index, pywikibot.Page(blib.site, page)) for page, index in blib.iter_pages(pages, startFrom, upTo))
  elif pagefile:
    lines = [x.strip() for x in codecs.open(pagefile, "r", "utf-8")]
    pages = ((index, pywikibot.Page(blib.site, page)) for page, index in blib.iter_pages(lines, startFrom, upTo))
  elif refs:
    pages = blib.references(refs, startFrom, upTo, includelinks=True)
  else:
    pages = yield_pages_in_cats(cat.split(","), startFrom, upTo)
  for index, page in pages:
    process_page(regex, index, page, filter_pages, verbose,
        include_non_mainspace, russian_only)

pa = blib.init_argparser("Search on pages")
pa.add_argument("-e", "--regex", help="Regular expression to search for.",
    required=True)
pa.add_argument("-r", "--references", "--refs",
    help="Do pages with references to this page.")
pa.add_argument("-c", "--category", "--cat",
    help="List of categories to search, comma-separated.")
pa.add_argument('--filter-pages', help="Regex to use to filter page names.")
pa.add_argument('--pages', help="List of pages to search, comma-separated.")
pa.add_argument('--pagefile', help="File containing pages to search.")
pa.add_argument('--include-non-mainspace', help="Don't skip non-mainspace pages.", action='store_true')
pa.add_argument('--russian-only', help="Only search the Russian section.", action='store_true')
params = pa.parse_args()
startFrom, upTo = blib.parse_start_end(params.start, params.end)

if not params.references and not params.category and not params.pages and not params.pagefile:
  raise ValueError("--references, --category, --pages or --pagefile must be present")

references = params.references and params.references.decode("utf-8")
category = params.category and params.category.decode("utf-8")
regex = params.regex.decode("utf-8")
pages = params.pages and re.split(",", params.pages.decode("utf-8"))
filter_pages = params.filter_pages and params.filter_pages.decode("utf-8")

search_pages(regex, references, category, pages, params.pagefile,
    filter_pages, params.verbose, startFrom, upTo,
    params.include_non_mainspace, params.russian_only)

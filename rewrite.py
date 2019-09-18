#!/usr/bin/env python
#coding: utf-8

#    rewrite.py is free software: you can redistribute it and/or modify
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
import pywikibot
from arabiclib import reorder_shadda

def rewrite_pages(refrom, reto, refs, pages_and_refs, cats, pages, pagefile,
    pagetitle_sub, comment, filter_pages, lang_only, save, verbose,
    diff, startFrom, upTo):
  def rewrite_one_page(page, index, text):
    #blib.msg("From: [[%s]], To: [[%s]]" % (refrom, reto))
    text = unicode(text)
    text = reorder_shadda(text)
    zipped_fromto = zip(refrom, reto)
    def replace_text(text):
      for fromval, toval in zipped_fromto:
        if pagetitle_sub:
          pagetitle = unicode(page.title())
          fromval = fromval.replace(pagetitle_sub, re.escape(pagetitle))
          toval = toval.replace(pagetitle_sub, pagetitle)
        text = re.sub(fromval, toval, text, 0, re.M)
      return text
    if not lang_only:
      text = replace_text(text)
    else:
      sec_to_replace = None
      foundlang = False
      sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

      for j in xrange(2, len(sections), 2):
        if sections[j-1] == "==%s==\n" % lang_only:
          if foundlang:
            pagemsg("WARNING: Found multiple %s sections, skipping page" % lang_only)
            return None, None
          foundlang = True
          sec_to_replace = j
          break

      if sec_to_replace is None:
        return None, None
      sections[sec_to_replace] = replace_text(sections[sec_to_replace])
      text = "".join(sections)
    return text, comment or "replace %s" % (", ".join("%s -> %s" % (f, t) for f, t in zipped_fromto))

  def yield_pages():
    if pages:
      for index, page in blib.iter_items(pages, startFrom, upTo):
        yield index, pywikibot.Page(blib.site, page)
    if pagefile:
      lines = [x.strip() for x in codecs.open(pagefile, "r", "utf-8")]
      for index, page in blib.iter_items(lines, startFrom, upTo):
        yield index, pywikibot.Page(blib.site, page)
    if refs:
      for ref in refs:
        for index, page in blib.references(ref, startFrom, upTo, only_template_inclusion=False):
          yield index, page
    if pages_and_refs:
      for page_and_refs in pages_and_refs:
        for index, page in blib.references(page_and_refs, startFrom, upTo, only_template_inclusion=False, include_page=True):
          yield index, page
    if cats:
      for cat in cats:
        for index, page in blib.cat_articles(cat, startFrom, upTo):
          yield index, page

  for index, page in yield_pages():
    pagetitle = unicode(page.title())
    if filter_pages and not re.search(filter_pages, pagetitle):
      blib.msg("Skipping %s because doesn't match --filter-pages regex %s" %
          (pagetitle, filter_pages))
    else:
      if verbose:
        blib.msg("Processing %s" % pagetitle)
      blib.do_edit(page, index, rewrite_one_page, save=save, verbose=verbose,
          diff=diff)

pa = blib.init_argparser("Search and replace on pages")
pa.add_argument("-f", "--from", help="From regex, can be specified multiple times",
    metavar="FROM", dest="from_", required=True, action="append")
pa.add_argument("-t", "--to", help="To regex, can be specified multiple times",
    required=True, action="append")
pa.add_argument("-r", "--references", "--refs",
    help="Do pages with references to this pages (comma-separated)")
pa.add_argument("--pages-and-refs", help="Comma-separated list of pages to do, along with references to those pages")
pa.add_argument("-c", "--categories", "--cats",
    help="Do pages in these categories (comma-separated)")
pa.add_argument("--comment", help="Specify the change comment to use")
pa.add_argument('--filter-pages', help="Regex to use to filter page names")
pa.add_argument('--pages', help="List of pages to fix (comma-separated)")
pa.add_argument('--pagefile', help="File containing pages to fix")
pa.add_argument('--pagetitle', help="Value to substitute page title with")
pa.add_argument('--lang-only', help="Only replace in the specified language section")
params = pa.parse_args()
startFrom, upTo = blib.parse_start_end(params.start, params.end)

if not params.references and not params.pages_and_refs and not params.categories and not params.pages and not params.pagefile:
  raise ValueError("--references, --categories, --pages, pages-and-refs or --pagefile must be present")

references = params.references and params.references.decode("utf-8").split(",") or []
pages_and_refs = params.pages_and_refs and params.pages_and_refs.decode("utf-8").split(",") or []
categories = params.categories and params.categories.decode("utf-8").split(",") or []
from_ = [x.decode("utf-8") for x in params.from_]
to = [x.decode("utf-8") for x in params.to]
pages = params.pages and params.pages.decode("utf-8").split(",") or []
pagetitle_sub = params.pagetitle and params.pagetitle.decode("utf-8")
comment = params.comment and params.comment.decode("utf-8")
filter_pages = params.filter_pages and params.filter_pages.decode("utf-8")
lang_only = params.lang_only and params.lang_only.decode("utf-8")

if len(from_) != len(to):
  raise ValueError("Same number of --from and --to arguments must be specified")

rewrite_pages(from_, to, references, pages_and_refs, categories, pages,
    params.pagefile, pagetitle_sub, comment, filter_pages, lang_only,
    params.save, params.verbose, params.diff, startFrom, upTo)

#!/usr/bin/env python
# -*- coding: utf-8 -*-

#    find_vep_uvvv_redlinks.py is free software: you can redistribute it and/or modify
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

# Go through all the pages in 'Category:R:vep:UVVV with red link' looking
# for {{R:vep:UVVV}} templates, and check the pages in those templates to
# see if they exist.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  parsed = blib.parse(page)
  for t in parsed.filter_templates():
    if unicode(t.name) == "R:vep:UVVV":
      refpages = blib.fetch_param_chain(t, "1", "")
      for refpage in refpages:
        if not pywikibot.Page(site, refpage).exists():
          pagemsg("Page [[%s]] does not exist" % refpage)

parser = blib.create_argparser(u"Find red links in pages in Category:R:vep:UVVV with red link",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_cats=["R:vep:UVVV with red link"])

#!/usr/bin/env python
#coding: utf-8

#    find_red_links.py is free software: you can redistribute it and/or modify
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

# Find redlinks (non-existent pages).

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser(u"Find red links")
parser.add_argument("--pagefile", help="File containing pages to check")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

lines = [x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")]
for i, pagename in blib.iter_items(lines, start, end):
  page = pywikibot.Page(site, pagename)
  if page.exists():
    msg("Page %s [[%s]]: exists" % (i, pagename))
  else:
    msg("Page %s [[%s]]: does not exist" % (i, pagename))

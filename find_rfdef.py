#!/usr/bin/env python
#coding: utf-8

#    find_rfdef.py is free software: you can redistribute it and/or modify
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

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser(u"Find pages that need definitions")
parser.add_argument("--pagefile", help="File containing pages to check")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lines = set([x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")])
for i, page in blib.cat_articles("Russian entries needing definition",
    start, end):
  pagetitle = page.title()
  if pagetitle in lines:
    msg("* Page %s [[%s]]" % (i, pagetitle))

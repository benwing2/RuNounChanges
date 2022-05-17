#!/usr/bin/env python
# -*- coding: utf-8 -*-

#    attributive_to_relational.py is free software: you can redistribute it and/or modify
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

import pywikibot, re, sys, codecs, argparse, time
import blib
from blib import site, msg, errmsg

def process_page(page, index, parsed):
  pagetitle = page.title()

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def errpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))

  if not blib.try_repeatedly(lambda: page.exists(), pagemsg,
      "check page existence"):
    pagemsg("Page doesn't exist, can't add etymology")
    return

  pagetext = unicode(page.text)

  def attributive_to_relational(m):
    labels = ['relational' if x == 'attributive' else x for x in m.group(1).split('|')]
    return '{{lb|ru|%s}}' % '|'.join(labels)
  newtext = re.sub(r'\{\{lb\|ru\|(.*?)\}\}', attributive_to_relational, pagetext)
  pagehead, sections = blib.split_text_into_sections(newtext, "Russian")
  # Go through each section in turn, looking for existing language section
  for i in xrange(len(sections)):
    m = re.match("^==([^=\n]+)==$", sections[i], re.M)
    if not m:
      pagemsg("Can't find language name in text: [[%s]]" % (sections[i]))
    elif m.group(1) == "Russian":
      lines = sections[i].split('\n')
      for line in lines:
        if '{{i|attributive}}' in line:
          pagemsg("Found {{i|attributive}}: %s" % line)
        elif 'attributive' in line:
          pagemsg("Found bare attributive: %s" % line)
      sections[i] = sections[i].replace('{{i|attributive}}', '{{i|relational}}')
      break
  else:
    errpagemsg("Can't find Russian section")
    return

  return pagehead + ''.join(sections), "attributive -> relational"

if __name__ == "__main__":
  parser = blib.create_argparser("Convert attributive labels to relational",
    include_pagefile=True)
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re
import pywikibot
import blib
from blib import msg, errandmsg, site

cats = [
  u"आना",
  u"उगलना",
  u"उठाना",
  u"उतरना",
  u"उतारना",
  u"कटना",
  u"कमाना",
  u"करना",
  u"कराना",
  u"खाना",
  u"खींचना",
  u"गाना",
  u"चढ़ाना",
  u"चबवाना",
  u"चलना",
  u"चलाना",
  u"चोदना",
  u"जाना",
  u"जोड़ना",
  u"डालना",
  u"तोड़ना",
  u"दबाना",
  u"दिलाना",
  u"देखना",
  u"देना",
  u"निकालना",
  u"निभाना",
  u"पड़ना",
  u"पढ़ना",
  u"पहनना",
  u"पहनाना",
  u"पहुँचाना",
  u"पाना",
  u"पीना",
  u"फूलना",
  u"बजाना",
  u"बनना",
  u"बनाना",
  u"बरसना",
  u"बाटना",
  u"बैठना",
  u"बोलना",
  u"भीगना",
  u"माँगना",
  u"मारना",
  u"मिलाना",
  u"रखना",
  u"रहना",
  u"लगना",
  u"लगाना",
  u"लेना",
  u"सकना",
  u"समझना",
  u"सुनाना",
  u"सूखना",
  u"हिलाना",
  u"होना",
]

parser = blib.create_argparser(u"Create Hindi phrasal verb categories")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for cat in cats:
  pagename = "Category:Hindi phrasal verbs with particle (%s)" % cat
  page = pywikibot.Page(site, pagename)
  if page.exists():
    msg("Page %s already exists, not overwriting" % pagename)
    continue
  text = "[[Category:Hindi phrasal verbs|%s]]" % cat
  page.text = text
  changelog = "Create '%s' with text '%s'" % (pagename, text)
  msg("Changelog = %s" % changelog)
  if args.save:
    blib.safe_page_save(page, changelog, errandmsg)

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re
import pywikibot
import blib
from blib import msg, errandmsg, site

cats = [
  "आना",
  "उगलना",
  "उठाना",
  "उतरना",
  "उतारना",
  "कटना",
  "कमाना",
  "करना",
  "कराना",
  "खाना",
  "खींचना",
  "गाना",
  "चढ़ाना",
  "चबवाना",
  "चलना",
  "चलाना",
  "चोदना",
  "जाना",
  "जोड़ना",
  "डालना",
  "तोड़ना",
  "दबाना",
  "दिलाना",
  "देखना",
  "देना",
  "निकालना",
  "निभाना",
  "पड़ना",
  "पढ़ना",
  "पहनना",
  "पहनाना",
  "पहुँचाना",
  "पाना",
  "पीना",
  "फूलना",
  "बजाना",
  "बनना",
  "बनाना",
  "बरसना",
  "बाटना",
  "बैठना",
  "बोलना",
  "भीगना",
  "माँगना",
  "मारना",
  "मिलाना",
  "रखना",
  "रहना",
  "लगना",
  "लगाना",
  "लेना",
  "सकना",
  "समझना",
  "सुनाना",
  "सूखना",
  "हिलाना",
  "होना",
]

parser = blib.create_argparser("Create Hindi phrasal verb categories")
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

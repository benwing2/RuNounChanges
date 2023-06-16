#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re, codecs

import blib
import grc_translit
from canon_foreign import canon_links

pa = blib.create_argparser("Canonicalize Greek and translit")
pa.add_argument("--cattype", default="borrowed",
    help="""Categories to examine ('vocab', 'borrowed', 'translation',
'links', 'pagetext', 'pages' or comma-separated list)""")
pa.add_argument("--page-file",
    help="""File containing "pages" to process when --cattype pagetext,
or list of pages when --cattype pages""")

params = pa.parse_args()
startFrom, upTo = blib.parse_start_end(params.start, params.end)
pages_to_do = []
if params.page_file:
  for line in codecs.open(params.page_file, "r", encoding="utf-8"):
    line = line.strip()
    if params.cattype == "pages":
      pages_to_do.append(line)
    else:
      m = re.match(r"^Page [0-9]+ (.*?): [^:]*: Processing (.*?)$", line)
      if not m:
        m = re.match(r"\* \[\[(.*?)]]: .*?<nowiki>(.*?)</nowiki>$", line)
      if not m:
        msg("WARNING: Unable to parse line: [%s]" % line)
      else:
        pages_to_do.append(m.groups())

canon_links(params.save, params.verbose, params.cattype, "grc", "Ancient Greek",
    ["polytonic", "Grek"], grc_translit, startFrom, upTo,
    pages_to_do=pages_to_do)

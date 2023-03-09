#!/usr/bin/env python
# -*- coding: utf-8 -*-

import blib
import fa_translit
from canon_foreign import canon_one_page_links

parser = blib.create_argparser("Clean up Persian transliterations",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

templates_seen = {}
templates_changed = {}
def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  text = unicode(page.text)
  return canon_one_page_links(pagetitle, index, text, "fa", "fa-Arab", fa_translit,
      templates_seen, templates_changed)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=1)
blib.output_process_links_template_counts(templates_seen, templates_changed)

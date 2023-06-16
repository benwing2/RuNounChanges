#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import blib
import bg_translit
from canon_foreign import canon_one_page_links

parser = blib.create_argparser("Change grave to acute in Bulgarian headwords",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

templates_seen = {}
templates_changed = {}
def process_page(page, index, parsed):
  pagetitle = str(page.title())
  text = str(page.text)
  return canon_one_page_links(pagetitle, index, text, "bg", "Cyrl", bg_translit,
      templates_seen, templates_changed)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=1)
blib.output_process_links_template_counts(templates_seen, templates_changed)

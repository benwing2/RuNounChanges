#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser(u"Delete obsolete form-of templates and documentation pages")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

templates_to_delete = [
  "abessive plural of",
  "abessive singular of",
  "associative plural of",
  "associative singular of",
  "comitative plural of",
  "comitative singular of",
  "comparative plural of",
  "comparative singular of",
  "distributive plural of",
  "distributive singular of",
  "exclusive plural of",
  "exclusive singular of",
  "oblique plural of",
  "oblique singular of",
  "terminative plural of",
  "terminative singular of",
  "ancient form of",
  "early form of",
  "late form of",
  "masculine animate plural past participle of",
  "masculine inanimate plural past participle of",
  "masculine singular past participle of",
  "neuter plural past participle of",
  "dative dual of",
  "dative plural definite of",
  "dative plural indefinite of",
  "paucal of",
  "second-person singular of",
]

for i, temp in blib.iter_items(templates_to_delete, start, end):
  template_page = pywikibot.Page(site, "Template:%s" % temp)
  if template_page.exists():
    template_page.delete('Delete obsoleted and orphaned form-of template (content was "%s")' % str(template_page.text))
  template_doc_page = pywikibot.Page(site, "Template:%s/documentation" % temp)
  if template_doc_page.exists():
    template_doc_page.delete('Delete documentation page of obsoleted and orphaned form-of template (content was "%s")' % str(template_doc_page.text))

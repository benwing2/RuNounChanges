#!/usr/bin/env python
# -*- coding: utf-8 -*-

import blib
from blib import getparam, addparam

def rewrite_one_page_ar_nisba(page, index, text):
  for template in text.filter_templates():
    if template.name == "ar-nisba":
      if template.has("head") and not template.has(1):
        head = str(template.get("head").value)
        template.remove("head")
        addparam(template, "1", head, before=template.params[0].name if len(template.params) > 0 else None)
      if template.has("plhead"):
        blib.msg("%s has plhead=" % page.title())
  return text, "ar-nisba: head= -> 1="

def rewrite_ar_nisba(save, verbose, startFrom, upTo):
  for index, page in blib.references("Template:ar-nisba", startFrom, upTo):
    blib.do_edit(page, index, rewrite_one_page_ar_nisba, save=save, verbose=verbose)

pa = blib.create_argparser("Rewrite ar-nisba, changing head= to 1=")
params = pa.parse_args()
startFrom, upTo = blib.parse_start_end(params.start, params.end)

rewrite_ar_nisba(params.save, params.verbose, startFrom, upTo)

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import blib
from blib import getparam, addparam

def rewrite_one_page_ar_plural(page, index, text):
  for template in text.filter_templates():
    if template.name == "ar-plural":
      template.name = "ar-noun-pl"

  return text, "rename {{temp|ar-plural}} to {{temp|ar-noun-pl}}"

def rewrite_ar_plural(save, verbose, startFrom, upTo):
  for cat in [u"Arabic plurals"]:
    for index, page in blib.cat_articles(cat, startFrom, upTo):
      blib.do_edit(page, index, rewrite_one_page_ar_plural, save=save, verbose=verbose)

pa = blib.create_argparser("Rewrite ar-plural to ar-noun-pl templates")
params = pa.parse_args()
startFrom, upTo = blib.parse_start_end(params.start, params.end)

rewrite_ar_plural(params.save, params.verbose, startFrom, upTo)

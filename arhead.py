#!/usr/bin/env python3
# -*- coding: utf-8 -*-
 
import blib, pywikibot, re, string, sys
from blib import addparam
import arabiclib
 
def fix(page, index, text):
  for template in text.filter_templates():
    if template.name in arabiclib.arabic_all_headword_templates:
      if template.has("head") and not template.has(1) and not template.has(2) and not template.has(3) and not template.has(4) and not template.has(5) and not template.has(6) and not template.has(7) and not template.has(8):
        head = str(template.get("head").value)
        template.remove("head")
        addparam(template, "head", head, before=template.params[0].name if len(template.params) > 0 else None)
 
        if template.params[0].name == "head":
          template.get("head").showkey = False
 
  return text, "ar headword: head= > 1="
 
startFrom, upTo = blib.parse_args()
 
for index, page in blib.references(u"Template:tracking/ar-head/head", startFrom, upTo):
  blib.do_edit(page, index, fix)

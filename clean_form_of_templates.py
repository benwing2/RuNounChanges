#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

from form_of_templates import (
  language_specific_alt_form_of_templates,
  language_specific_form_of_templates,
  form_of_templates
)

form_of_template_list = []
for form_of_spec in form_of_templates:
  form_of_template_list.append(form_of_spec[0])
  if "aliases" in form_of_spec[1]:
    form_of_template_list.extend(form_of_spec[1]["aliases"])
request_templates = [
  "etystub", "rfap", "rfc-pron-n", "rfc-sense", "rfc-def",
  "rfd", "rfdo", "rfd-redundant", "rfd-sense", "rfdecl", "rfdef",
  "request for etymology", "rfe", "rfelite", "rfex", "rfusex",
  "rfform", "rfi", "rfinfl", "rfp", "rfp-old",
  "rfquote", "citesneeded", "rfcite",
  "rfquote-sense", "rfcite-sense",
  "request for references", "rfr", "rft-sense",
  "rfv", "rfv-etymology", "rfv-pronunciation", "rfv-sense",
  "sense stub", "gloss-stub", "stub-gloss",
]
multicolumn_templates = [
  "columns", "col", "col-u",
  "col1", "col2", "col3", "col4", "col5",
  "col1-u", "col2-u", "col3-u", "col4-u", "col5-u",
  "rel2", "rel3", "rel4",
  "der2", "der3", "der4",
]
quote_templates = [
  "quote-av", "quote-book", "quote-hansard", "quote-journal",
  "quote-newsgroup", "quote-song", "quote-us-patent", "quote-web",
  "quote-wikipedia",
]
misc_templates = [
  "&lit", "audio", "audio-IPA", "audio-pron", "given name",
  "historical given name",
  "homophones", "homophone", "hmp",
  "hot word", "hyphenation", "hyph", "IPA", "named-after", "no entry",
  "only used in", "picdicimg", "picdiclabel",
  "rhymes", "rhyme", "seemoreCites",
  "surname", "term-context", "tcx", "trademark erosion",
  "was fwotd", "X2IPA", "x2IPA", "x2ipa", "x2rhymes", "Zodiac",
]

templates_to_move_lang = (
  form_of_template_list + request_templates + multicolumn_templates +
  quote_templates + misc_templates
)

templates_to_iterate_over = ["form of", "synonym of"] + quote_templates

#templates_to_remove_empty_dot = (
#  form_of_template_list + language_specific_form_of_templates
#)
#templates_to_check_for_empty_dot = (
#  alt_form_of_templates + language_specific_alt_form_of_templates
#)
#templates_to_remove_nodot = (
#  form_of_template_list + language_specific_form_of_templates
#)
templates_to_remove_empty_dot = []
templates_to_check_for_empty_dot = []
templates_to_remove_nodot = []

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)
    if tn in templates_to_remove_nodot:
      if t.has("nodot"):
        rmparam(t, "nodot")
        notes.append("remove effectless nodot= from {{%s}}" % tn)
    if tn in templates_to_remove_empty_dot:
      if t.has("dot"):
        if getparam(t, "dot") and getparam(t, "dot") != "<nowiki/>":
          pagemsg("WARNING: non-empty dot= in form_of_t template: %s" % unicode(t))
        rmparam(t, "dot")
        notes.append("remove effectless empty dot= from {{%s}}" % tn)
    if tn in templates_to_check_for_empty_dot:
      if t.has("dot") and (not getparam(t, "dot") or getparam(t, "dot") == "<nowiki/>"):
        pagemsg("WARNING: empty dot= in alt_form_of_t template: %s" % unicode(t))
        rmparam(t, "dot")
        t.add("nodot", "1")
        notes.append("convert empty dot= to nodot=1 in {{%s}}" % tn)
    if tn in templates_to_move_lang:
      lang = getparam(t, "lang")
      if lang:
        # Fetch all params.
        params = []
        for param in t.params:
          pname = unicode(param.name)
          if pname.strip() != "lang":
            params.append((pname, param.value, param.showkey))
        # Erase all params.
        del t.params[:]
        t.add("1", lang)
        # Put remaining parameters in order.
        for name, value, showkey in params:
          if re.search("^[0-9]+$", name):
            t.add(str(int(name) + 1), value, showkey=showkey, preserve_spacing=False)
          else:
            t.add(name, value, showkey=showkey, preserve_spacing=False)
        notes.append("move lang= to 1= in {{%s}}" % tn)

    if unicode(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, unicode(t)))

  return unicode(parsed), notes

parser = blib.create_argparser("Move lang= to 1=", include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
    default_refs=["Template:%s" % template for template in templates_to_iterate_over],
    #default_refs=["Template:tracking/form-of/form-of-t/unused/nodot"]
)

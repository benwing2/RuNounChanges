#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

templates_to_rewrite = {
  'sv-adj-form-abs-def': ['abs', 'def', 'form'],
  'sv-adj-form-abs-def+pl': ['abs', 's', 'def', 'and', 'p', 'form'],
  'sv-adj-form-abs-def-m': ['abs', 'def', 'natural', 'm', 'form'],
  'sv-adj-form-abs-indef-n': ['abs', 'indef', 'n', 'form'],
  'sv-adj-form-abs-pl': ['abs', 'p', 'form'],
  'sv-adj-form-comp': ['comp'],
  'sv-adj-form-comp-pl': ['comp', 'pl'],
  'sv-adj-form-sup-attr': ['sup', 'attr'],
  'sv-adj-form-sup-attr-m': ['sup', 'attr', 's', 'm'],
  'sv-adj-form-sup-pred': ['sup', 'pred'],
  'sv-adj-form-sup-pred-pl': ['sup', 'pred', 'p'],
  'sv-adv-form-comp': ['comp'],
  'sv-adv-form-sup': ['sup'],
  # 'sv-noun-form-adj': [?],
  'sv-noun-form-def': ['def', 's'],
  'sv-noun-form-def-gen': ['def', 'gen', 's'],
  'sv-noun-form-def-gen-pl': ['def', 'gen', 'p'],
  # 'sv-noun-form-def-pl': [?],
  'sv-noun-form-indef-gen': ['indef', 'gen', 's'],
  'sv-noun-form-indef-gen-pl': ['indef', 'gen', 'p'],
  'sv-noun-form-indef-pl': ['indef', 'p'],
  'sv-proper-noun-form-indef-pl': ['gen'],
  # 'sv-verb-form-imp': [?],
  'sv-verb-form-inf-pass': ['inf', 'pass'],
  # 'sv-verb-form-past': [?],
  # 'sv-verb-form-past-pass': [?],
  'sv-verb-form-past-part': ['past', 'part'],
  # 'sv-verb-form-pre': [?],
  'sv-verb-form-pre-pass': ['pres', 'pass'],
  'sv-verb-form-prepart': ['pres', 'part'],
  'sv-verb-form-pres-pass': ['pres', 'pass'],
  'sv-verb-form-subj': ['subj'],
  'sv-verb-form-sup': ['sup'],
  'sv-verb-form-sup-pass': ['sup', 'pass'],
}

from form_of_templates import (
  language_specific_alt_form_of_templates,
  alt_form_of_templates,
  language_specific_form_of_templates,
  form_of_templates
)

templates_to_process = form_of_templates + alt_form_of_templates + (
  language_specific_form_of_templates + language_specific_alt_form_of_templates
)

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "#invoke:form of/templates" and getparam(t, "1") == "template_tags":
      t.add("1", "tagged_form_of_t")
      notes.append("Rewrite {{#invoke:form of/templates|template_tags}} with {{#invoke:form of/templates|tagged_form_of_t}}")
    if tn == "#invoke:form of" and getparam(t, "1") in ["form_of_t", "alt_form_of_t"]:
      ignorelist = blib.fetch_param_chain(t, "ignorelist", "ignorelist")
      if ignorelist:
        ignore = blib.fetch_param_chain(t, "ignore", "ignore")
        for il in ignorelist:
          ignore.append(il + ":list")
        blib.set_param_chain(t, ignore, "ignore", "ignore", before="ignorelist")
        blib.remove_param_chain(t, "ignorelist", "ignorelist")
      blib.set_template_name(t, "#invoke:form of/templates")
      notes.append("Rewrite {{#invoke:form of|%s}} with {{#invoke:form of/templates|form_of_t}}"  % getparam(t, "1"))
    if tn == "#invoke:form of" and getparam(t, "1") == "alt_form_of_t":
      t.add("2", getparam(t, "text"), before="text")
      rmparam(t, "text")
      if t.has("nocap"):
        rmparam(t, "nocap")
      else:
        t.add("withcap", "1")
      if t.has("nodot"):
        rmparam(t, "nodot")
      else:
        t.add("withdot", "1")
      t.add("1", "form_of_t")

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Convert sv-* form-of templates to {{infl of}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, template in blib.iter_items(templates_to_process, start, end):
  page = pywikibot.Page(site, "Template:%s" % template)
  blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)

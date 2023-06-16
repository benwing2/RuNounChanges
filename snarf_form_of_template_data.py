#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

outlines = []

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)

  props = {}
  saw_invoke_form_of_templates = False
  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param)
    origt = str(t)
    tn = tname(t)
    if tn == "#invoke:form of/templates":
      if saw_invoke_form_of_templates:
        pagemsg("WARNING: Saw two module invocations of [[Module:form of/templates]]")
        return
      if getp("lang"):
        pagemsg("WARNING: Saw lang-specific form of template: %s" % str(t))
        return
      if getp("withcap"):
        props["withcap"] = True
      if getp("withdot"):
        props["withdot"] = True
      cats = blib.fetch_param_chain(t, "cat")
      cats = [re.sub("<!--.*?-->", "", cat, 0, re.S) for cat in cats]
      cats = [re.sub(r"\{\{#invoke:form of/templates\|normalize_pos\|\{\{#if:\{\{\{p\|\}\}\}\|\{\{\{p\|\}\}\}\|\{\{#if:\{\{\{POS\|\}\}\}\|\{\{\{POS\|\}\}\}\|(.*?)\}\}\}\}\}\}",
          r"{{{p|{{{POS|\1}}}}}}", cat) for cat in cats]
      if cats:
        props["cat"] = cats
      func = getp("1")
      if func == "form_of_t":
        formtext = getp("2")
        if "|show_from" in formtext:
          props["withfrom"] = True
        ignore = getp("ignore").split(",")
        if "POS" in ignore:
          props["withPOS"] = True
      elif func == "inflection_of_t":
        props["withtags"] = True
      elif func == "tagged_form_of_t":
        props["withPOS"] = True
  if not props:
    pagemsg("WARNING: Didn't see [[Module:form of/templates]] invocation")
    return
  aliases = []
  for i, subpage in blib.references(pagetitle, namespaces=[u"Template"], only_template_inclusion=False, filter_redirects=True):
    alias = str(subpage.title())
    num_refs = len(list(blib.references(alias, namespaces=[0])))
    pagemsg("Found alias '%s', num_refs=%s" % (alias, num_refs))
    aliases.append(re.sub("^Template:", "", alias))
  if aliases:
    pagemsg("Found aliases: %s" % ",".join(aliases))
    props["aliases"] = aliases
  props_key = {"aliases": 0, "withcap": 1, "withdot": 2, "withfrom": 3, "withPOS": 4, "withtags": 5, "cat": 6}
  propitems = sorted(props.items(), key=lambda x: props_key[x[0]])
  def valuestr(value):
    if type(value) is bool:
      return str(value)
    elif isinstance(value, basestring):
      return '"%s"' % value.replace('"', r'\"')
    else:
      return "[%s]" % ", ".join(valuestr(x) for x in value)
  propstr = ", ".join("%s: %s" % ('"%s"' % key, valuestr(value)) for key, value in propitems)
  outlines.append('  ("%s", {%s}),' % (re.sub("^Template:", "", pagetitle), propstr))

parser = blib.create_argparser("Generate input to make_form_of_table.py", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Form-of templates"])
msg("form_of_templates = [")
for line in outlines:
  msg(line)
msg("]")

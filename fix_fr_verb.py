#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Convert fr-conj-* templates to fr-conj-auto, checking in the process that
# the conjugation doesn't change.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru
import runounlib as runoun

templates_to_change = ["fr-conj-aillir", ...]

all_verb_props = [
  "inf", "pp", "ppr",
  "inf_nolink", "pp_nolink", "ppr_nolink",
  "ind_p_1s", "ind_p_2s", "ind_p_3s", "ind_p_1p", "ind_p_2p", "ind_p_3p",
  "ind_i_1s", "ind_i_2s", "ind_i_3s", "ind_i_1p", "ind_i_2p", "ind_i_3p",
  "ind_ps_1s", "ind_ps_2s", "ind_ps_3s", "ind_ps_1p", "ind_ps_2p", "ind_ps_3p",
  "ind_f_1s", "ind_f_2s", "ind_f_3s", "ind_f_1p", "ind_f_2p", "ind_f_3p",
  "cond_p_1s", "cond_p_2s", "cond_p_3s", "cond_p_1p", "cond_p_2p", "cond_p_3p",
  "sub_p_1s", "sub_p_2s", "sub_p_3s", "sub_p_1p", "sub_p_2p", "sub_p_3p",
  "sub_pa_1s", "sub_pa_2s", "sub_pa_3s", "sub_pa_1p", "sub_pa_2p", "sub_pa_3p",
  "imp_p_2s", "imp_p_1p", "imp_p_2p"
]

cached_template_calls = {}

def find_old_template_props(template, pagemsg):
  name = unicode(template.name)
  if name in cached_template_calls:
    template_text = cached_template_calls[name]
  else:
    template_page = pywikibot.Page(site, "Template:%s" % name)
    if not page.exists():
      pagemsg("WARNING: Can't locate template 'Template:%s'" % name)
      return None
    template_text = unicode(template_page.text)
    cached_template_calls[name] = template_text
  for t in blib.parse_text(template_text).filter_templates():
    if unicode(t.name) == "fr-conj":
      args = {}
      debug_args = []
      for param in t.params:
        pname = re.sub(r"\.", "_", unicode(param.name))
        pval = unicode(param.value)
        if pname in all_verb_props:
          pval = re.sub(r"\{\{\{1\}\}\}", getparam(template, "1"))
          debug_args.append("%s=%s" % (pname, pval))
          if not re.search(r"—", pval):
            args[pname] = pval
      pagemsg("Found args: %s" % "|".join(debug_args))
      return args
  pagemsg("WARNING: Can't find {{fr-conj}} in template definition for %s" %
      unicode(template))
  return None

def compare_conjugation(index, page, template, pagemsg, expand_text):
  generate_result = expand_text("{{fr-generate-verb-args}}")
  if not generate_result:
    return None
  args = {}
  for arg in re.split(r"\|", generate_result):
    name, value = re.split("=", arg)
    args[name] = re.sub("<!>", "|", value)
  existing_args = find_old_template_props(template)
  if existing_args is None:
    return None
  difvals = []
  for prop in all_verb_props:
    curval = existing_args.get(prop, "")
    newval = args.get(prop, "")
    if curval != newval:
      difvals.append((prop, (curval, newval)))
  return difvals

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping")
    return

  text = unicode(page.text)

  notes = []
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    name = unicode(t.name)
    if name in templates_to_change:
      difvals = compare_conjugation(index, page, t, pagemsg, expand_text)
      if difvals is None:
        pass
      elif difvals:
        difprops = []
        for prop, (oldval, newval) in difvals:
          difprops.append("%s=%s vs. %s" % (prop, oldval or "(missing)", newval or "(missing)"))
        pagemsg("WARNING: Different conjugation when changing template %s to {{fr-conj-auto}}: %s" %
            (unicode(t), "; ".join(difprops)))
      else:
        oldt = unicode(t)
        del t.params[:]
        t.name = "fr-conj-auto"
        newt = unicode(t)
        pagemsg("Replacing %s with %s" % (oldt, newt))
        notes.append("replaced {{%s}} with {{fr-conj-auto}}" % name)

  newtext = unicode(page.text)
  if newtext != text:
    assert notes
    comment = "; ".join(notes)
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = newtext
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser("Convert old fr-conj-* to fr-conj-auto")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for cat in ["French verbs"]:
  msg("Processing category: %s" % cat)
  for i, page in blib.cat_articles(cat, start, end):
    process_page(i, page, args.save, args.verbose)

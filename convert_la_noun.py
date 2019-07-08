#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, getrmparam, tname, msg, errandmsg, site, bool_param_is_true

import lalib

def compare_new_and_old_templates(origt, newt, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  old_forms = lalib.generate_noun_forms(origt, errandpagemsg, expand_text)
  if old_forms is None:
    errandpagemsg("WARNING: Error generating old forms, can't compare")
    return False
  new_generate_template = re.sub(r"^\{\{la-ndecl\|", "{{User:Benwing2/la-new-generate-noun-forms|", newt)
  new_result = expand_text(new_generate_template)
  if not new_result:
    errandpagemsg("WARNING: Error generating new forms, can't compare")
    return False
  new_forms = blib.split_generate_args(new_result)
  for form in set(old_forms.keys() + new_forms.keys()):
    if form not in new_forms:
      pagemsg("WARNING: form %s=%s in old forms but missing in new forms" % (
        form, old_forms[form]))
      return False
    if form not in old_forms:
      pagemsg("WARNING: form %s=%s in new forms but missing in old forms" % (
        form, new_forms[form]))
      return False
    if new_forms[form] != old_forms[form]:
      pagemsg("WARNING: form %s=%s in old forms but =%s in new forms" % (
        form, old_forms[form], new_forms[form]))
      return False
  pagemsg("%s and %s have same forms" % (origt, newt))
  return True

def convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg):
  origt = unicode(t)
  tn = tname(t)
  m = re.search(r"^la-decl-(.*)$", tn)
  if not m:
    pagemsg("WARNING: Something wrong, can't parse noun decl template name: %s" % tn)
    return None
  decl_suffix = m.group(1)
  if decl_suffix not in lalib.la_noun_decl_suffix_to_decltype:
    pagemsg("WARNING: Unrecognized noun decl template name: %s" % tn)
    return None
  retval = lalib.la_noun_decl_suffix_to_decltype[decl_suffix]
  if retval is None:
    pagemsg("WARNING: Unable to convert template: %s" % unicode(t))
    return None
  declspec, stem_suffix, pl_suffix, to_auto = retval
  if type(declspec) is tuple:
    declspec = declspec[0]
  if type(to_auto) is not tuple:
    to_auto = to_auto(t)
  for subtype in to_auto:
    if subtype.startswith('-'):
      pagemsg("WARNING: Inferred canceling subtype %s, need to verify: %s" % (subtype, unicode(t)))
  num = getrmparam(t, "num")
  if num == "pl" and pl_suffix:
    lemma = getparam(t, "1").strip() + pl_suffix
    num = None
  else:
    lemma = getparam(t, "1").strip() + stem_suffix
  stem2 = getparam(t, "2").strip()
  subtypes = list(to_auto)
  if num:
    subtypes.append(num)
  loc = getrmparam(t, "loc")
  if bool_param_is_true(loc):
    subtypes.append("loc")
  lig = getrmparam(t, "lig")
  if bool_param_is_true(lig):
    subtypes.append("lig")
  um = getrmparam(t, "um")
  genplum = getrmparam(t, "genplum")
  if bool_param_is_true(um) or bool_param_is_true(genplum):
    subtypes.append("genplum")
  sufn = getrmparam(t, "n")
  if bool_param_is_true(sufn):
    subtypes.append("sufn")
  blib.set_template_name(t, "la-ndecl")
  # Fetch all params
  named_params = []
  for param in t.params:
    pname = unicode(param.name)
    if pname.strip() in ["1", "2", "noun"]:
      continue
    named_params.append((pname, param.value, param.showkey))
  # Erase all params
  del t.params[:]
  # Put back params
  if stem2:
    lemma += "/" + stem2
  lemma += "<%s>" % ".".join([declspec] + subtypes)
  t.add("1", lemma)
  for name, value, showkey in named_params:
    t.add(name, value, showkey=showkey, preserve_spacing=False)
  pagemsg("Replaced %s with %s" % (origt, unicode(t)))
  compare_new_and_old_templates(origt, unicode(t), pagetitle, pagemsg, errandpagemsg)
  return t

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in lalib.la_noun_decl_templates:
      if convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg):
        notes.append("converted {{%s}} to {{la-ndecl}}" % tn)

  return unicode(parsed), notes

parser = blib.create_argparser("Convert Latin noun decl templates to new form")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for cat in ["Latin nouns", "Latin proper nouns"]:
#for cat in ["Latin proper nouns"]:
  for i, page in blib.cat_articles(cat, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)

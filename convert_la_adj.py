#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, getrmparam, tname, msg, errandmsg, site

# FIXME: Out of date script, not needed any more, might not still work.

def la_adj_1_and_2_subtype(stem1, stem2, decl, types, num, g, is_adj, pagetitle, pagemsg):
  if stem2:
    pagemsg("WARNING: stem2=%s should not be present with 1&2 adjectives" %
        stem2)
    stem2 = ""
  set_stem1 = False
  if stem1.endswith("(e)r"):
    if num == "pl":
      stem2 = stem1[:-4] + ("rae" if g == "F" else u"rī")
    elif g in ["F", "N"]:
      stem2 = stem1[:-4] + ("ra" if g == "F" else u"rum")
    else:
      stem2 = stem1[:-4] + "r"
      stem1 = stem1[:-4] + "er"
    set_stem1 = True
  elif stem1.endswith("er") or stem1.endswith("ur"):
    macronless_stem1 = remove_macrons(stem1)
    if macronless_stem1 != pagetitle and macronless_stem1 + "us" != pagetitle:
      pagemsg("WARNING: Potential 1&2 adjective ending in -er or -ur, but pagetitle=%s not same" %
          pagetitle)
    if macronless_stem1 == pagetitle:
      if num == "pl":
        stem1 += ("ae" if g == "F" else u"ī")
      elif g in ["F", "N"]:
        stem1 += ("a" if g == "F" else "um")
      set_stem1 = True
  if not set_stem1:
    if "greekA" in types or "greekE" in types:
      stem1 += ("on" if g == "N" else "os")
      types = [x for x in types if x != "greekA"]
      if num == "pl":
        types = types + ["pl"]
    elif "ic" in types:
      stem1 += "ic"
      types = [x for x in types if x != "ic"]
    elif num == "pl":
      stem1 += ("ae" if g == "F" else u"ī")
    else:
      stem1 += ("a" if g == "F" else "um" if g == "N" else "us")
  types = ["lig" if x == "ea" else x for x in types]
  return stem1, stem2, "", types

def la_adj_1_1_subtype(stem1, stem2, decl, types, num, g, is_adj, pagetitle, pagemsg):
  if stem2:
    pagemsg("WARNING: stem2=%s should not be present with 1-1 adjectives" %
        stem2)
    stem2 = ""
  stem1 += "ae" if num == "pl" else "a"
  return stem1, stem2, decl, types

def la_adj_2_2_subtype(stem1, stem2, decl, types, num, g, is_adj, pagetitle, pagemsg):
  if stem2:
    pagemsg("WARNING: stem2=%s should not be present with 2-2 adjectives" %
        stem2)
    stem2 = ""
  if num == "pl":
    stem1 += "a" if g == "N" else u"ī"
  else:
    stem1 += "um" if g == "N" else u"us"
  return stem1, stem2, decl, types

def la_adj_3rd_1E_subtype(stem1, stem2, decl, types, num, g, is_adj, pagetitle, pagemsg):
  if "par" in types:
    types = ["-I" if x == "par" else x for x in types]
  if num == "pl":
    types = types + ["pl"]
  if stem2 == infer_3rd_decl_stem(stem1):
    stem2 = ""
  if re.search("(is|[ij]or|e)$", stem1):
    pagemsg("WARNING: Possible wrongly tagged adj, decl=3-1, stem1=%s, stem2=%s" % (
      stem1, stem2))
    decl = "3-1"
  elif stem1.endswith("er"):
    # Just 3 is detected as 3-3
    decl = "3-1"
  elif re.search(u"(us|a|um|ī|ae|ur|os|ē|on)$", stem1) or stem1 == "hic":
    decl = "3"
  else:
    decl = ""
  return stem1, stem2, decl, types

def la_adj_3rd_2E_subtype(stem1, stem2, decl, types, num, g, is_adj, pagetitle, pagemsg):
  if num == "pl":
    types = types + ["pl"]
  if stem2:
    pagemsg("WARNING: stem2=%s present with decl=3-2" % stem2)
    stem2 = ""
  stem1 += ("e" if g == "N" else "is")
  decl = ""
  return stem1, stem2, decl, types

def la_adj_3rd_3E_subtype(stem1, stem2, decl, types, num, g, is_adj, pagetitle, pagemsg):
  if num == "pl":
    types = types + ["pl"]
  if stem2 == infer_3rd_decl_stem(stem1):
    stem2 = ""
  if not stem1.endswith("er"):
    pagemsg("WARNING: Possible wrongly tagged adj, decl=3-3, stem1=%s, stem2=%s" % (
      stem1, stem2))
    decl = "3-2"
  else:
    decl = "3" # need to indicate 3 to distinguish from 1&2 adjs in -er
  if g in ["F", "N"]:
    stem1 = stem2 + ("is" if g == "F" else "e")
    stem2 = ""
  return stem1, stem2, decl, types

def la_adj_3rd_comp_subtype(stem1, stem2, decl, types, num, g, is_adj, pagetitle, pagemsg):
  if num == "pl":
    types = types + ["pl"]
  if stem2:
    if stem2 == "j":
      stem1 += "jor"
      stem2 = ""
    elif stem2 == "n" and stem1 == "mi":
      stem1 = "minor"
      stem2 = ""
    else:
      pagemsg("WARNING: strange stem2=%s present with decl=3-C" % stem2)
  else:
    stem1 += "ior"
  decl = ""
  return stem1, stem2, decl, types

def la_adj_3rd_part_subtype(stem1, stem2, decl, types, num, g, is_adj, pagetitle, pagemsg):
  if num == "pl":
    types = types + ["pl"]
  if not re.search(u"[āē]ns$", stem1):
    pagemsg("WARNING: strange stem1=%s present with decl=3-P" % stem1)
  if stem2 and not stem2.endswith("eunt"):
    pagemsg("WARNING: strange stem2=%s present with decl=3-P" % stem2)
  return stem1, stem2, decl, types

def la_adj_irreg_subtype(stem1, stem2, decl, types, num, g, is_adj, pagetitle, pagemsg):
  if num == "pl":
    types = types + ["pl"]
  if stem1 == "qui":
    stem1 = u"quī"
  # duo, ambō converted by hand
  return stem1, stem2, decl, types

la_adj_decl_suffix_to_decltype = {
  'decl-1&2': ['1&2', la_adj_1_and_2_subtype],
  'adecl-1st': ['1-1', la_adj_1_1_subtype],
  'adecl-2nd': ['2-2', la_adj_2_2_subtype],
  'decl-3rd-1E': ['3-1', la_adj_3rd_1E_subtype],
  'decl-3rd-2E': ['3-2', la_adj_3rd_2E_subtype],
  'decl-3rd-3E': ['3-3', la_adj_3rd_3E_subtype],
  'decl-3rd-comp': ['3-C', la_adj_3rd_comp_subtype],
  'decl-3rd-part': ['3-P', la_adj_3rd_part_subtype],
  'decl-irreg': ['irreg', la_adj_irreg_subtype],
}

adj_decl_and_subtype_to_props = {}
for key, val in la_adj_decl_suffix_to_decltype.iteritems():
  decl, compute_props = val
  adj_decl_and_subtype_to_props[decl] = [key, compute_props]

old_la_adj_decl_templates = {
  "la-decl-1&2",
  "la-adecl-1st",
  "la-adecl-2nd",
  "la-decl-3rd-1E",
  "la-decl-3rd-2E",
  "la-decl-3rd-3E",
  "la-decl-3rd-comp",
  "la-decl-3rd-part",
  "la-decl-irreg",
  "la-decl-multi",
}

def generate_old_adj_forms(template, errandpagemsg, expand_text, return_raw=False,
    include_linked=False):

  def generate_adj_forms_prefix(m):
    decl_suffix_to_decltype = {
      'decl-1&2': '1&2',
      'decl-3rd-1E': '3-1',
      'decl-3rd-2E': '3-2',
      'decl-3rd-3E': '3-3',
      'decl-3rd-comp': '3-C',
      'decl-3rd-part': '3-P',
      'adecl-1st': '1-1',
      'adecl-2nd': '2-2',
      'decl-irreg': 'irreg',
    }
    if m.group(1) in decl_suffix_to_decltype:
      return "{{la-generate-adj-forms|decltype=%s|" % (
        decl_suffix_to_decltype[m.group(1)]
      )
    return m.group(0)

  if template.startswith("{{la-adecl|"):
    generate_template = re.sub(r"^\{\{la-adecl\|", "{{la-generate-adj-forms|",
        template)
  else:
    generate_template = re.sub(r"^\{\{la-(.*?)\|", generate_adj_forms_prefix,
        template)
  if not generate_template.startswith("{{la-generate-adj-forms|"):
    errandpagemsg("Template %s not a recognized adjective declension template" % template)
    return None
  result = expand_text(generate_template)
  if return_raw:
    return None if result is False else result
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return None
  args = blib.split_generate_args(result)
  if not include_linked:
    args = {k: v for k, v in args.iteritems() if not k.startswith("linked_")}
  # Add missing feminine forms if needed
  augmented_args = {}
  for key, form in args.iteritems():
    augmented_args[key] = form
    if key.endswith("_m"):
      equiv_fem = key[:-2] + "_f"
      if equiv_fem not in args:
        augmented_args[equiv_fem] = form
  return augmented_args

def compare_new_and_old_templates(origt, newt, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  def generate_old_forms():
    return generate_old_adj_forms(origt, errandpagemsg, expand_text, return_raw=True)

  def generate_new_forms():
    new_generate_template = re.sub(r"^\{\{la-adecl\|", "{{User:Benwing2/la-new-generate-adj-forms|", newt)
    new_result = expand_text(new_generate_template)
    if not new_result:
      return None
    return new_result

  return blib.compare_new_and_old_template_forms(origt, newt, generate_old_forms,
    generate_new_forms, pagemsg, errandpagemsg)

def convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg):
  origt = str(t)
  tn = tname(t)
  m = re.search(r"^la-(.*)$", tn)
  if not m:
    pagemsg("WARNING: Something wrong, can't parse adj decl template name: %s" % tn)
    return None
  decl_suffix = m.group(1)
  if decl_suffix not in la_adj_decl_suffix_to_decltype:
    pagemsg("WARNING: Unrecognized adj decl template name: %s" % tn)
    return None
  decl, compute_props = la_adj_decl_suffix_to_decltype[decl_suffix]
  stem1 = getparam(t, "1").strip()
  stem2 = getparam(t, "2").strip()
  num = getrmparam(t, "num")
  specified_subtypes = getrmparam(t, "type")
  if specified_subtypes:
    specified_subtypes = specified_subtypes.split("-")
  else:
    specified_subtypes = []
  lemma, stem2, decl, subtypes = (
    compute_props(stem1, stem2, decl, specified_subtypes, num, None, True,
      pagetitle, pagemsg)
  )
  if num == "sg":
    subtypes.append("sg")
  decl += "+"
  blib.set_template_name(t, "la-adecl")
  # Fetch all params
  named_params = []
  for param in t.params:
    pname = str(param.name)
    if pname.strip() in ["1", "2", "noun"]:
      continue
    named_params.append((pname, param.value, param.showkey))
  # Erase all params
  del t.params[:]
  # Put back params
  if stem2:
    lemma += "/" + stem2
  subtypes = [decl] + subtypes
  if subtypes != ["+"]:
    lemma += "<%s>" % ".".join(subtypes)
  t.add("1", lemma)
  for name, value, showkey in named_params:
    t.add(name, value, showkey=showkey, preserve_spacing=False)
  pagemsg("Replaced %s with %s" % (origt, str(t)))
  if compare_new_and_old_templates(origt, str(t), pagetitle, pagemsg, errandpagemsg):
    return t
  else:
    return None

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "la-decl-multi":
      pagemsg("Skipping la-decl-multi for now: %s" % str(t))
    elif tn == "la-decl-irreg" and getparam(t, "noun"):
      pagemsg("Skipping noun la-decl-irreg: %s" % str(t))
    elif tn in old_la_adj_decl_templates:
      if convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg):
        notes.append("converted {{%s}} to {{la-adecl}}" % tn)
      else:
        return None, None

  return str(parsed), notes

if __name__ == "__main__":
  parser = blib.create_argparser("Convert Latin adj decl templates to new form",
      include_pagefile=True)
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_cats=["Latin adjectives"], edit=True)

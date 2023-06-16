#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

import rulib

def add_rel_adj_or_dim_to_noun_page(nounpage, index, new_adj_or_dims, param, desc):
  notes = []
  pagetitle = str(nounpage.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  text = str(nounpage.text)
  retval = blib.find_modifiable_lang_section(text, "Russian", pagemsg)
  if retval is None:
    pagemsg("WARNING: Couldn't find Russian section for noun of %s %s" % (
      desc, ",".join(new_adj_or_dims)))
    return
  sections, j, secbody, sectail, has_non_lang = retval
  parsed = blib.parse_text(secbody)
  head = None
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["ru-noun+", "ru-proper noun+", "ru-noun", "ru-proper noun"]:
      if head:
        pagemsg("WARNING: Saw multiple heads %s and %s for noun of %s %s, not modifying" %
            (str(head), str(t), desc, ",".join(new_adj_or_dims)))
        return
      head = t
  if not head:
    pagemsg("WARNING: Couldn't find head for noun of %s %s" % (desc, ",".join(new_adj_or_dims)))
    return
  orig_adjs_or_dims = blib.fetch_param_chain(head, param, param)
  adjs_or_dims = blib.fetch_param_chain(head, param, param)
  added_adjs_or_dims = []
  for adj_or_dim in new_adj_or_dims:
    if adj_or_dim in adjs_or_dims:
      pagemsg("Already saw %s %s in head %s" % (desc, adj_or_dim, str(head)))
    else:
      adjs_or_dims.append(adj_or_dim)
      added_adjs_or_dims.append(adj_or_dim)
  if adjs_or_dims != orig_adjs_or_dims:
    orighead = str(head)
    blib.set_param_chain(head, adjs_or_dims, param, param)
    pagemsg("Replaced %s with %s" % (orighead, str(head)))
    notes.append("add %s=%s to Russian noun" % (param, ",".join(added_adjs_or_dims)))
    secbody = str(parsed)
  subsecs = re.split("(^==.*==\n)", secbody, 0, re.M)
  for k in range(2, len(subsecs), 2):
    if "==Derived terms==" in subsecs[k - 1] or "==Related terms==" in subsecs[k - 1]:
      header = re.sub("=", "", subsecs[k - 1]).strip()
      for adj_or_dim in adjs_or_dims:
        def note_removed_text(m):
          if m.group(1):
            pagemsg("Removed '%s' term with gloss for noun of %s %s: %s" %
                (header, desc, adj_or_dim, m.group(0)))
          return ""
        newsubsecsk = re.sub(r"\{\{[lm]\|ru\|%s((?:\|[^{}\n]*)?)\}\}" % adj_or_dim, note_removed_text, subsecs[k])
        if newsubsecsk != subsecs[k]:
          notes.append("remove %s %s from %s" % (desc, adj_or_dim, header))
        subsecs[k] = newsubsecsk
        subsecs[k] = re.sub(", *,", ",", subsecs[k])
        # Repeat in case adjacent terms removed (unlikely though).
        subsecs[k] = re.sub(", *,", ",", subsecs[k])
        subsecs[k] = re.sub(" *, *$", "", subsecs[k], 0, re.M)
        subsecs[k] = re.sub(r"^\* *, *", "* ", subsecs[k], 0, re.M)
        subsecs[k] = re.sub(r"^\* *(\n|$)", "", subsecs[k], 0, re.M)
      if re.search(r"^\s*$", subsecs[k]):
        subsecs[k] = ""
        subsecs[k - 1] = ""
  secbody = "".join(subsecs)
  secj = secbody + sectail
  newsecj = re.sub(r"\n\n\n+", "\n\n", secj)
  if newsecj != secj and not notes:
    notes.append("eliminate sequences of 3 or more newlines")
  secj = newsecj
  sections[j] = secj
  return "".join(sections), notes

def add_rel_adj_or_dim_to_noun(index, adjs_or_dims, noun, param, desc):
  pagetitle = rulib.remove_accents(blib.remove_links(noun))
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  nounpage = pywikibot.Page(site, pagetitle)
  if not blib.safe_page_exists(nounpage, pagemsg):
    pagemsg("WARNING: Noun %s for %s %s doesn't exist" % (noun, desc, ",".join(adjs_or_dims))
    return
  def do_add_rel_adj_or_dim_to_noun_page(page, index, parsed):
    return add_rel_adj_or_dim_to_noun_page(page, index, adjs_or_dims, param, desc)
  blib.do_edit(nounpage, index, do_add_rel_adj_or_dim_to_noun_page, save=args.save, verbose=args.verbose,
    diff=args.diff)

def process_section_for_relational_adj_snarf(index, pagetitle, text, is_multi_etym_section):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  if not re.search(r"\{\{lb\|ru\|([^{}]*\|)*relational[|}]", text):
    pagemsg("Not a relational adjective")
    return
  parsed = blib.parse_text(text)
  adj = None
  for t in parsed.filter_templates():
    if tname(t) == "ru-adj":
      if getparam(t, "head2"):
        pagemsg("WARNING: Multihead relational adjective %s, skipping" % str(t))
        return
      newadj = getparam(t, "1") or pagetitle
      if adj and adj != newadj:
        pagemsg("WARNING: Saw multiple adjectives %s and %s on relational page, skipping: head=%s" %
            (adj, newadj, str(t)))
        return
      if "[[" in newadj:
        pagemsg("WARNING: Saw links in relational adjective %s, skipping: head=%s" % (
          newadj, str(t)))
        return
      adj = newadj
  subsecs = re.split("(^==.*==\n)", text, 0, re.M)
  if is_multi_etym_section:
    etymtext = subsecs[0]
  else:
    for k in range(2, len(subsecs), 2):
      if "==Etymology==" in subsecs[k - 1]:
        etymtext = subsecs[k]
        break
    else:
      pagemsg("WARNING: Relational adjective %s but couldn't find etymology section" % adj)
      return
  parsed = blib.parse_text(etymtext)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["affix", "af", "suffix", "suf"] and getparam(t, "1") == "ru":
      noun = getparam(t, "2")
      if getparam(t, "lang1"):
        pagemsg("WARNING: lang1= in affix template %s for relational adjective %s" % (str(t), adj))
      elif noun.endswith("-"):
        pagemsg("WARNING: Prefix %s found as putative source noun for relational adjective %s: affix template %s" %
            (noun, adj, str(t)))
      elif noun.startswith("-"):
        pagemsg("WARNING: Suffix %s found as putative source noun for relational adjective %s: affix template %s" %
            (noun, adj, str(t)))
      elif not noun:
        pagemsg("WARNING: Blank string found as putative source noun for relational adjective %s: affix template %s" %
            (adj, str(t)))
      elif tn in ["affix", "af"] and not getparam(t, "3").startswith("-"):
        pagemsg("WARNING: Apparent compound etymology for relational adjective %s, skipping: affix template %s" %
            (adj, str(t)))
      elif tn in ["affix", "af"] and getparam(t, "3").endswith("-"):
        pagemsg("WARNING: Infix %s, hence apparent compound etymology for relational adjective %s, skipping: affix template %s" %
            (getparam(t, "3"), adj, str(t)))
      else:
        msg("%s ||| %s" % (adj, noun))
        break
  else:
    pagemsg("WARNING: Relational adjective %s, found etymology section but not affix template" % adj)

def snarf_relational_adjs(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  #retval = blib.find_modifiable_lang_section(text, "Russian", pagemsg)
  #if retval is None:
  #  pagemsg("WARNING: Couldn't find Russian section")
  #  return
  #sections, j, secbody, sectail, has_non_lang = retval
  secbody = text
  if "Etymology 1" in secbody:
    etym_sections = re.split("(^===Etymology [0-9]+===\n)", secbody, 0, re.M)
    for k in range(2, len(etym_sections), 2):
      process_section_for_relational_adj_snarf(index, pagetitle, etym_sections[k], True)
  else:
    process_section_for_relational_adj_snarf(index, pagetitle, secbody, False)

def process_section_for_diminutive_snarf(index, pagetitle, text, is_multi_etym_section):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)
  parsed = blib.parse_text(text)

  saw_dim = False
  for t in parsed.filter_templates():
    if tname(t) in ["diminutive of", "dim of", "endearing diminutive of"]:
      saw_dim = True
  if not saw_dim:
    return

  nount = None
  saw_dim = False
  for t in parsed.filter_templates():
    if tname(t) in ["ru-noun+", "ru-noun"]:
      if nount and not saw_dim:
        pagemsg("WARNING: Saw multiple heads (first=%s, second=%s), the first of which may or may not be a diminutive" % (
          str(nount), str(t)))
      nount = t
      saw_dim = False
    if tname(t) in ["diminutive of", "dim of", "endearing diminutive of"]:
      if not nount:
        pagemsg("WARNING: Didn't see head for diminutive noun, skipping")
        return
      if tname(nount) == "ru-noun":
        heads = blib.fetch_param_chain(nount, "1", "head")
      else:
        nounargs = rulib.fetch_noun_args(nount, expand_text, forms_only=True)
        if not nounargs:
          return
        if "nom_sg" in nounargs:
          heads = nounargs["nom_sg"].split(",")
        else:
          heads = nounargs["nom_pl"].split(",")
      saw_dim = True
      dimofs = blib.remove_links(getparam(t, "2"))
      for dimof in re.split(", *", dimofs):
        msg("%s ||| %s" % (",".join(heads), dimof))

def snarf_diminutives(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  #retval = blib.find_modifiable_lang_section(text, "Russian", pagemsg)
  #if retval is None:
  #  pagemsg("WARNING: Couldn't find Russian section")
  #  return
  #sections, j, secbody, sectail, has_non_lang = retval
  secbody = text
  if "Etymology 1" in secbody:
    etym_sections = re.split("(^===Etymology [0-9]+===\n)", secbody, 0, re.M)
    for k in range(2, len(etym_sections), 2):
      process_section_for_diminutive_snarf(index, pagetitle, etym_sections[k], True)
  else:
    process_section_for_diminutive_snarf(index, pagetitle, secbody, False)

parser = blib.create_argparser("Snarf Russian relational adjectives or diminutives or add to corresponding noun",
  include_pagefile=True, include_stdin=True)
parser.add_argument('--direcfile', help="File of adjectives/diminutives and nouns, from a previous run of same script")
parser.add_argument('--pos', help="Part of speech ('reladj' or 'dim')", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.direcfile:
  for index, line in blib.iter_items_from_file(args.direcfile, start, end):
    if " ||| " in line:
      adj_or_dim, noun = re.split(r" \|\|\| ", line)
    else:
      adj_or_dim, noun = re.split(" ", line)
    adjs_or_dims = adj_or_dim.split(",")
    if args.pos == "reladj":
      add_rel_adj_or_dim_to_noun(index, adjs_or_dims, noun, 'adj', 'relational adjective')
    else:
      add_rel_adj_or_dim_to_noun(index, adjs_or_dims, noun, 'dim', 'diminutive')
else:
  def process_text_on_page(index, pagename, text):
    if args.pos == "reladj":
      snarf_relational_adjs(index, pagename, text)
    else:
      snarf_diminutives(index, pagename, text)
  blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, stdin=True)

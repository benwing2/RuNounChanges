#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

import rulib

import find_regex

def add_rel_adj_to_noun_page(nounpage, index, adj):
  notes = []
  pagetitle = unicode(nounpage.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  text = unicode(nounpage.text)
  retval = blib.find_modifiable_lang_section(text, "Russian", pagemsg)
  if retval is None:
    pagemsg("WARNING: Couldn't find Russian section for noun of relational adjective %s" % adj)
    return
  sections, j, secbody, sectail, has_non_lang = retval
  parsed = blib.parse_text(secbody)
  head = None
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["ru-noun+", "ru-proper noun+", "ru-noun", "ru-proper noun"]:
      if head:
        pagemsg("WARNING: Saw multiple heads %s and %s for noun of relational adjective %s, not modifying" %
            (unicode(head), unicode(t), adj))
        return
      head = t
  if not head:
    pagemsg("WARNING: Couldn't find head for noun of relational adjective %s" % adj)
    return
  adjs = blib.fetch_param_chain(head, "adj", "adj")
  if adj in adjs:
    pagemsg("Already saw adjective %s in head %s" % (adj, unicode(head)))
  else:
    adjs.append(adj)
    orighead = unicode(head)
    blib.set_param_chain(head, adjs, "adj", "adj")
    pagemsg("Replaced %s with %s" % (orighead, unicode(head)))
    notes.append("add adj=%s to Russian noun" % adj)
    secbody = unicode(parsed)
  subsecs = re.split("(^==.*==\n)", secbody, 0, re.M)
  for k in xrange(2, len(subsecs), 2):
    if "==Derived terms==" in subsecs[k - 1] or "==Related terms==" in subsecs[k - 1]:
      header = re.sub("=", "", subsecs[k - 1]).strip()
      origsubsecsk = subsecs[k]
      def note_removed_text(m):
        if m.group(1):
          pagemsg("Removed '%s' term with gloss for noun of relational adjective %s: %s" %
              (header, adj, m.group(0)))
        return ""
      subsecs[k] = re.sub(r"\{\{[lm]\|ru\|%s((?:\|[^{}\n]*)?)\}\}" % adj, note_removed_text, subsecs[k])
      subsecs[k] = re.sub(", *,", ",", subsecs[k])
      # Repeat in case adjacent terms removed (unlikely though).
      subsecs[k] = re.sub(", *,", ",", subsecs[k])
      subsecs[k] = re.sub(" *, *$", "", subsecs[k], 0, re.M)
      subsecs[k] = re.sub(r"^\* *, *", "* ", subsecs[k], 0, re.M)
      subsecs[k] = re.sub(r"^\* *(\n|$)", "", subsecs[k], 0, re.M)
      if re.search(r"^\s*$", subsecs[k]):
        subsecs[k] = ""
        subsecs[k - 1] = ""
      if origsubsecsk != subsecs[k]:
        notes.append("remove adj %s from %s" % (adj, header))
  secbody = "".join(subsecs)
  secj = secbody + sectail
  newsecj = re.sub(r"\n\n\n+", "\n\n", secj)
  if newsecj != secj and not notes:
    notes.append("eliminate sequences of 3 or more newlines")
  secj = newsecj
  sections[j] = secj
  return "".join(sections), notes

def add_rel_adj_to_noun(index, adj, noun):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, adj, txt))
  nounpage = pywikibot.Page(site, rulib.remove_accents(blib.remove_links(noun)))
  if not blib.safe_page_exists(nounpage, pagemsg):
    pagemsg("WARNING: Noun %s for adjective %s doesn't exist" % (noun, adj))
    return
  def do_add_rel_adj_to_noun_page(page, index, parsed):
    return add_rel_adj_to_noun_page(page, index, adj)
  blib.do_edit(nounpage, index, do_add_rel_adj_to_noun_page, save=args.save, verbose=args.verbose,
    diff=args.diff)

def process_section_for_snarf(index, pagetitle, text, is_multi_etym_section):
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
        pagemsg("WARNING: Multihead relational adjective %s, skipping" % unicode(t))
        return
      newadj = getparam(t, "1") or pagetitle
      if adj and adj != newadj:
        pagemsg("WARNING: Saw multiple adjectives %s and %s on relational page, skipping: head=%s" %
            (adj, newadj, unicode(t)))
        return
      if "[[" in newadj:
        pagemsg("WARNING: Saw links in relational adjective %s, skipping: head=%s" % (
          newadj, unicode(t)))
        return
      adj = newadj
  subsecs = re.split("(^==.*==\n)", text, 0, re.M)
  if is_multi_etym_section:
    etymtext = subsecs[0]
  else:
    for k in xrange(2, len(subsecs), 2):
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
        pagemsg("WARNING: lang1= in affix template %s for relational adjective %s" % (unicode(t), adj))
      elif noun.endswith("-"):
        pagemsg("WARNING: Prefix %s found as putative source noun for relational adjective %s: affix template %s" %
            (noun, adj, unicode(t)))
      elif noun.startswith("-"):
        pagemsg("WARNING: Suffix %s found as putative source noun for relational adjective %s: affix template %s" %
            (noun, adj, unicode(t)))
      elif not noun:
        pagemsg("WARNING: Blank string found as putative source noun for relational adjective %s: affix template %s" %
            (adj, unicode(t)))
      elif tn in ["affix", "af"] and not getparam(t, "3").startswith("-"):
        pagemsg("WARNING: Apparent compound etymology for relational adjective %s, skipping: affix template %s" %
            (adj, unicode(t)))
      elif tn in ["affix", "af"] and getparam(t, "3").endswith("-"):
        pagemsg("WARNING: Infix %s, hence apparent compound etymology for relational adjective %s, skipping: affix template %s" %
            (getparam(t, "3"), adj, unicode(t)))
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
    for k in xrange(2, len(etym_sections), 2):
      process_section_for_snarf(index, pagetitle, etym_sections[k], True)
  else:
    process_section_for_snarf(index, pagetitle, secbody, False)

parser = blib.create_argparser("Add relational adjectives to corresponding Russian noun",
  include_pagefile=True)
parser.add_argument('--direcfile', help="File of adjectives and nouns")
parser.add_argument('--textfile', help="File of find_regex output")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.direcfile:
  lines = codecs.open(args.direcfile, "r", "utf-8")
  for index, line in blib.iter_items(lines, start, end):
    line = line.strip()
    if " ||| " in line:
      adj, noun = re.split(r" \|\|\| ", line)
    else:
      adj, noun = re.split(" ", line)
    add_rel_adj_to_noun(index, adj, noun)
elif args.textfile:
  lines = codecs.open(args.textfile, "r", "utf-8")
  pagename_and_text = find_regex.yield_text_from_find_regex(lines, args.verbose)
  for index, (pagename, text) in blib.iter_items(pagename_and_text, start, end,
      get_name=lambda x:x[0]):
    snarf_relational_adjs(index, pagename, text)

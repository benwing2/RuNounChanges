#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, errandmsg, site

def process_page(page, index, line, respelling, orig_template, repl_template,
    args):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if respelling == "-":
    pagemsg("Skipping line with respelling '-': %s" % line)
    return

  if respelling == "":
    pagemsg("WARNING: Skipping blank respelling: %s" % line)
    return

  notes = []

  text = str(page.text)
  if orig_template not in text:
    pagemsg("WARNING: Can't find original template %s in text" % orig_template)
    return

  m = re.search("^.*?%s.*$" % re.escape(orig_template), text, re.M)
  if not m:
    pagemsg("WARNING: Couldn't find template %s in page text" % orig_template)
    textline = "(unknown)"
  else:
    textline = m.group(0)

  m = re.search(r"(\|pos=[a-z]+)", repl_template)
  if m:
    posarg = m.group(1)
  else:
    posarg = ""
  if respelling == "y":
    respellingarg = ""
  else:
    respellingarg = "|" + "|".join(respelling.split(","))
  real_repl = "{{fr-IPA%s%s}}" % (respellingarg, posarg)

  if "{{a|" in textline:
    pagemsg("WARNING: Replacing %s with %s and saw accent spec on line: %s" % (
      orig_template, real_repl, textline))

  newtext, did_replace = blib.replace_in_text(text, orig_template,
      real_repl, pagemsg)
  text = newtext
  if did_replace:
    notes.append("semi-manually replace %s with %s" % (orig_template, real_repl))
  if respelling != "y":
    parsed = blib.parse_text(text)
    saw_fr_conj_auto = False
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "fr-conj-auto":
        if saw_fr_conj_auto:
          pagemsg("WARNING: Saw {{fr-conj-auto}} twice, first=%s, second=%s" % (
            saw_fr_conj_auto, str(t)))
        saw_fr_conj_auto = str(t)
        if getparam(t, "pron"):
          pagemsg("WARNING: Already saw pron= param: %s" % str(t))
          continue
        pronarg = ",".join(pron or pagetitle for pron in respelling.split(","))
        origt = str(t)
        t.add("pron", pronarg)
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("add pron=%s to {{fr-conj-auto}}" % pronarg)
    text = str(parsed)

  return text, notes

parser = blib.create_argparser("Push manual {{fr-IPA}} replacements for {{IPA|fr}}")
parser.add_argument("--direcfile", help="File of directives", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for index, line in blib.iter_items_from_file(args.direcfile, start, end):
  m = re.search(r"^(.*?)\|Page [0-9]+ (.*?): WARNING: Can't replace (\{\{IPA\|fr\|.*?\}\}) with (\{\{.*?\}\}) because auto-generated pron .*$", line)
  if not m:
    errandmsg("Line %s: Unrecognized line: %s" % (index, line))
    continue
  respelling, page, orig_template, repl_template = m.groups()
  def do_process_page(page, index, parsed):
    return process_page(page, index, line, respelling, orig_template,
        repl_template, args)
  blib.do_edit(pywikibot.Page(site, page), index, do_process_page,
    save=args.save, verbose=args.verbose, diff=args.diff)

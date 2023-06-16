#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Delete erroneously created forms given the declensions that led to those
# forms being created.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def process_decl(index, pagetitle, decl, forms, save, verbose):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  if decl.startswith("{{ru-conj|"):
    tempcall = re.sub(r"^\{\{ru-conj", "{{ru-generate-verb-forms", decl)
  elif decl.startswith("{{ru-noun-table"):
    tempcall = re.sub(r"^\{\{ru-noun-table", "{{ru-generate-noun-args", decl)
  else:
    pagemsg("WARNING: Unrecognized decl template, skipping: %s" % decl)
    return

  result = expand_text(tempcall)
  if not result:
    pagemsg("WARNING: Error generating forms, skipping")
    return
  args = blib.split_generate_args(result)

  for form in forms:
    if form in args:
      for formpagename in re.split(",", args[form]):
        formpagename = re.sub("//.*$", "", formpagename)
        formpagename = rulib.remove_accents(formpagename)
        formpage = pywikibot.Page(site, formpagename)
        if not formpage.exists():
          pagemsg("WARNING: Form page %s doesn't exist, skipping" % formpagename)
        elif formpagename == pagetitle:
          pagemsg("WARNING: Attempt to delete dictionary form, skipping")
        else:
          text = str(formpage.text)
          if "Etymology 1" in text:
            pagemsg("WARNING: Found 'Etymology 1', skipping form %s" % formpagename)
          else:
            skip_form = False
            for m in re.finditer(r"^==([^=]*?)==$", text, re.M):
              if m.group(1) != "Russian":
                pagemsg("WARNING: Found entry for non-Russian language %s, skipping form %s" %
                    (m.group(1), formpagename))
                skip_form = True
            if not skip_form:
              comment = "Delete erroneously created form of %s" % pagetitle
              if save:
                formpage.delete(comment)
              else:
                pagemsg("Would delete page %s with comment=%s" %
                    (formpagename, comment))

parser = blib.create_argparser(u"Delete erroneously created forms")
parser.add_argument("--declfile", help="File containing declensions to expand to get forms.")
parser.add_argument("--forms", help="Form codes of forms to delete.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.forms == "all-verb":
  forms = [
      "pres_1sg", "pres_2sg", "pres_3sg", "pres_1pl", "pres_2pl", "pres_3pl",
      "futr_1sg", "futr_2sg", "futr_3sg", "futr_1pl", "futr_2pl", "futr_3pl",
      "impr_sg", "impr_pl",
      "past_m", "past_f", "past_n", "past_pl",
      "past_m_short", "past_f_short", "past_n_short", "past_pl_short"
  ]
elif args.forms == "pres":
  forms = [
      "pres_1sg", "pres_2sg", "pres_3sg", "pres_1pl", "pres_2pl", "pres_3pl"
  ]
elif args.forms == "futr":
  forms = [
      "futr_1sg", "futr_2sg", "futr_3sg", "futr_1pl", "futr_2pl", "futr_3pl"
  ]
elif args.forms == "impr":
  forms = [
      "impr_sg", "impr_pl"
  ]
elif args.forms == "past":
  forms = [
      "past_m", "past_f", "past_n", "past_pl",
      "past_m_short", "past_f_short", "past_n_short", "past_pl_short"
  ]
elif args.forms == "all-noun":
  forms = [
      "nom_sg", "gen_sg", "dat_sg", "acc_sg", "acc_sg_an", "acc_sg_in",
        "ins_sg", "pre_sg",
      "nom_pl", "gen_pl", "dat_pl", "acc_pl", "acc_pl_an", "acc_pl_in",
        "ins_pl", "pre_pl"
  ]
elif args.forms == "sg":
  forms = [
      "nom_sg", "gen_sg", "dat_sg", "acc_sg", "acc_sg_an", "acc_sg_in",
        "ins_sg", "pre_sg"
  ]
elif args.forms == "pl":
  forms = [
      "nom_pl", "gen_pl", "dat_pl", "acc_pl", "acc_pl_an", "acc_pl_in",
        "ins_pl", "pre_pl"
  ]
else:
  forms = blib.split_utf8_arg(args.forms)
for i, line in blib.iter_items_from_file(args.declfile, start, end):
  if "!!!" in line:
    pagetitle, decl = re.split("!!!", line)
  else:
    pagetitle, decl = re.split(" ", line, 1)
  process_decl(i, pagetitle, decl, forms, args.save, args.verbose)

#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Convert ru-noun to ru-noun+, ru-proper noun to ru-proper noun+.
#
# FIXME:
#
# 1. If tr= occurs in ru-noun, skip. Eventually, move tr= to ru-noun-table.
# 2. If proper noun, can remove n=sg, but only if the noun would be singular
#    with this removed (i.e. not plural). To check this we need to expand
#    the result with n=sg removed and with ndef=sg and see what the gender is
#    (it should be sg then).
# 3. When checking gender mismatch, if there's animacy mismatch, punt and
#    issue warning rather than allowing it.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam

import rulib as ru

site = pywikibot.Site()

def msg(text):
  print text.encode("utf-8")

def errmsg(text):
  print >>sys.stderr, text.encode("utf-8")

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    if verbose:
      pagemsg("Expanding text: %s" % tempcall)
    result = site.expand_text(tempcall, title=pagetitle)
    if verbose:
      pagemsg("Raw result is %s" % result)
    if result.startswith('<strong class="error">'):
      result = re.sub("<.*?>", "", result)
      pagemsg("WARNING: Got error: %s" % result)
      return False
    return result

  if not page.exists():
    pagemsg("WARNING: Page doesn't exist")
    return

  parsed = blib.parse(page)

  noun_table_templates = []

  for t in parsed.filter_templates():
    if unicode(t.name) == "ru-noun-table":
      noun_table_templates.append(t)

  if len(noun_table_templates) > 1:
    pagemsg("WARNING: Multiple ru-noun-table templates, skipping")
    return
  if len(noun_table_templates) < 1:
    pagemsg("WARNING: No ru-noun-table templates, skipping")
    return

  for t in parsed.filter_templates():
    if unicode(t.name) in ["ru-noun+", "ru-proper noun+"]:
      pagemsg("Found ru-noun+ or ru-proper noun+, skipping")
      return

  headword_templates = []

  for t in parsed.filter_templates():
    if unicode(t.name) in ["ru-noun", "ru-proper noun"]:
      headword_templates.append(t)

  if len(headword_templates) > 1:
    pagemsg("Found multiple headword templates, skipping")
    return
  if len(headword_templates) < 1:
    pagemsg("Found no headword templates, skipping")
    return

  noun_table_template = noun_table_templates[0]
  headword_template = headword_templates[0]
  generate_template = re.sub(r"^\{\{ru-noun-table", "{{ru-generate-noun-args",
      unicode(noun_table_template))
  generate_result = expand_text(generate_template)
  if not generate_result:
    pagemsg("WARNING: Error generating noun args")
    return
  args = {}
  for arg in re.split(r"\|", generate_result):
    name, value = re.split("=", arg)
    args[name] = value

  def compare_forms(case, form1, form2):
    form2 = re.split(",", form2)
    if form1 and set(form1) != set(form2):
      pagemsg("WARNING: case %s, existing forms %s not same as proposed %s" %(
          case, ",".join(form1), ",".join(form2)))
      return False
    return True

  def compare_genders(g1, g2):
    if set(g1) == set(g2):
      return True
    if len(g1) == 1 and len(g2) == 1:
      if g1[0] == 'm' and g2[0].startswith("m-") or g1[0] == 'f' and g2[0].startswith("f-"):
        return True
    pagemsg("WARNING: gender mismatch, existing=%s, new=%s" % (
      ",".join(g1), ",".join(g2)))
    return False

  def process_arg_chain(t, first, pref, firstdefault=""):
    ret = []
    val = getparam(t, first)
    i = 2

    while val:
      ret.append(val)
      val = getparam(t, pref + str(i))
    return val

  headwords = process_arg_chain(headword_template, "1", "head", pagetitle)
  genders = process_arg_chain(headword_template, "2", "g")
  genitives = process_arg_chain(headword_template, "3", "gen")
  plurals = process_arg_chain(headword_template, "4", "pl")
  if args["n"] == "s":
    if (not compare_forms("nom_sg", headwords, args["nom_sg"]) or
        not compare_forms("gen_sg", genitives, args["gen_sg"])):
      pagemsg("Existing and proposed forms not same, skipping")
      return
  elif args["n"] == "p":
    if (not compare_forms("nom_pl", headwords, args["nom_pl"]) or
        not compare_forms("gen_pl", genitives, args["gen_pl"])):
      pagemsg("Existing and proposed forms not same, skipping")
      return
  elif args["n"] == "b":
    if (not compare_forms("nom_sg", headwords, args["nom_sg"]) or
        not compare_forms("gen_sg", genitives, args["gen_sg"]) or
        not compare_forms("nom_pl", plurals, args["nom_pl"])):
      pagemsg("Existing and proposed forms not same, skipping")
      return
  else:
    pagemsg("WARNING: Unrecognized number spec %s, skipping" % args["n"])
    return

  proposed_genders = re.split(",", args["g"])
  if compare_genders(genders, proposed_genders):
    proposed_genders = []

  for param in headword_template.params:
    name = unicode(param.name)
    if name not in ["1", "2", "3", "4"] and re.search(r"^[0-9]+$", name):
      pagemsg("WARNING: Extraneous numbered param %s=%s in headword template, skipping" % (
        unicode(param.name), unicode(param.value)))
      return

  params_to_preserve = []
  for param in headword_template.params:
    name = unicode(param.name)
    if (name not in ["1", "2", "3", "4", "g", "gen", "pl"] and
        not re.search(r"^(head|g|gen|pl)[0-9]+$", name)):
      params_to_preserve.append(param)

  # FIXME

  if save:
    comment = "Convert ru-noun to ru-noun+, ru-proper noun to ru-proper noun+"
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = unicode(parsed)
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = argparse.ArgumentParser(description="Convert ru-noun to ru-noun+, ru-proper noun to ru-proper noun+")
parser.add_argument('start', help="Starting page index", nargs="?")
parser.add_argument('end', help="Ending page index", nargs="?")
parser.add_argument('--save', action="store_true", help="Save results")
parser.add_argument('--verbose', action="store_true", help="More verbose output")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for i, page in blib.references("Template:ru-noun-table", start, end):
  msg("Page %s %s: Processing" % (i, unicode(page.title())))
  process_page(i, page, args.save, args.verbose)

#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Convert ru-noun to ru-noun+, ru-proper noun to ru-proper noun+, transfer
# manual translit in headword to declension template (ru-noun-table).

# FIXME:
#
# 1. What about if there are links in the headword? They may disappear when
#    we convert to ru-noun+. Need to be careful about this.
# 2. Need to split on level-3 headers to handle multiple etymologies and
#    pronunciation etc. sections.
# 3. In try_to_stress(), need to stress monosyllabic transliterations
#    (e.g. in Ре́ин).

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam

import rulib as ru

site = pywikibot.Site()

def msg(text):
  print text.encode("utf-8")

def errmsg(text):
  print >>sys.stderr, text.encode("utf-8")

def arg1_is_stress(arg1):
  if not arg1:
    return False
  for arg in re.split(",", arg1):
    if not (re.search("^[a-f]'?'?$", arg) or re.search(r"^[1-6]\*?$", arg)):
      return False
  return True

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)

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
  frobbed_manual_translit = ""

  if verbose:
    pagemsg("Found headword template: %s" % unicode(headword_template))
    pagemsg("Found decl template: %s" % unicode(noun_table_template))

  headword_tr = getparam(headword_template, "tr")
  if headword_tr:
    if verbose:
      pagemsg("Found headword manual translit tr=%s" % headword_tr)
    if "," in headword_tr:
      pagemsg("WARNING: Comma in headword manual translit, skipping: %s" %
          headword_tr)
      return
    # Punt if multi-arg-set, can't handle yet
    for param in noun_table_template.params:
      if not param.showkey:
        val = unicode(param.value)
        if val == "or":
          pagemsg("WARNING: Manual translit and multi-decl templates, can't handle: %s" % unicode(noun_table_template))
          return
        if val == "-" or val == "_" or val.startswith("join:"):
          pagemsg("WARNING: Manual translit and multi-word templates, can't handle: %s" % unicode(noun_table_template))
          return
    for i in xrange(2, 10):
      if getparam(headword_template, "tr%s" % i):
        pagemsg("WARNING: Headword template has translit param tr%s, can't handle: %s" % (
          i, unicode(headword_template)))
        return
    if arg1_is_stress(getparam(noun_table_template, "1")):
      lemma_arg = "2"
    else:
      lemma_arg = "1"
    lemmaval = getparam(noun_table_template, lemma_arg)
    if not lemmaval:
      lemmaval = subpagetitle
    if "//" in lemmaval:
      m = re.search("^(.*?)//(.*)$", lemmaval)
      if m.group(2) != headword_tr:
        pagemsg("WARNING: Found existing manual translit in decl template %s, but doesn't match headword translit %s; skipping" % (
          lemmaval, headword_tr))
        return
      else:
        pagemsg("Already found manual translit in decl template %s" %
            lemmaval)
    else:
      lemmaval += "//" + headword_tr
      orig_noun_table_template = unicode(noun_table_template)
      noun_table_template.add(lemma_arg, lemmaval)
      if verbose:
        pagemsg("Replacing decl %s with %s" % (orig_noun_table_template,
          unicode(noun_table_template)))
      frobbed_manual_translit = (", transferred tr=%s to ru-noun-table" %
          headword_tr)

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

  def try_to_stress(form):
    if "//" in form:
      m = re.search("^(.*?)//(.*)$", form)
      # FIXME: This should stress the translit as well
      return ru.try_to_stress(m.group(1)) + "//" + m.group(2)
    return ru.try_to_stress(form)

  def compare_forms(case, form1, form2):
    form2 = re.split(",", form2)
    # If existing value missing, OK; also allow for unstressed monosyllabic
    # existing form matching stressed monosyllabic new form
    if form1 and set(form1) != set(form2) and set(try_to_stress(x) for x in form1) != set(form2):
      pagemsg("WARNING: case %s, existing forms %s not same as proposed %s" %(
          case, ",".join(form1), ",".join(form2)))
      return False
    return True

  def compare_genders(g1, g2):
    if set(g1) == set(g2):
      return True
    if len(g1) == 1 and len(g2) == 1:
      if g1[0] == 'm' and g2[0].startswith("m-") or g1[0] == 'f' and g2[0].startswith("f-") or g1[0] == 'n' and g2[0].startswith("n-"):
        return True
    pagemsg("WARNING: gender mismatch, existing=%s, new=%s" % (
      ",".join(g1), ",".join(g2)))
    return False

  def process_arg_chain(t, first, pref, firstdefault=""):
    ret = []
    val = getparam(t, first) or firstdefault
    i = 2
    while val:
      ret.append(val)
      val = getparam(t, pref + str(i))
      i += 1
    return ret

  headwords = process_arg_chain(headword_template, "1", "head", subpagetitle)
  translits = process_arg_chain(headword_template, "tr", "tr")
  for i in xrange(len(translits)):
    if len(headwords) <= i:
      pagemsg("WARNING: Not enough headwords for translit tr%s=%s, skipping" % (
        "" if i == 0 else str(i+1), translits[i]))
      return
    else:
      headwords[i] += "//" + translits[i]
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
  else:
    # Check for animacy mismatch, punt if so
    cur_in = [x for x in genders if re.search(r"\bin\b", x)]
    cur_an = [x for x in genders if re.search(r"\ban\b", x)]
    proposed_in = [x for x in proposed_genders if re.search(r"\bin\b", x)]
    proposed_an = [x for x in proposed_genders if re.search(r"\ban\b", x)]
    if cur_in and proposed_an or cur_an and proposed_in:
      pagemsg("WARNING: Animacy mismatch, skipping: cur=%s proposed=%s" % (
        ",".join(genders), ",".join(proposed_genders)))
      return
    # Check for number mismatch, punt if so
    cur_pl = [x for x in genders if re.search(r"\bp\b", x)]
    if cur_pl and args["n"] != "p" or not cur_pl and args["n"] == "p":
      pagemsg("WARNING: Number mismatch, skipping: cur=%s, proposed=%s, n=%s" % (
        ",".join(genders), ",".join(proposed_genders), args["n"]))
      return

  for param in headword_template.params:
    name = unicode(param.name)
    if name not in ["1", "2", "3", "4"] and re.search(r"^[0-9]+$", name):
      pagemsg("WARNING: Extraneous numbered param %s=%s in headword template, skipping" % (
        unicode(param.name), unicode(param.value)))
      return

  params_to_preserve = []
  for param in headword_template.params:
    name = unicode(param.name)
    if (name not in ["1", "2", "3", "4", "g", "gen", "pl", "tr"] and
        not re.search(r"^(head|g|gen|pl|tr)[0-9]+$", name)):
      params_to_preserve.append(param)

  orig_headword_template = unicode(headword_template)
  del headword_template.params[:]
  for param in noun_table_template.params:
    headword_template.add(param.name, param.value)
  i = 1
  for g in proposed_genders:
    headword_template.add("g" if i == 1 else "g%s" % i, g)
  if unicode(headword_template.name) == "ru-proper noun":
    # If proper noun and n is both then we need to add n=both because
    # proper noun+ defaults to n=sg
    if args["n"] == "b" and not getparam(headword_template, "n"):
      if verbose:
        pagemsg("Adding n=both to headword tempate")
      headword_template.add("n", "both")
    # Correspondingly, if n is sg then we can usually remove n=sg;
    # but we need to check that the number is actually sg with n=sg
    # removed because of the possibility of plurale tantum lemmas
    if args["n"] == "s":
      generate_template_with_ndef = generate_template.replace("}}", "|ndef=sg}}")
      generate_template_with_ndef = re.sub(r"\|n=s[^=|{}]*", "",
          generate_template_with_ndef)
      generate_result = expand_text(generate_template_with_ndef)
      if not generate_result:
        pagemsg("WARNING: Error generating noun args")
        return
      ndef_args = {}
      for arg in re.split(r"\|", generate_result):
        name, value = re.split("=", arg)
        ndef_args[name] = value
      if ndef_args["n"] == "s":
        existing_n = getparam(headword_template, "n")
        if existing_n and not re.search(r"^s", existing_n):
          pagemsg("WARNING: Something wrong: Found n=%s, not singular" %
              existing_n)
        else:
          if verbose:
            pagemsg("Removing n=sg from headword tempate")
          rmparam(headword_template, "n")
      elif verbose:
        pagemsg("Unable to remove n= from headword template because n=%s" %
            ndef_args["n"])

  headword_template.params.extend(params_to_preserve)
  if unicode(headword_template.name) == "ru-noun":
    headword_template.name = "ru-noun+"
    comment = "Convert ru-noun to ru-noun+"
  else:
    headword_template.name = "ru-proper noun+"
    comment = "Convert ru-proper noun to ru-proper noun+"

  if verbose:
    pagemsg("Replacing headword %s with %s" % (orig_headword_template, unicode(headword_template)))

  comment += frobbed_manual_translit
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

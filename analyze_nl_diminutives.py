#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site
from collections import defaultdict

pages_by_dim_ending = defaultdict(int)

vowels = "AEIOUaeiouäëïöü"
V = "[%s]" % vowels
NV = "[^%s]" % vowels
long_monophthongs = "aa|ee|ie|oo|uu"
diphthongs = "aai|a[iu]|eeu|e[iu]|ieu|ij|o[eui]|ooi|oei|ui"
LONGV = "(?:%s|%s)" % (long_monophthongs, diphthongs)
lengthen = {
  "a": "aa",
  "e": "ee",
  "i": "ie",
  "o": "oo",
  "u": "uu",
  "A": "Aa",
  "E": "Ee",
  "I": "Ie",
  "O": "Oo",
  "U": "Uu",
  # FIXME: Do the following ever occur and if so are these correct?
  "ä": "äa",
  "ë": "ëe",
  "ï": "ïe",
  "ö": "öo",
  "ü": "üu",
}

def remove_final_e(form, final_multisyllable_stress=False):
  if re.search(LONGV + "$", form) or not re.search(V + NV + "*[eë]$", form):
    return form
  form = form[:-1]
  if re.search(LONGV + NV + "$", form):
    return form
  m = re.search("^" + V + NV + "*(e[rln]|or|[eu]m)$", form)
  if m and not final_multisyllable_stress:
    return form
  m = re.search("^(.*)(" + V + NV + ")$", form)
  if m:
    base, ending = m.groups()
    assert len(ending) == 2
    ending_v = ending[0]
    ending_c = ending[1]
    return base + lengthen[ending_v] + ending_c
  m = re.search("^(.*)(" + NV + r")\2$", form)
  if m:
    base, first_c = m.groups()
    return base + first_c
  return form

# Based on [https://www.dutchgrammar.com/en/?n=NounsAndArticles.23].
def default_dim_1(lemma, final_multisyllable_stress=False, modifier_final_multisyllable_stress=False):
  m = re.search("^([^ ]+[eë]) (.*)$", lemma)
  if m:
    first_word, rest = m.groups()
    return remove_final_e(first_word, modifier_final_multisyllable_stress) + " " + default_dim_1(
        rest, final_multisyllable_stress, modifier_final_multisyllable_stress)
  if re.search(NV + "[aou]$", lemma):
    return lemma + lemma[-1] + "tje"
  if re.search(NV + "i$", lemma):
    return lemma + "etje"
  if re.search(NV + "y$", lemma):
    return lemma + "'tje"
  if re.search("é$", lemma):
    return lemma[:-1] + "eetje"
  if re.search(V + "$", lemma) or lemma.endswith("w") or re.search(LONGV + "[rln]$", lemma):
    return lemma + "tje"
  if re.search(V + NV + "*(e[rln]|or)$", lemma):
    # NOTE: we already handled LONGV + [rln]$ above, so any occurrence of V + (e[rln]|or)$ is not a long vowel or
    # diphthong.
    return lemma + lemma[-1] + "etje" if final_multisyllable_stress else lemma + "tje"
  if re.search(V + "[rln]$", lemma):
    # NOTE: we already handled LONGV + [rln]$ above, so any occurrence of V + [rln]$ is not a long vowel or diphthong.
    return lemma + lemma[-1] + "etje"
  if re.search(LONGV + "m$", lemma) or re.search("[lr]m$", lemma):
    return lemma + "pje"
  if re.search(V + NV + "*[eu]m$", lemma):
    # NOTE: we already handled LONGV + m$ above, so any occurrence of V + [eu]m$ is not a long vowel or diphthong.
    return lemma + lemma[-1] + "etje" if final_multisyllable_stress else lemma + "pje"
  if re.search(V + "m$", lemma):
    # NOTE: we already handled LONGV + m$ above, so any occurrence of V + m$ is not a long vowel or diphthong.
    return lemma + lemma[-1] + "etje"
  if re.search(LONGV + "ng$", lemma):
    # NOTE: This may not exist.
    return lemma + "je"
  if re.search(V + NV + "*ing$", lemma):
    # NOTE: we already handled LONGV + ng$ above, so any occurrence of V + ing$ is not a long vowel or diphthong.
    return lemma + "etje" if final_multisyllable_stress else lemma[:-1] + "kje"
  if re.search(V + "ng$", lemma):
    # NOTE: we already handled LONGV + ng$ above, so any occurrence of V + ng$ is not a long vowel or diphthong.
    return lemma + "etje"
  return lemma + "je"

def default_dim(lemma, final_multisyllable_stress=False, modifier_final_multisyllable_stress=False):
  retval = default_dim_1(lemma, final_multisyllable_stress, modifier_final_multisyllable_stress)
  #msg("default_dim(%s, final_multisyllable_stress=%s, modifier_final_multisyllable_stress=%s) = %s" % (
  #  lemma, final_multisyllable_stress, modifier_final_multisyllable_stress, retval))
  return retval
  
def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Dutch",
                                             pagemsg, force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "nl-noun":
      dims = blib.fetch_param_chain(t, "3", "dim")
      for dim in dims:
        if dim == "-":
          continue
        if dim == default_dim(pagetitle):
          pages_by_dim_ending["+"] += 1
        elif dim == default_dim(pagetitle, True):
          pages_by_dim_ending["++"] += 1
        elif " " in pagetitle and dim == default_dim(pagetitle, False, True):
          pages_by_dim_ending["++/+"] += 1
        elif " " in pagetitle and dim == default_dim(pagetitle, True, True):
          pages_by_dim_ending["++/++"] += 1
        elif dim.startswith(pagetitle):
          dimending = dim[len(pagetitle):]
          pages_by_dim_ending[dimending] += 1
        else:
          pagemsg("WARNING: Can't analyze diminutive %s" % dim)

parser = blib.create_argparser("Analyze {{nl-noun}} diminutive usage",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang Dutch' and has no ==Dutch== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

msg("%20s  %5s" % ("Ending", "Count"))
msg("-"*27)
for dimending, num_occur in sorted(pages_by_dim_ending.items(), reverse=True, key=lambda x:x[1]):
  msg("%20s = %d" % (dimending, num_occur))

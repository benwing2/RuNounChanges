#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

remove_stress_table = {
  u'à': 'a',
  u'á': 'a',
  u'è': 'e',
  u'é': 'e',
  u'ì': 'i',
  u'í': 'i',
  u'ò': 'o',
  u'ó': 'o',
  u'ù': 'u',
  u'ú': 'u',
  u'ỳ': 'y',
  u'ý': 'y',
  u'À': 'A',
  u'Á': 'A',
  u'È': 'E',
  u'É': 'E',
  u'Ì': 'I',
  u'Í': 'I',
  u'Ò': 'O',
  u'Ó': 'O',
  u'Ù': 'U',
  u'Ú': 'U',
  u'Ỳ': 'Y',
  u'Ý': 'Y',
}

def remove_stress(char):
  if char in remove_stress_table:
    return remove_stress_table[char]
  return char

def synchronize(term, hyphenation, pagemsg):
  i = 0
  hyph = "|".join(hyphenation)
  j = 0
  transfer_j = []
  transfer_char = []
  while i < len(term) and j < len(hyph):
    while j < len(hyph) and hyph[j] == '|':
      j += 1
    if j >= len(hyph):
      break
    if term[i] == hyph[j]:
      i += 1
      j += 1
      continue
    if remove_stress(term[i]) == hyph[j]:
      transfer_j.append(j)
      transfer_char.append(term[i])
      i += 1
      j += 1
      continue
    if term[i] == " ":
      i += 1
      continue
    pagemsg("WARNING: Unable to match it-stress term %s against hyphenation %s at it-stress char #%s=%s, hyphenation char #%s=%s" % (
      term, hyph, i, term[i], j, hyph[j]))
    return None
  if i < len(term):
    pagemsg("WARNING: Trailing it-stress chars %s in term %s when matching against hyphenation %s" % (
      term[i:], term, hyph))
    return None
  if j < len(hyph):
    pagemsg("WARNING: Trailing hyphenation chars %s in term %s when matching against it-stress %s" % (
      hyph[j:], hyph, term))
    return None
  if not transfer_char:
    pagemsg("Stress already transferred from %s to %s" % (term, hyph))
    return hyphenation
  secs = []
  last_transfer_j = 0
  for this_transfer_j, this_transfer_char in zip(transfer_j, transfer_char):
    secs.append(hyph[last_transfer_j:this_transfer_j] + this_transfer_char)
    last_transfer_j = this_transfer_j + 1
  secs.append(hyph[last_transfer_j:])
  return "".join(secs).replace(" ", "").split("|")

def process_page(index, page, title_with_syllable_divs=None):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = str(page.text)

  notes = []

  if pagetitle.startswith("Rhymes:Italian/"):
    sections = [text]
    j = 0
    secbody = text
    sectail = ""
    has_non_lang = False
  else:
    retval = blib.find_modifiable_lang_section(text, "Italian", pagemsg)
    if retval is None:
      return None, None
    sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  for k in range(2, len(subsections), 2):
    parsed = blib.parse_text(subsections[k])
    it_stress_template = None
    it_hyph_template = None
    do_continue = False
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "it-stress":
        if it_stress_template:
          pagemsg("WARNING: Saw multiple it-stress templates: %s and %s" % (
            str(it_stress_template), str(t)))
          do_continue = True
          break
        else:
          it_stress_template = t
      elif tn in ["hyph", "hyphenation"]:
        lang = getparam(t, "lang")
        if not lang:
          lang = getparam(t, "1")
        if lang == "it":
          if it_hyph_template:
            pagemsg("WARNING: Saw multiple hyph|it templates: %s and %s" % (
              str(it_hyph_template), str(t)))
            do_continue = True
            break
          else:
            it_hyph_template = t
    if do_continue:
      continue
    if not it_stress_template:
      if "==Pronunciation==" in subsections[k - 1]:
        pagemsg("No it-stress template in Pronunciation section")
      continue
    if not it_hyph_template:
      if not title_with_syllable_divs:
        pagemsg("WARNING: Saw it-stress template %s but no hyphenation template and --stressfile not given" %
            str(it_stress_template))
        continue
      new_hyph = synchronize(getparam(it_stress_template, "1"),
          title_with_syllable_divs.split("."), pagemsg)
      if new_hyph is None:
        continue
      it_hyph_template = "{{hyph|it|%s}}" % "|".join(new_hyph)
      subsec_k = str(parsed)
      subsec_k, modified = blib.replace_in_text(subsec_k,
        "* %s\n" % str(it_stress_template), "* %s\n" % it_hyph_template,
        pagemsg, no_found_repl_check=True)
      if not modified:
        continue
      subsections[k] = subsec_k
      notes.append("replace {{it-stress}} with {{hyph|it}}")
    else:
      if getparam(it_hyph_template, "lang"):
        first_hyph_param = 1
      else:
        first_hyph_param = 2
      hyph_params = []
      i = first_hyph_param
      while getparam(it_hyph_template, str(i)):
        hyph_params.append(getparam(it_hyph_template, str(i)))
        i += 1
      new_hyph = synchronize(getparam(it_stress_template, "1"), hyph_params,
          pagemsg)
      if new_hyph is None:
        continue
      assert len(hyph_params) == len(new_hyph)
      orig_hyph_template = str(it_hyph_template)
      i = first_hyph_param
      for param in new_hyph:
        it_hyph_template.add(str(i), param)
        i += 1
      if orig_hyph_template != str(it_hyph_template):
        pagemsg("Replaced %s with %s" % (orig_hyph_template, str(it_hyph_template)))
      else:
        pagemsg("No changes to hyph template %s" % (orig_hyph_template))
      subsec_k = str(parsed)
      subsec_k, modified = blib.replace_in_text(subsec_k,
        "* %s\n" % str(it_stress_template), "", pagemsg, no_found_repl_check=True)
      if not modified:
        continue
      subsections[k] = subsec_k
      notes.append("transfer accent from {{it-stress}} to {{hyph|it}} and remove {{it-stress}}")

  secbody = "".join(subsections)
  sections[j] = secbody + sectail
  return "".join(sections), notes

parser = blib.create_argparser(u"Transfer accent from {{it-stress}} to {{hyph|it}} and remove {{it-stress}}, or replace {{it-stress}} with synthesized {{hyph|it}}")
parser.add_argument("--stressfile", help="List of pages with stress.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.stressfile:
  for index, line in blib.iter_items_from_file(args.stressfile, start, end):
    m = re.search(r"^\* Page [0-9]+ \[\[(Rhymes:.*?)\]\]: WARNING: Saw it-stress template \{\{temp\|it-stress\|(.*?)\}\}.*$", line)
    if m:
      title, title_with_syllable_divs = m.groups()
    else:
      m = re.search(r"^\* Page [0-9]+ \[\[(.*?)\]\]: WARNING:.*$", line)
      if m:
        title = m.group(1)
        title_with_syllable_divs = title.replace(".", "")
      else:
        msg("Line %s: WARNING: Unable to parse: %s" % (index, line))
        continue
    page = pywikibot.Page(site, title)
    def handler(page, index, parsed):
      return process_page(index, page, title_with_syllable_divs)
    blib.do_edit(page, index, handler, save=args.save, verbose=args.verbose)
else:
  for index, page in blib.references("Template:it-stress", start, end):
    def handler(page, index, parsed):
      return process_page(index, page)
    blib.do_edit(page, index, handler, save=args.save, verbose=args.verbose)

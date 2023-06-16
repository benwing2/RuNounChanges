#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

# Value is one of:
# "pl-p-respelling": if page has any {{pl-p}} with respelling
# "pl-p-no-respelling": if page has only {{pl-p}} without respelling
# "no-pl-p": if page does not have {{pl-p}}
pages_with_pl_p = {}

infl_templates = ["inflection of", "infl of"]

pronun_templates = ["IPA", "pl-IPA", "pl-p", "pl-pronunciation"]

def get_pl_p_property(index, pagetitle):
  if pagetitle in pages_with_pl_p:
    return pages_with_pl_p[pagetitle]
  page = pywikibot.Page(site, pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  pagetext = blib.safe_page_text(page, pagemsg)
  parsed = blib.parse_text(pagetext)
  saw_pl_p = False
  respellings = []
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["pl-p", "pl-pronunciation"]:
      def getp(param):
        return getparam(t, param)
      saw_pl_p = True
      for pno in range(1, 11):
        respelling = getp(str(pno))
        if respelling and respelling not in respellings:
          respellings.append(respelling)
  if respellings:
    retval = ("pl-p-respelling", respellings)
  elif saw_pl_p:
    retval = ("pl-p-no-respelling", None)
  else:
    retval = ("no-pl-p", None)
  pages_with_pl_p[pagetitle] = retval
  return retval

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Polish", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  has_etym_sections = "==Etymology 1==" in secbody
  if has_etym_sections:
    # Check if either Pronunciation with pronunciation template above Etymology 1, or every
    # Etymology N section has Pronunciation with pronunciation template.
    saw_etym_1 = False
    cur_etym_header = None
    saw_pron_in_etym = False
    for k in range(1, len(subsections), 2):
      if "==Pronunciation==" in subsections[k]:
        secparsed = blib.parse_text(subsections[k + 1])
        for t in secparsed.filter_templates():
          tn = tname(t)
          if tn in pronun_templates:
            if saw_etym_1:
              saw_pron_in_etym = True
              break
            else:
              pagemsg("Already saw pronunciation template above ==Etymology 1==: %s" % str(t))
              return
        else: # no break
          pagemsg("WARNING: Saw ==Pronunciation== section without pronunciation template, along with ==Etymology 1==; can't handle, skipping")
          return

      if "==Etymology 1==" in subsections[k]:
        saw_etym_1 = True
        cur_etym_header = subsections[k].strip()
      elif re.search("==Etymology [0-9]+==", subsections[k]):
        if not saw_pron_in_etym:
          pagemsg("WARNING: No ==Pronunciation== section above ==Etymology N== headers and saw %s without pronunciation template; can't handle, skipping"
              % cur_etym_header)
          return
        saw_pron_in_etym = False
        cur_etym_header = subsections[k].strip()
    if not saw_pron_in_etym:
      # Last Etymology N section didn't have pronunciation template.
      pagemsg("WARNING: No ==Pronunciation== section above ==Etymology N== headers and saw %s without pronunciation template; can't handle, skipping"
          % cur_etym_header)
      return

  parsed = blib.parse_text(secbody)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in pronun_templates:
      pagemsg("Already saw pronunciation template: %s" % str(t))
      return

  if not args.ignore_lemma_respelling:
    lemmas = set()
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn in infl_templates:
        def getp(param):
          return getparam(t, param)
        if getp("1") != "pl":
          pagemsg("WARNING: Wrong language in {{%s}}, skipping: %s" % (tn, str(t)))
          return
        lemma = getparam(t, "2")
        lemmas.add(lemma)
    if len(lemmas) > 1:
      pagemsg("WARNING: Saw inflection of multiple lemmas %s, skipping" % ",".join(lemmas))
      return
    if not lemmas:
      pagemsg("WARNING: Didn't see inflection template, skipping")
      return
    lemma = list(lemmas)[0]
    pl_p_prop, pl_p_respellings = get_pl_p_property(index, lemma)
    if pl_p_prop == "no-pl-p":
      pagemsg("WARNING: Lemma page %s has no {{pl-p}}, not sure what to do, skipping" % lemma)
      return
    elif pl_p_prop == "pl-p-respelling":
      pagemsg("WARNING: Lemma page %s has respelling(s) %s, skipping" % (
        lemma, ",".join(pl_p_respellings)))
      return
    else:
      pagemsg("Lemma page %s has {{pl-p}} without respelling, proceeding" % lemma)

  def construct_new_pron_template():
    return "{{pl-p}}", ""

  def insert_into_existing_pron_section(k):
    parsed = blib.parse_text(subsections[k])
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn in pronun_templates:
        pagemsg("Already saw pronunciation template: %s" % str(t))
        break
    else: # no break
      new_pron_template, pron_prefix = construct_new_pron_template()
      # Remove existing rhymes/hyphenation/pl-IPA lines
      for template in ["rhyme|pl", "rhymes|pl", "pl-IPA", "hyph|pl", "hyphenation|pl"]:
        re_template = template.replace("|", r"\|")
        regex = r"^([* ]*\{\{%s(?:\|[^{}]*)*\}\}\n)" % re_template
        m = re.search(regex, subsections[k], re.M)
        if m:
          pagemsg("Removed existing %s" % m.group(1).strip())
          notes.append("remove existing {{%s}}" % template)
          subsections[k] = re.sub(regex, "", subsections[k], 0, re.M)
      for template in ["audio|pl"]:
        re_template = template.replace("|", r"\|")
        regex = r"^([* ]*\{\{%s(?:\|[^{}]*)*\}\}\n)" % re_template
        all_audios = re.findall(regex, subsections[k], re.M)
        if len(all_audios) > 1:
          pagemsg("WARNING: Saw multiple {{audio}} templates, skipping: %s" % ",".join(x.strip() for x in all_audios()))
          return
        if len(all_audios) == 1:
          audiot = list(blib.parse_text(all_audios[0].strip()).filter_templates())[0]
          assert(tname(audiot) == "audio")
          if getparam(audiot, "1") != "pl":
            pagemsg("WARNING: Wrong language in {{audio}}, skipping: %s" % audio_line)
            return
          audiofile = getparam(audiot, "2")
          audiogloss = getparam(audiot, "3")
          for param in audiot.params:
            pn = pname(param)
            pv = str(param.value)
            if pn not in ["1", "2", "3"]:
              pagemsg("WARNING: Unrecognized param %s=%s in {{audio}}, skipping: %s" % (
                pn, pv, audio_line))
              return
          if audiogloss in ["Audio", "audio"]:
            audiogloss = ""
          params = "|a=%s" % audiofile
          if audiogloss:
            params += "|ac=%s" % audiogloss
          new_pron_template = new_pron_template[:-2] + params + new_pron_template[-2:]
          pagemsg("Removed existing %s in order to incorporate into {{pl-p}}" % all_audios[0].strip())
          notes.append("incorporate existing {{%s}} into {{pl-p}}" % template)
          subsections[k] = re.sub(regex, "", subsections[k], 0, re.M)
      subsections[k] = pron_prefix + new_pron_template + "\n" + subsections[k]
      notes.append("insert %s into existing Pronunciation section" % new_pron_template)
    return True

  def insert_new_l3_pron_section(k):
    new_pron_template, pron_prefix = construct_new_pron_template()
    subsections[k:k] = ["===Pronunciation===\n", pron_prefix + new_pron_template + "\n\n"]
    notes.append("add top-level Polish pron %s" % new_pron_template)

  for k in range(2, len(subsections), 2):
    if "==Pronunciation==" in subsections[k - 1]:
      if not insert_into_existing_pron_section(k):
        return
      break
  else: # no break
    k = 2
    while k < len(subsections) and re.search("==(Alternative forms|Etymology)==", subsections[k - 1]):
      k += 2
    if k -1 >= len(subsections):
      pagemsg("WARNING: No lemma or non-lemma section at top level")
      return
    insert_new_l3_pron_section(k - 1)

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Add Polish non-lemma pronunciations", include_pagefile=True,
    include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
parser.add_argument("--ignore-lemma-respelling", action="store_true", help="Add {{pl-p}} to nonlemmas irrespective of lemma respelling.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_cats=["Polish non-lemma forms"], edit=True, stdin=True)

blib.elapsed_time()

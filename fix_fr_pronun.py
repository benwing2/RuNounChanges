#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

french_nonverb_head_templates = [
  "fr-abbr",
  "fr-adj",
  "fr-adv",
  "fr-diacritical mark",
  "fr-intj", "fr-interjection",
  "fr-letter",
  "fr-noun",
  "fr-past participle",
  "fr-phrase",
  "fr-prefix",
  "fr-prep",
  "fr-prep phrase",
  "fr-pron", "fr-pronoun",
  "fr-proper noun", "fr-proper-noun",
  "fr-punctuation mark",
  "fr-suffix",
]

french_verb_head_templates = [
  "fr-verb",
]

french_verb_head_pos = [
  "verb",
  "verb form",
  "past participle",
  "past participle form",
  "present participle",
  "present participle form",
]

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  if not args.stdin:
    pagemsg("Processing")

  if "==French==" not in text or "{{IPA|" not in text:
    return

  retval = blib.find_modifiable_lang_section(text, "French", pagemsg)
  if retval is None:
    return

  sections, j, secbody, sectail, has_non_french = retval

  if "{{IPA|" not in secbody:
    return

  notes = []

  def fix_up_section(sectext):
    parsed = blib.parse_text(sectext)

    pronun_templates = []
    verb_templates = []
    nonverb_templates = []
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn in french_nonverb_head_templates:
        nonverb_templates.append(t)
      elif tn in french_verb_head_templates:
        verb_templates.append(t)
      elif tn == "head":
        if getparam(t, "1").strip() != "fr":
          pagemsg("WARNING: Saw wrong-language {{head}} template: %s" % str(t))
        else:
          pos = getparam(t, "2").strip()
          if pos in french_verb_head_pos:
            verb_templates.append(t)
          else:
            nonverb_templates.append(t)
    if verb_templates and nonverb_templates:
      pagemsg("WARNING: Saw both verb template(s) %s and non-verb template(s) %s, using pos=vnv" % (
        ",".join(str(x) for x in verb_templates),
        ",".join(str(x) for x in nonverb_templates)
      ))
    if not verb_templates and not nonverb_templates:
      pagemsg("WARNING: Didn't see any French templates")
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "IPA":
        m = re.search("^.*?%s.*$" % re.escape(str(t)), sectext, re.M)
        if not m:
          pagemsg("WARNING: Couldn't find template %s in section text" % str(t))
          line = "(unknown)"
        else:
          line = m.group(0)
        if t.has("lang"):
          first_param = 1
          lang = getparam(t, "lang")
        else:
          first_param = 2
          lang = getparam(t, "1")
        if lang != "fr":
          pagemsg("WARNING: Saw wrong-language {{IPA}} template: %s in line <%s>" %
            (str(t), line))
          continue
        pron = getparam(t, str(first_param))
        if not pron:
          pagemsg("WARNING: No pronun in {{IPA}} template: %s in line <%s>" %
            (str(t), line))
          continue
        if getparam(t, str(first_param + 1)) or getparam(t, str(first_param + 2)) or getparam(t, str(first_param + 3)):
          pagemsg("WARNING: Multiple pronuns in {{IPA}} template: %s in line <%s>" %
            (str(t), line))
          continue
        pos_val = (
          "vnv" if verb_templates and nonverb_templates else
          "v" if verb_templates else ""
        )
        pos_arg = "|pos=%s" % pos_val if pos_val else ""
        #autopron = expand_text("{{#invoke:User:Benwing2/fr-pron|show|%s%s}}" % (
        autopron = expand_text("{{#invoke:fr-pron|show|%s%s}}" % (
          pagetitle, pos_arg))
        if not autopron:
          continue
        pron = re.sub("^/(.*)/$", r"\1", pron)
        pron = re.sub(r"^\[(.*)\]$", r"\1", pron)
        pron = pron.strip()
        pron = pron.replace("r", "ʁ")
        # account for various common errors in Dawnraybot's generated pronunciations:
        # #1
        if pagetitle.endswith("rez") and pron.endswith("ʁɔe"):
          pron = re.sub("ʁɔe$", "ʁe", pron)
        # #2
        if re.search("ai(s|t|ent)$", pagetitle) and pron.endswith("e"):
          pron = re.sub("e$", "ɛ", pron)
        # #3
        if pos_val == "v" and pagetitle.endswith("ai") and pron.endswith("ɛ"):
          pron = re.sub("ɛ$", "e", pron)
        if "." not in pron:
          autopron = autopron.replace(".", "")
        if autopron.endswith("ɑ") and pron.endswith("a"):
          autopron = autopron[:-1] + "a"
        if re.search(r"ɑ[mt]$", autopron) and re.search("a[mt]$", pron):
          autopron = re.sub(r"ɑ([mt])$", r"a\1", autopron)
        for i in range(2):
          # {{fr-IPA}} deletes schwa in the sequence V.Cə.CV esp. in the
          # sequence V.Cə.ʁV in verbs, whereas the bot-generated pronunciation
          # doesn't. We have separate cases depending on the identity of C,
          # which may go before or after the syllable break. Do it twice in
          # case it occurs twice in a row in a single word.
          pron = re.sub(r"([aɑɛeiɔouyœøɑ̃ɛ̃ɔ̃])\.([jlmnɲwʃʒ])ə\.(ʁ[aɑɛeiɔouyœøɑ̃ɛ̃ɔ̃])", r"\1\2.\3", pron)
          pron = re.sub(r"([aɑɛeiɔouyœøɑ̃ɛ̃ɔ̃])\.([szfvtdpbkɡ])ə\.(ʁ[aɑɛeiɔouyœøɑ̃ɛ̃ɔ̃])", r"\1.\2\3", pron)
        # {{fr-IPA}} converts sequences of Crj and Clj to Cri.j and Cli.j,
        # which is correct, but Dawnraybot doesn't do that.
        pron = re.sub("([szfvtdpbkɡ][ʁl])j", r"\1i.j", pron)
        allow_mismatch = False
        if pron != autopron:
          tempcall = "{{fr-IPA%s}}" % pos_arg
          if pron.replace("ɑ", "a") == autopron.replace("ɑ", "a"):
            pagemsg("WARNING: Would replace %s with %s but auto-generated pron %s disagrees with %s in ɑ vs. a only: line <%s>" % (
              str(t), tempcall, autopron, pron, line))
          elif re.sub("ɛ(.)", r"e\1", pron) == re.sub("ɛ(.)", r"e\1", autopron):
            pagemsg("WARNING: Would replace %s with %s but auto-generated pron %s disagrees with %s in ɛ vs. e only: line <%s>" % (
              str(t), tempcall, autopron, pron, line))
          elif pron.replace(".", "") == autopron.replace(".", ""):
            pagemsg("WARNING: Would replace %s with %s but auto-generated pron %s disagrees with %s in syllable division only: line <%s>" % (
              str(t), tempcall, autopron, pron, line))
            allow_mismatch = True
          elif pron.replace(".", "").replace(" ", "") == autopron.replace(".", "").replace(" ", ""):
            pagemsg("WARNING: Would replace %s with %s but auto-generated pron %s disagrees with %s in syllable/word division only: line <%s>" % (
              str(t), tempcall, autopron, pron, line))
          else:
            pagemsg("WARNING: Can't replace %s with %s because auto-generated pron %s doesn't match %s: line <%s>" % (
              str(t), tempcall, autopron, pron, line))
          if not allow_mismatch:
            continue
        origt = str(t)
        rmparam(t, "lang")
        rmparam(t, "1")
        rmparam(t, str(first_param))
        blib.set_template_name(t, "fr-IPA")
        if pos_val:
          t.add("pos", pos_val)
        notes.append("replace manually-specified {{IPA|fr}} pronun with {{fr-IPA}}")
        pagemsg("Replaced %s with %s: line <%s>" % (origt, str(t), line))
        if "{{a|" in line:
          pagemsg("WARNING: Replaced %s with %s on a line with an accent spec: line <%s>" %
            (origt, str(t), line))
    return str(parsed)

  # If there are multiple Etymology sections, the pronunciation may be above all of
  # them if all have the same pronunciation, else it will be within each section.
  # Cater to both situations. We first try without splitting on etym sections; if that
  # doesn't change anything, it may be because there were multiple heads found and
  # separate pronunciation sections, so we then try splitting on etym sections.
  if "==Etymology 1==" in secbody:
    etym_sections = re.split("(^===Etymology [0-9]+===\n)", secbody, 0, re.M)
    if "{{IPA|" in etym_sections[0]:
      secbody = fix_up_section(secbody)
    else:
      for k in range(2, len(etym_sections), 2):
        etym_sections[k] = fix_up_section(etym_sections[k])
      secbody = "".join(etym_sections)
  else:
    secbody = fix_up_section(secbody)
  sections[j] = secbody + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Replace manual French pronun with {{fr-IPA}}",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

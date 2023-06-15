#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse, unicodedata

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname, rsub_repeatedly

AC = u"\u0301" # acute =  ́
GR = u"\u0300" # grave =  ̀
CFLEX = u"\u0302" # circumflex =  ̂
TILDE = u"\u0303" # tilde =  ̃
DIA = u"\u0308" # diaeresis =  ̈

SYLDIV = u"\uFFF0" # used to represent a user-specific syllable divider (.) so we won't change it
accent = AC + GR + CFLEX
accent_c = "[" + accent + "]"
stress = AC + GR
stress_c = "[" + AC + GR + "]"
ipa_stress = u"ˈˌ"
ipa_stress_c = "[" + ipa_stress + "]"
separator = accent + ipa_stress + r"# \-." + SYLDIV
separator_c = "[" + separator + "]"

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)
  def verify_template_is_full_line(tn, line):
    line = line.strip()
    templates = list(blib.parse_text(line).filter_templates())
    if type(tn) is list:
      tns = tn
    else:
      tns = [tn]
    tntext = "/".join(tns)
    if len(templates) == 0:
      pagemsg("WARNING: No templates on {{%s}} line?, skipping: %s" % (tntext, line))
      return None
    t = templates[0]
    if tname(t) not in tns:
      pagemsg("WARNING: Putative {{%s}} line doesn't have {{%s...}} as the first template, skipping: %s" %
          (tntext, tntext, line))
      return None
    if unicode(t) != line:
      pagemsg("WARNING: {{%s}} line has text other than {{%s...}}, skipping: %s" % (tntext, tntext, line))
      return None
    return t

  notes = []

  if len(pagetitle) == 1 or pagetitle.endswith("-"):
    pagemsg("Page title is a single letter or a prefix, skipping")
    return

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Polish", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  for k in range(1, len(subsections), 2):
    if re.search(r"==\s*Pronunciation\s*==", subsections[k]):
      secheader = re.sub(r"\s*Pronunciation\s*", "Pronunciation", subsections[k])
      if secheader != subsections[k]:
        subsections[k] = secheader
        notes.append("remove extraneous spaces in ==Pronunciation== header")
      extra_notes = []
      parsed = blib.parse_text(subsections[k + 1])
      num_pl_IPA = 0
      saw_pl_p = False
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn in ["pl-p", "pl-pronunciation"]:
          saw_pl_p = True
          break
        if tn in ["pl-IPA", "pl-IPA-auto"]:
          num_pl_IPA += 1
      if saw_pl_p:
        pagemsg("Already saw {{pl-p}}, skipping: %s" % unicode(t))
        continue
      if num_pl_IPA == 0:
        pagemsg("WARNING: Didn't see {{pl-IPA}} in Pronunciation section, skipping")
        continue
      if num_pl_IPA > 1:
        pagemsg("WARNING: Saw multiple {{pl-IPA}} in Pronunciation section, skipping")
        continue
      lines = subsections[k + 1].strip().split("\n")
      # Remove blank lines.
      lines = [line for line in lines if line]
      hyph_lines = []
      homophone_lines = []
      rhyme_lines = []
      audio_lines = []
      must_continue = False
      newtemp = None
      next_audio_param = 0
      has_respelling = False
      ipat = None
      for line in lines:
        origline = line
        # In case of "* {{pl-IPA|...}}", chop off the "* ".
        line = re.sub(r"^\*\s*(\{\{pl-IPA)", r"\1", line)
        if line.startswith("{{pl-IPA"):
          if newtemp:
            pagemsg("WARNING: Something wrong, already saw {{pl-IPA}}?: %s" % origline)
            must_continue = True
            break
          ipat = verify_template_is_full_line(["pl-IPA", "pl-IPA-auto"], line)
          if ipat is None:
            must_continue = True
            break
          newtemp_str = "{{pl-p}}"
          newtemp = list(blib.parse_text(newtemp_str).filter_templates())[0]
          for param in ipat.params:
            pn = pname(param)
            pv = unicode(param.value)
            if re.search("^[0-9]+$", pn):
              has_respelling = True
              newtemp.add(pn, pv, preserve_spacing=False)
            elif re.search("^qual[0-9]*$", pn):
              newtemp.add(pn.replace("qual", "q"), pv, preserve_spacing=False)
            else:
              pagemsg("WARNING: Unrecognized param %s=%s in {{pl-IPA}}, skipping: %s" % (
                pn, pv, origline))
              must_continue = True
              break
          if has_respelling:
            pagemsg("WARNING: {{pl-IPA}} has respelling: %s" % unicode(ipat))
          if must_continue:
            break
          continue
        if not line.startswith("* ") and not line.startswith("*{"):
          pagemsg("WARNING: Pronunciation section line doesn't start with '* ', skipping: %s"
              % origline)
          must_continue = True
          break
        if line.startswith("* "):
          line = line[2:]
        else:
          line = line[1:]
        if line.startswith("{{hyph"):
          hyph_lines.append(line)
        elif line.startswith("{{homophone") or line.startswith("{{hmp"):
          homophone_lines.append(line)
        elif line.startswith("{{audio"):
          audio_lines.append(line)
        elif line.startswith("{{rhyme"):
          rhyme_lines.append(line)
        else:
          pagemsg("WARNING: Unrecognized Pronunciation section line, skipping: %s" % origline)
          must_continue = True
          break
      if has_respelling and (rhyme_lines or hyph_lines):
        rhyme_hyph = []
        if rhyme_lines:
          rhyme_hyph.append("rhyme line(s) %s" % ",".join(rhyme_lines))
        if hyph_lines:
          rhyme_hyph.append("hyphenation line(s) %s" % ",".join(hyph_lines))
        # We formerly skipped these pages, but [[User:Vininn126]] requested running the bot on them.
        pagemsg("WARNING: Has respelling %s along with %s" % (
          ipat and unicode(ipat) or "UNKNOWN", " and ".join(rhyme_hyph)))
        #continue
      if must_continue:
        continue

      if audio_lines:
        must_continue = False
        for audio_line in audio_lines:
          audiot = verify_template_is_full_line("audio", audio_line)
          if audiot is None:
            must_continue = True
            break
          if getparam(audiot, "1") != "pl":
            pagemsg("WARNING: Wrong language in {{audio}}, skipping: %s" % audio_line)
            must_continue = True
            break
          audiofile = getparam(audiot, "2")
          audiogloss = getparam(audiot, "3")
          for param in audiot.params:
            pn = pname(param)
            pv = unicode(param.value)
            if pn not in ["1", "2", "3"]:
              pagemsg("WARNING: Unrecognized param %s=%s in {{audio}}, skipping: %s" % (
                pn, pv, audio_line))
              must_continue = True
              break
          if must_continue:
            break
          if audiogloss in ["Audio", "audio"]:
            audiogloss = ""
          if not newtemp:
            pagemsg("WARNING: Saw %s without {{pl-IPA}}, skipping: %s" % (unicode(audiot), audio_line))
            must_continue = True
            break
          next_audio_param += 1
          if next_audio_param == 1:
            paramsuf = ""
          else:
            paramsuf = str(next_audio_param)
          newtemp.add("a%s" % paramsuf, audiofile, preserve_spacing=False)
          if audiogloss:
            newtemp.add("ac%s" % paramsuf, audiogloss, preserve_spacing=False)
          pagemsg("Replacing %s with %s" % (unicode(audiot), unicode(newtemp)))
          extra_notes.append("incorporate %s into {{pl-p}}" % unicode(audiot))
        if must_continue:
          continue

      if rhyme_lines:
        if len(rhyme_lines) > 1:
          pagemsg("WARNING: Multiple rhyme lines, not removing: %s" % ", ".join(rhyme_lines))
          continue
        rhyme_line = rhyme_lines[0]
        rhymet = verify_template_is_full_line(["rhyme", "rhymes"], rhyme_line)
        if not rhymet:
          continue
        if getparam(rhymet, "1") != "pl":
          pagemsg("WARNING: Wrong language in {{%s}}, not removing: %s" % (tname(rhymet), rhyme_line))
          continue
        pagemsg("Ignoring rhyme line: %s" % rhyme_line)
        extra_notes.append("remove rhyme template %s" % unicode(rhymet))

      if hyph_lines:
        if len(hyph_lines) > 1:
          pagemsg("WARNING: Multiple hyphenation lines, not removing: %s" % ", ".join(hyph_lines))
          continue
        hyph_line = hyph_lines[0]
        hypht = verify_template_is_full_line(["hyph", "hyphenation"], hyph_line)
        if not hypht:
          continue
        if getparam(hypht, "1") != "pl":
          pagemsg("WARNING: Wrong language in {{%s}}, not removing: %s" % (tname(hypht), hyph_line))
          continue
        pagemsg("Ignoring hyphenation line: %s" % hyph_line)
        extra_notes.append("remove hyphenation template %s" % unicode(hypht))

      if homophone_lines:
        next_homophone_param = 0
        must_continue = False
        for homophone_line in homophone_lines:
          homophones = {}
          homophone_qualifiers = {}
          hmpt = verify_template_is_full_line(["hmp", "homophone", "homophones"], homophone_line)
          if not hmpt:
            must_continue = True
            break
          if getparam(hmpt, "1") != "pl":
            pagemsg("WARNING: Wrong language in {{%s}}, not removing: %s" % (tname(hmpt), homophone_line))
            must_continue = True
            break
          for param in hmpt.params:
            pn = pname(param)
            pv = unicode(param.value)
            if not re.search("^q?[0-9]+$", pn):
              pagemsg("WARNING: Unrecognized param %s=%s in {{%s}}, not removing: %s" %
                  (pn, pv, tname(hmpt), homophone_line))
              must_continue = True
              break
            if pn.startswith("q"):
              homophone_qualifiers[int(pn[1:])] = pv
            elif int(pn) > 1:
              homophones[int(pn) - 1] = pv
          if must_continue:
            break
          if not newtemp:
            pagemsg("WARNING: Something wrong, saw %s without {{pl-IPA}}, skipping" % unicode(hmpt))
            must_continue = True
            break
          hhs = []
          hhp_args = []
          for pn, pv in sorted(homophones.items()):
            next_homophone_param += 1
            hmp_param = "" if next_homophone_param == 1 else str(next_homophone_param)
            hhs.append(pv)
            if pn in homophone_qualifiers:
              hhp_args.append(("hhp%s" % hmp_param, homophone_qualifiers[pn]))
          if hhs:
            newtemp.add("hh", ",".join(hhs))
            for pn, pv in hhp_args:
              newtemp.add(pn, pv, preserve_spacing=False)
          pagemsg("Replacing %s with %s" % (unicode(hmpt), unicode(newtemp)))
          extra_notes.append("incorporate homophones into {{pl-p}}")
        if must_continue:
          continue

      pagemsg("Replaced %s with %s" % (unicode(ipat), unicode(newtemp)))

      all_lines = "\n".join([unicode(newtemp)])
      newsubsec = "%s\n\n" % all_lines
      if subsections[k + 1] != newsubsec:
        this_notes = ["convert {{pl-IPA}} to {{pl-p}}"] + extra_notes
        notes.extend(this_notes)
      subsections[k + 1] = newsubsec

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Convert {{pl-IPA}} to {{pl-p}}", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

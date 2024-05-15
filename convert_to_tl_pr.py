#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, unicodedata, json

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname, rsub_repeatedly

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)
  def verify_template_is_full_line(tn, line):
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
    if str(t) != line:
      pagemsg("WARNING: {{%s}} line has text other than {{%s...}}, skipping: %s" % (tntext, tntext, line))
      return None
    return t

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Tagalog", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  sect_for_wiki = 0
  for k in range(1, len(subsections), 2):
    if re.search(r"==\s*Etymology [0-9]+\s*==", subsections[k]):
      sect_for_wiki = k + 1
    elif re.search(r"==\s*Pronunciation\s*==", subsections[k]):
      secheader = re.sub(r"\s*Pronunciation\s*", "Pronunciation", subsections[k])
      if secheader != subsections[k]:
        subsections[k] = secheader
        notes.append("remove extraneous spaces in ==Pronunciation== header")
      extra_notes = []
      parsed = blib.parse_text(subsections[k + 1])
      num_tl_IPA = 0
      saw_tl_pr = False
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn in ["tl-pr"]:
          saw_tl_pr = True
          break
        if tn == "tl-IPA":
          num_tl_IPA += 1
      if saw_tl_pr:
        pagemsg("Already saw {{tl-pr}}, skipping: %s" % str(t))
        continue
      if num_tl_IPA == 0:
        pagemsg("WARNING: Didn't see {{tl-IPA}} in Pronunciation section, skipping")
        continue
      lines = subsections[k + 1].strip().split("\n")
      # Remove blank lines.
      lines = [line for line in lines if line]
      tl_IPA_lines = []
      hyph_lines = []
      homophone_lines = []
      rfap_lines = []
      rhyme_lines = []
      must_continue = False
      audioarg = ""
      lines_so_far = []
      for lineind, line in enumerate(lines):
        origline = line
        lines_so_far.append(line)
        if line.startswith("{{rfap"):
          line = "* " + line
        if "{{wiki" in line:
          m = re.search(r"^(.*?)(\{\{wiki[^{}]*\}\})(.*?)$", line)
          if not m:
            pagemsg("WARNING: Can't match {{wikipedia}} template in supposed line containing it: %s" % line)
          else:
            prevline, wikitemp, postline = m.groups()
            subsections[sect_for_wiki] = wikitemp + "\n" + subsections[sect_for_wiki]
            # Remove the {{wikipedia}} line or template from lines seen so far. Put back the remaining lines in case we
            # run into a problem later on, so we don't end up duplicating the {{wikipedia}} line. We accumulate lines
            # like this in case for some reason we have two {{wikipedia}} lines in the Pronunciation section.
            if not prevline and not postline:
              del lines_so_far[-1]
            else:
              line = prevline + postline
              lines_so_far[-1] = line
            subsections[k + 1] = "%s\n\n" % "\n".join(lines_so_far + lines[lineind + 1:])
            notes.append("move {{wikipedia}} line to top of etym section")
            if not prevline and not postline:
              continue
        # In case of "* {{tl-IPA|...}}", chop off the "* ".
        line = re.sub(r"^\*\s*(\{\{tl-IPA)", r"\1", line)
        if line.startswith("{{tl-IPA"):
          tl_IPA_lines.append(line)
          continue
        # Get rid of any leading * + whitespace; continue without it though.
        line = re.sub(r"^\*+\s*", "", line, 0, re.U)
        if line.startswith("{{hyph"):
          hyph_lines.append("* " + line)
        elif re.search(r"^(\{\{(q|qual|qualifier|q-lite|i|a)\|[^{}]*\}\} )?{\{(homophone|hmp)", line):
          homophone_lines.append("* " + line)
        elif line.startswith("{{rfap"):
          rfap_lines.append(line)
        elif re.search(r"^(Audio: *)?\{\{audio", line):
          line = re.sub("^Audio: *", "", line)
          audiot = verify_template_is_full_line("audio", line)
          if audiot is None:
            must_continue = True
            break
          if getparam(audiot, "1") != "tl":
            pagemsg("WARNING: Wrong language in {{audio}}, skipping: %s" % origline)
            must_continue = True
            break
          audiofile = getparam(audiot, "2")
          audiogloss = getparam(audiot, "3")
          for param in audiot.params:
            pn = pname(param)
            pv = str(param.value)
            if pn not in ["1", "2", "3"]:
              pagemsg("WARNING: Unrecognized param %s=%s in {{audio}}, skipping: %s" % (
                pn, pv, origline))
              must_continue = True
              break
          if must_continue:
            break
          if audiogloss in ["Audio", "audio"]:
            audiogloss = ""
          if audiogloss:
            audiogloss = "#%s" % audiogloss
          audiopart = "<audio:%s%s>" % (audiofile, audiogloss)
          audioarg += audiopart
          pagemsg("Replacing %s with argument part %s" % (str(audiot), audiopart))
          extra_notes.append("incorporate %s into {{tl-pr}}" % str(audiot))
        elif line.startswith("{{rhyme"):
          rhyme_lines.append(line)
        else:
          pagemsg("WARNING: Unrecognized Pronunciation section line, skipping: %s" % origline)
          must_continue = True
          break
      if must_continue:
        continue

      respellings = []
      respelling_args = []
      for tl_IPA_line in tl_IPA_lines:
        tl_IPA_qualifier_text = None
        m = re.search(r"^(\{\{tl-IPA[^{}]*\}\}) \{\{(?:q|qual|qualifier|q-lite|i)\|([^{}|=]*)\}\}$", tl_IPA_line)
        if m:
          tl_IPA_line, tl_IPA_qualifier_text = m.groups()
        ipat = verify_template_is_full_line("tl-IPA", tl_IPA_line)
        if ipat is None:
          must_continue = True
          break
        bare_arg = getparam(ipat, "1")
        for param in ipat.params:
          pn = pname(param)
          pv = str(param.value)
          if pn == "1":
            continue
          pagemsg("WARNING: Unrecognized param %s=%s in {{tl-IPA}}, skipping: %s" % (
            pn, pv, origline))
          must_continue = True
          break
        if must_continue:
          break
        respellings.append((bare_arg, tl_IPA_qualifier_text))
        respelling_args.append("%s%s" % (
          bare_arg or "+", "<qq:%s>" % tl_IPA_qualifier_text if tl_IPA_qualifier_text else ""))
      if must_continue:
        continue
      pronun = None
      if rhyme_lines or hyph_lines:
        pron_json_args = [respelling or pagetitle for respelling, qualifier in respellings]
        pronuns = expand_text("{{#invoke:tl-pronunciation|pron_json|%s|pagename=%s}}" % (
          "|".join(pron_json_args), pagetitle))
        if not pronuns:
          continue
        pronuns = json.loads(pronuns)
        syllabification_from_pagetitle = pronuns.get("syllabification_from_pagename", "")
        syllabifications_from_respelling = []
        rhyme_pronuns = []
        for pronun, (respelling, qualifier) in zip(pronuns["data"], respellings):
          if qualifier and re.search(r"\b(colloquial|obsolete|relaxed)\b", qualifier):
            pagemsg("Skipping respelling '%s' with qualifier '%s'" % (respelling, qualifier))
            continue
          syllabification_from_respelling = pronun.get("syllabification", "")
          if not syllabification_from_respelling:
            pagemsg("Unable to syllabify respelling '%s'" % respelling)
          else:
            for existing_respelling, existing_syllab in syllabifications_from_respelling:
              if existing_syllab == syllabification_from_respelling:
                break
            else: # no break
              syllabifications_from_respelling.append((respelling, syllabification_from_respelling))
          rhyme_pronun = pronun["rhyme"]
          rhyme_nsyl = pronun["num_syl"]
          for existing_respelling, existing_rhyme, existing_nsyl in rhyme_pronuns:
            if existing_rhyme == rhyme_pronun and existing_nsyl == rhyme_nsyl:
              break
          else: # no break
            rhyme_pronuns.append((respelling, rhyme_pronun, rhyme_nsyl))

      if rhyme_lines:
        if len(rhyme_lines) > 1:
          pagemsg("WARNING: Multiple rhyme lines, not removing: %s" % ", ".join(rhyme_lines))
          continue
        rhyme_line = rhyme_lines[0]
        rhymet = verify_template_is_full_line(["rhyme", "rhymes", "rhymes-lite"], rhyme_line)
        if not rhymet:
          continue
        if getparam(rhymet, "1") != "tl":
          pagemsg("WARNING: Wrong language in {{%s}}, not removing: %s" % (tname(rhymet), rhyme_line))
          continue
        rhymes = blib.fetch_param_chain(rhymet, "2")
        if len(rhymes) > 1:
          pagemsg("WARNING: Saw more than one rhyme in {{%s}}: %s" % (tname(rhymet), rhyme_line))
          continue
        rhyme = rhymes[0]
        nsyl = (getparam(rhymet, "s1") or getparam(rhymet, "s")).strip()
        if nsyl:
          if not re.search("^[0-9]+$", nsyl):
            pagemsg("WARNING: Bad syllable count in rhyme template: %s" % str(rhymet))
            continue
          nsyl = int(nsyl)
        else:
          nsyl = None
        if len(rhyme_pronuns) > 1:
          pagemsg("WARNING: Saw multiple auto-generated rhymes, can't handle: %s" % ",".join(
            "%s/%s/%s" % (respelling, rhyme, nsyl) for respelling, rhyme, nsyl in rhyme_pronuns))
          continue
        rhyme_respelling, rhyme_pronun, rhyme_nsyl = rhyme_pronuns[0]
        if rhyme == rhyme_pronun:
          if nsyl is None:
            pagemsg("Removing rhyme %s, same as pronunciation-based rhyme for respelling '%s': %s"
                % (rhyme, rhyme_respelling, str(rhymet)))
            extra_notes.append("remove {{%s}} same as auto-generated rhyme" % tname(rhymet))
          elif nsyl == rhyme_nsyl:
            pagemsg("Removing rhyme %s, same as pronunciation-based rhyme for respelling '%s' and syllable count %s matches: %s"
                % (rhyme, rhyme_respelling, nsyl, str(rhymet)))
            extra_notes.append("remove {{%s}} same as auto-generated rhyme and syllable count" % tname(rhymet))
          elif pagetitle in allow_mismatching_nsyl:
            pagemsg("Removing rhyme %s, same as pronunciation-based rhyme for respelling '%s'; syllable count %s mismatches pronunciation syllable count %s but is known to be incorrect so is ignored: %s"
                % (rhyme, rhyme_respelling, nsyl, rhyme_nsyl, str(rhymet)))
            extra_notes.append("ignore known-incorrect syllable count %s in {{%s}}" % (nsyl, tname(rhymet)))
        else:
          pagemsg("WARNING: For spelling '%s', rhyme %s%s not same as pronunciation-based rhyme %s: %s"
              % (rhyme_respelling, rhyme, " with explicit syllable count %s" % nsyl if nsyl is not None else "",
                rhyme_pronun, str(rhymet)))
          continue

      if audioarg:
        if len(respelling_args) > 1:
          pagemsg("WARNING: Saw audio arg %s and multiple respellings %s, don't know where to add audio arg" % (
            audioarg, "|".join(respelling_args)))
          continue
        respelling_args[0] += audioarg

      syll_arg = ""
      if hyph_lines:
        if len(syllabifications_from_respelling) > 1:
          pagemsg("WARNING: Saw multiple auto-generated syllabifications, can't handle: %s" % ",".join(
            "%s/%s" % (respelling, syllab) for respelling, syllab in syllabifications_from_respelling))
          continue
        syllabification_from_pagetitle = pronuns["syllabification_from_pagename"]
        if syllabifications_from_respelling:
          _, syllabification_from_respelling = syllabifications_from_respelling[0]
        else:
          syllabification_from_respelling = None
        syllab_respelling = "|".join(respelling_args)
        if len(hyph_lines) > 1:
          pagemsg("WARNING: Multiple syllabification lines, not removing: %s" % ", ".join(hyph_lines))
        else:
          assert hyph_lines[0].startswith("* ")
          hyph_line = hyph_lines[0][2:]
          hypht = verify_template_is_full_line(["hyph", "hyphenation", "hyph-lite"], hyph_line)
          if hypht:
            syls = []
            if getparam(hypht, "1") != "tl":
              pagemsg("WARNING: Wrong language in {{%s}}, not removing: %s" % (tname(hypht), hyph_line))
            else:
              for param in hypht.params:
                pn = pname(param)
                pv = str(param.value)
                if not re.search("^[0-9]+$", pn) and not (pn == "caption" and pv == "Syllabification"):
                  pagemsg("WARNING: Unrecognized param %s=%s in {{%s}}, not removing: %s" %
                      (pn, pv, tname(hypht), hyph_line))
                  break
                if pn == "caption":
                  continue
                if not pv:
                  pagemsg("WARNING: Multiple syllabifications in a single template, not removing: %s" % hyph_line)
                  break
                if int(pn) > 1:
                  syls.append(pv)
              else: # no break
                specified_syllabification = ".".join(syls)
                if specified_syllabification == syllabification_from_respelling:
                  pagemsg("Removing explicit syllabification same as auto-syllabification: %s" % hyph_line)
                  extra_notes.append("remove {{%s}} same as respelling auto-syllabification" % tname(hypht))
                elif specified_syllabification == syllabification_from_pagetitle:
                  if respelling_args == ["+"]:
                    pagemsg("WARNING: Something wrong, {{tl-IPA}} used with '+' or empty respelling but respelling auto-syllabification %s different from pagetitle auto-syllabification %s"
                      % (syllabification_from_respelling or "(nil)", syllabification_from_pagetitle))
                    continue
                  else:
                    pagemsg("Non-default respelling %s, explicit syllabification %s not same as syllabification from respelling %s but same as pagetitle auto-syllabification, replacing with <syll:+>: %s" %
                        (syllab_respelling, specified_syllabification, syllabification_from_respelling or "(nil)", hyph_line))
                    syll_arg = "+"
                    extra_notes.append("remove/incorporate {{%s}} same as pagetitle auto-syllabification into {{tl-pr}}" % tname(hypht))
                elif specified_syllabification == pagetitle:
                  pagemsg("Non-default respelling %s, explicit syllabification %s not same as syllabification from respelling %s or syllabification from pagetitle %s but same as pagetitle, replacing with <syll:#>: %s" %
                      (syllab_respelling, specified_syllabification, syllabification_from_respelling or "(nil)",
                       syllabification_from_pagetitle, hyph_line))
                  syll_arg = "#"
                  extra_notes.append("remove/incorporate {{%s}} same as pagetitle into {{tl-pr}}" % tname(hypht))
                else:
                  hyph_text = (
                    "respelling auto-syllabification %s or pagetitle auto-syllabification %s" % (
                      syllabification_from_respelling or "(nil)", syllabification_from_pagetitle
                    ) if syllabification_from_respelling != syllabification_from_pagetitle else
                    "respelling/pagetitle auto-syllabification %s" % (syllabification_from_respelling or "(nil)")
                  )
                  if respelling_args == ["+"]:
                    pagemsg("WARNING: {{tl-IPA}} used with '+' or empty respelling but specified syllabification %s not equal to %s, adding explicitly: %s" %
                        (specified_syllabification, hyph_text, hyph_line))
                  else:
                    pagemsg("WARNING: Non-default pronunciation %s and specified syllabification %s not equal to %s, adding explicitly: %s" %
                        (syllab_respelling, specified_syllabification, hyph_text, hyph_line))
                  syll_arg = specified_syllabification
                  extra_notes.append("remove/incorporate {{%s}} into {{tl-pr}}" % tname(hypht))
                hyph_lines = []

      if homophone_lines:
        if len(homophone_lines) > 1:
          pagemsg("WARNING: Multiple homophone lines, not removing: %s" % ", ".join(homophone_lines))
        else:
          assert homophone_lines[0].startswith("* ")
          homophone_line = homophone_lines[0][2:]
          homophones = {}
          homophone_qualifiers = {}
          homophone_qualifier_text = None
          m = re.search(r"^(\{\{(?:hmp|homophones?)\|[^{}]*\}\}) \{\{(?:q|qual|qualifier|q-lite|i|a)\|([^{}|=]*)\}\}$", homophone_line)
          if m:
            homophone_line, homophone_qualifier_text = m.groups()
          if not m:
            m = re.search(r"^\{\{(?:q|qual|qualifier|q-lite|i|a)\|([^{}|=]*)\}\} (\{\{(?:hmp|homophones?)\|[^{}]*\}\})", homophone_line)
            if m:
              homophone_qualifier_text, homophone_line = m.groups()
          if not m:
            m = re.search(r"^(\{\{(?:hmp|homophones?)\|[^{}]*\}\}) \('*([^{}|=]*?)'*\)$", homophone_line)
            if m:
              homophone_line, homophone_qualifier_text = m.groups()
          hmpt = verify_template_is_full_line(["hmp", "homophone", "homophones"], homophone_line)
          if hmpt:
            if getparam(hmpt, "1") != "tl":
              pagemsg("WARNING: Wrong language in {{%s}}, not removing: %s" % (tname(hmpt), homophone_line))
            else:
              for param in hmpt.params:
                pn = pname(param)
                pv = str(param.value)
                if pn == "q":
                  pn = "q1"
                if not re.search("^q?[0-9]+$", pn):
                  pagemsg("WARNING: Unrecognized param %s=%s in {{%s}}, not removing: %s" %
                      (pn, pv, tname(hmpt), homophone_line))
                  break
                if pn.startswith("q"):
                  homophone_qualifiers[int(pn[1:])] = pv
                elif int(pn) > 1:
                  homophones[int(pn) - 1] = pv
              else: # no break
                hmp_args = []
                for pn, pv in sorted(homophones.items()):
                  hmp_args.append(pv)
                  if pn in homophone_qualifiers:
                    hmp_args[-1] += "<q:%s>" % homophone_qualifiers[pn]
                if homophone_qualifier_text:
                  hmp_args[-1] += "<q:%s>" % homophone_qualifier_text
                hmp_arg = "<hmp:%s>" % ",".join(hmp_args)
                if len(respelling_args) > 1:
                  pagemsg("WARNING: Saw homophone arg %s and multiple respellings %s, don't know where to add homophone arg" % (
                    hmp_arg, "|".join(respelling_args)))
                  continue
                extra_notes.append("incorporate homophones into {{tl-pr}}")
                homophone_lines = []

      if syll_arg:
        syll_arg = "|syll=%s" % syll_arg
      if respelling_args == ["+"]:
        tl_pr = "{{tl-pr%s}}" % syll_arg
      else:
        tl_pr = "{{tl-pr|%s%s}}" % ("|".join(respelling_args), syll_arg)
      pagemsg("Replaced %s with %s" % (str(ipat), tl_pr))

      all_lines = "\n".join([tl_pr] + rfap_lines + hyph_lines + homophone_lines)
      newsubsec = "%s\n\n" % all_lines
      if subsections[k + 1] != newsubsec:
        this_notes = ["convert {{tl-IPA}} to {{tl-pr}}"] + extra_notes
        notes.extend(this_notes)
      subsections[k + 1] = newsubsec

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Convert {{tl-IPA}} to {{tl-pr}}", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
parser.add_argument("--allow-mismatching-nsyl", help="Comma-separated list of pages with known incorrect value for number of syllables in {{rhymes}} template.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

allow_mismatching_nsyl = set()
if args.allow_mismatching_nsyl:
  allow_mismatching_nsyl = set(blib.split_utf8_arg(args.allow_mismatching_nsyl))

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

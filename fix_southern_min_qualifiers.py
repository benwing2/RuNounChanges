#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, errandmsg, site

def get_params_from_zh_l(t):
  # This is an utter piece of shit. Ported from lines 53-74 of [[Module:zh/link]].
  def getp(param):
    return getparam(t, param)
  arg1 = getp("1")
  arg2 = getp("2")
  arg3 = getp("3")
  arg4 = getp("4")
  arggloss = getp("gloss")
  argtr = getp("tr")
  text = None
  tr = None
  gloss = None
  if arg2 and re.search("[一-龯㐀-䶵]", arg2):
    gloss = arg4
    tr = arg3
    text = arg1 + "/" + arg2
  else:
    text = arg1
    if arggloss:
      tr = arg2
      gloss = arggloss
    else:
      if arg3 or (arg2 and (re.search("[āōēīūǖáóéíúǘǎǒěǐǔǚàòèìùǜâêîôû̍ⁿ]", arg2) or re.search("[bcdfghjklmnpqrstwz]h?y?[aeiou][aeiou]?[iumnptk]?g?[1-9]", arg2))):
        tr = arg2
        gloss = arg3
      else:
        gloss = arg2
  if argtr:
    tr = argtr
    gloss = gloss or arg2
  return text, tr, gloss

def find_southern_min_types(index, pagetitle, linkt, linkpage, linkgloss):
  def make_msg_txt(txt):
    return "Page %s %s: Link page [[%s]]%s in %s: %s" % (
        index, pagetitle, linkpage, linkgloss and " (glossed as '%s')" % linkgloss or "", str(linkt), txt)
  def errandpagemsg(txt):
    errandmsg(make_msg_txt(txt))
  def pagemsg(txt):
    msg(make_msg_txt(txt))
  page = pywikibot.Page(site, blib.remove_links(linkpage))
  linkmsg = "synonym/antonym %s (template %s)" % (linkpage, str(linkt))
  if not blib.safe_page_exists(page, errandpagemsg):
    return "Found %s but page doesn't exist" % linkmsg
  text = blib.safe_page_text(page, errandpagemsg)
  if not text:
    return "Error fetching text for %s" % linkmsg
  chinese_text = blib.find_lang_section(text, "Chinese", pagemsg)
  if chinese_text is None:
    return "Could locate Chinese section for %s" % linkmsg

  def find_section_min_types(sectext):
    parsed = blib.parse_text(sectext)
    hokkien = False
    teochew = False
    leizhou = False
    saw_zh_pron = False
    saw_zh_label = False
    for t in parsed.filter_templates():
      tn = tname(t)
      def getp(param):
        return getparam(t, param)
      if tn == "zh-pron":
        if getp("mn"):
          hokkien = True
        if getp("mn-t"):
          teochew = True
        if getp("mn-l"):
          leizhou = True
        saw_zh_pron = True

      if tn in blib.label_templates and getp("1") == "zh":
        for i in range(2, 30):
          label = getp(str(i))
          if "Hokkien" in label:
            hokkien = True
          if "Teochew" in label:
            teochew = True
          if "Leizhou" in label:
            leizhou = True
        saw_zh_label = True
    lects_seen = []
    if hokkien:
      lects_seen.append("Hokkien")
    if teochew:
      lects_seen.append("Teochew")
    if leizhou:
      lects_seen.append("Leizhou")
    return lects_seen, saw_zh_pron, saw_zh_label

  if "Etymology 1" in chinese_text or "Pronunciation 1" in chinese_text:
    subsections, subsections_by_header, subsection_headers, subsection_levels = (
      blib.split_text_into_subsections(chinese_text, pagemsg)
    )
    etym_pron_sectext = []
    index_of_secbegin = None
    for k in range(2, len(subsections), 2):
      if re.search("= *(Etymology|Pronunciation) +[0-9]+ *=", subsections[k - 1]):
        if index_of_secbegin:
          etym_pron_sectext.append((subsections[index_of_secbegin].strip(), "".join(subsections[index_of_secbegin: k - 1])))
        index_of_secbegin = k - 1
    if not index_of_secbegin:
      return ("Something wrong, can't find any Etymology N or Pronunciation N sections in Chinese section for %s" %
              linkmsg)
    etym_pron_sectext.append((subsections[index_of_secbegin].strip(), "".join(subsections[index_of_secbegin:])))

    southern_min_types = None
    header_for_southern_min_types = None
    for stage in [1, 2]:
      for secheader, sectext in etym_pron_sectext:
        if stage == 1 and linkgloss and not re.search(re.escape(blib.remove_links(linkgloss)), sectext):
          pagemsg("Stage 1 processing section header %s, skipping because bare link gloss '%s' not found in section text" %
                  (secheader, blib.remove_links(linkgloss)))
          continue
        section_min_types, _, _ = find_section_min_types(sectext)
        if section_min_types:
          if not southern_min_types:
            southern_min_types = section_min_types
            header_for_southern_min_types = secheader
          elif southern_min_types != section_min_types:
            return "Saw multiple Etymology/Pronunciation sections with different Southern Min Types for %s: section %s has %s while section %s has %s; skipping" % (
              linkmsg, header_for_southern_min_types, ",".join(southern_min_types), secheader, ",".join(section_min_types))
      if southern_min_types:
        break

    if not southern_min_types:
      return "Multiple Etymology or Pronunciation sections for %s and couldn't identify any Southern Min lect from scraping page" % (
          linkmsg)
    return southern_min_types

  section_min_types, saw_zh_pron, saw_zh_label = find_section_min_types(chinese_text)
  if not section_min_types:
    saw_msgs = []
    if saw_zh_pron:
      saw_msgs.append("saw {{zh-pron}}")
    else:
      saw_msgs.append("didn't see {{zh-pron}}")
    if saw_zh_label:
      saw_msgs.append("saw {{lb|zh|...}}")
    else:
      saw_msgs.append("didn't see any {{lb|zh|...}}")
    parsed = blib.parse_text(chinese_text)
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "zh-see":
        canon = getparam(t, "1")
        pagemsg(
            "WARNING (may be ignorable): Couldn't identify any Southern Min lect from scraping page (%s), but saw %s, redirecting"
            % ("; ".join(saw_msgs), str(t)))
        return find_southern_min_types(index, pagetitle, linkt, canon, linkgloss)
    return "Couldn't identify any Southern Min lect from scraping page %s (%s)" % (linkmsg, "; ".join(saw_msgs))
  return section_min_types

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  lines = text.split("\n")
  new_lines = []
  for line in lines:
    if re.search(r"(Min Nan|Southern Min).*\{\{zh-l *\|", line):
      line_parts = re.split(
          r"(\{\{(?:%s)\|[^{}]*(?:Min Nan|Southern Min)[^{}]*\}\} *\{\{zh-l\|[^{}]*\}\}(?:, *\{\{zh-l\|[^{}]*\}\})*)" %
          "|".join(blib.qualifier_templates), line)
      if len(line_parts) == 1:
        pagemsg("WARNING: Couldn't parse apparent synonyms/antonyms line: %s" % line)
        new_lines.append(line)
        continue
      frobbed_parts = []
      for line_part_no in range(len(line_parts)):
        line_part = line_parts[line_part_no]
        if line_part_no % 2 == 0:
          frobbed_parts.append(line_part)
        else:
          parsed = blib.parse_text(line_part)
          q_t = None
          zh_l_ts = []
          for t in parsed.filter_templates(recursive=False):
            tn = tname(t)
            if tn in blib.qualifier_templates:
              if q_t is not None:
                pagemsg("WARNING: Found two qualifier templates %s and %s in synonyms/antonyms line part %s, can't parse: %s" %
                        (str(q_t), str(t), line_part_no, line))
                break
              else:
                q_t = t
            elif tn == "zh-l":
              zh_l_ts.append(t)
          else: # no break
            if not q_t:
              pagemsg("WARNING: Couldn't find qualifier template in synonyms/antonyms line part %s, can't parse: %s" %
                      (line_part_no, line))
            elif not zh_l_ts:
              pagemsg("WARNING: Couldn't find {{zh-l}} link(s) in synonyms/antonyms line part %s, can't parse: %s" %
                      (line_part_no, line))
            else:
              all_min_types = []
              all_linkpages = []
              min_warnings = []
              for zh_l_t in zh_l_ts:
                linkpage, linktr, linkgloss = get_params_from_zh_l(zh_l_t)
                if linkpage.startswith("*"):
                  linkpage = linkpage[1:]
                if "/" in linkpage:
                  linkpage = re.sub("/.*", "", linkpage)
                all_linkpages.append(linkpage)
                min_types = find_southern_min_types(index, pagetitle, zh_l_t, linkpage, linkgloss)
                if type(min_types) is str:
                  min_warnings.append(min_types)
                elif min_types:
                  pagemsg("For link page [[%s]], found %s: %s" % (linkpage, ", ".join(min_types), line))
                  for min_type in min_types:
                    if min_type not in all_min_types:
                      all_min_types.append(min_type)
              if not all_min_types:
                pagemsg("WARNING: Couldn't locate any Southern Min types among link page(s) %s (reason(s): %s): %s" % (
                  ",".join(all_linkpages), "; ".join(min_warnings), line))
              else:
                if min_warnings:
                  pagemsg("WARNING (may be ignorable): Was able to locate Southern Min type(s) %s among link page(s) %s, but with some warnings (%s): %s" % (
                    ", ".join(all_min_types), ",".join(all_linkpages), "; ".join(min_warnings), line))
                qualifier_vals = blib.fetch_param_chain(q_t, "1")
                frobbed_qualifier_vals = []
                saw_min_nan = False
                for val in qualifier_vals:
                  if val in ["Min Nan", "Southern Min"]:
                    if saw_min_nan:
                      pagemsg("WARNING: Saw 'Min Nan' or 'Southern Min' multiple times in qualifier template %s, not changing: %s" %
                              (str(q_t), line))
                      break
                    saw_min_nan = val
                    frobbed_qualifier_vals.extend(all_min_types)
                  else:
                    frobbed_qualifier_vals.append(val)
                else: # no break
                  if saw_min_nan:
                    blib.set_param_chain(q_t, frobbed_qualifier_vals, "1")
                    note = ("qualifier '%s' with '%s' in Synonyms/Antonyms section by examining associated term(s) %s" %
                            (saw_min_nan, "|".join(all_min_types),
                             ",".join("[[%s]]" % term for term in all_linkpages)))
                    pagemsg("Replacing %s: %s" % (note, line))
                    notes.append("replace %s" % note)
                    line_part = str(parsed)
                  else:
                    pagemsg("WARNING: Couldn't find 'Min Nan' or 'Southern Min' qualifier in template %s: %s" % (
                      str(q_t), line))
          frobbed_parts.append(line_part)
      line = "".join(frobbed_parts)
    new_lines.append(line)

  text = "\n".join(new_lines)
  return text, notes

parser = blib.create_argparser("Convert 'Min Nan' and 'Southern Min' in qualifiers to appropriate lects",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

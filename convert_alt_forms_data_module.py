#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse
from dataclasses import dataclass

import blib
from blib import getparam, rmparam, set_template_name, msg, errandmsg, site, tname

@dataclass
class LabelData:
  label: str
  label_lines: list
  last_label_line: str
  wikipedia: str
  wikipedia_comment: str
  display: str
  display_comment: str
  appendix: str
  appendix_comment: str
  aliases: list

#blib.getLanguageData()

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  def ucfirst(txt):
    if not txt:
      return txt
    return txt[0].upper() + txt[1:]

  notes = []

  #m = re.search("^Module:(.*):Dialects$", pagename)
  #langname = None
  #if m:
  #  code = m.group(1)
  #  if code in blib.languages_byCode:
  #    langname = blib.languages_byCode[code]["canonicalName"]
  #  else:
  #    errandpagemsg("WARNING: Can't locate language %s" % code)

  new_lines = []
  lines = text.split("\n")
  labels_seen = []
  indexed_labels = {}
  label_lines = []
  label = False
  wikipedia = None
  wikipedia_comment = None
  display = None
  display_comment = None
  appendix = None
  appendix_comment = None
  in_label = False
  in_return = False
  in_data = False
  saw_data = False

  either_quote_string_re = '("[^"]*?"|' + "'[^']*?')"
  true_or_either_quote_string_re = '(true|"[^"]*?"|' + "'[^']*?')"

  for lineind, line in enumerate(lines):
    lineno = lineind + 1
    def linemsg(txt):
      pagemsg("Line %s: %s" % (lineno, txt))
    if re.search(r"^labels *\[", line):
      if label or in_data or in_return:
        errandpagemsg("WARNING: Saw nested labels on line %s, can't handle file: %s" % (lineno, line))
        return
      if label_lines:
        labels_seen.append(label_lines)
        label_lines = []
      wikipedia = None
      wikipedia_comment = None
      display = None
      display_comment = None
      appendix = None
      appendix_comment = None
      m = re.search(r"^labels *\[%s\] *= *\{$" % (either_quote_string_re), line.rstrip())
      if not m:
        linemsg("WARNING: Unable to parse labels start line: %s" % line)
        label_lines.append(line)
      else:
        label = m.group(1)[1:-1]
        in_label = True

    elif re.search(r"^aliases *\[", line):
      m = re.search(r"^aliases *\[%s\] *= *%s$" % (either_quote_string_re, either_quote_string_re), line.rstrip())
      if not m:
        linemsg("WARNING: Unable to parse aliases line: %s" % line)
        label_lines.append(line)
        continue
      # an alias
      alias, canon = m.groups()
      canon = canon[1:-1] # discard quotes
      alias = alias[1:-1] # discard quotes
      if canon not in indexed_labels:
        linemsg("WARNING: Unable to locate canonical label '%s' for aliases: %s" % (canon, line))
        label_lines.append(line)
        continue
      labels_seen[indexed_labels[canon]].aliases.append(alias)
      continue

    elif line.strip() == "local data = {":
      in_data = True

    elif line.strip() == "}":
      if in_return:
        in_return = False
        continue
      if in_data:
        in_data = False
        saw_data = True
        continue
      if not in_label:
        errandpagemsg("WARNING: Saw non-label object on line %s, can't handle file: %s" % (lineno, line))
        return
      if label_lines and not label_lines[-1].endswith(","):
        # FIXME: This could break if there are quotes around the comment sign
        m = re.search("^(.*?)(--.*)$", label_lines[-1])
        if m:
          pre_comment, comment = m.groups()
          if pre_comment.strip() and not pre_comment.strip().endswith(","):
            label_lines[-1] = "%s, %s" % (pre_comment.rstrip(), comment)
        else:
          label_lines[-1] += ","

      labels_seen.append(LabelData(label, label_lines, line, wikipedia, wikipedia_comment, display, display_comment,
                                   appendix, appendix_comment, []))
      indexed_labels[label] = len(labels_seen) - 1
      label = False
      label_lines = []
      in_label = False

    elif in_return:
      continue

    elif in_data:
      m = re.search(r"^\[%s\] *= *\{ *\[%s\] *= *%s *, *\[%s\] *= *%s *\},?$" % (
        either_quote_string_re, either_quote_string_re, either_quote_string_re, either_quote_string_re,
        either_quote_string_re), line.strip())
      if m:
        label, prop1, val1, prop2, val2 = m.groups()
        label = label[1:-1]
        prop1 = prop1[1:-1]
        val1 = val1[1:-1]
        prop2 = prop2[1:-1]
        val2 = val2[1:-1]
        wikipedia = False
        display = False
        if prop1 == "link":
          wikipedia = val1
        elif prop1 == "display":
          display = val1
        else:
          linemsg("WARNING: Unrecognized property '%s' in data line, skipping file: %s" % (prop1, line))
          return
        if prop2 == "link":
          wikipedia = val2
        elif prop2 == "display":
          display = val2
        else:
          linemsg("WARNING: Unrecognized property '%s' in data line, skipping file: %s" % (prop2, line))
          return
        labels_seen.append(LabelData(label, [], "}", wikipedia, None, display, None, None, None, []))
        continue
      m = re.search(r"^\[%s\] *= *\{ *\[%s\] *= *%s *\},?$" % (
        either_quote_string_re, either_quote_string_re, either_quote_string_re), line.strip())
      if m:
        label, prop1, val1 = m.groups()
        label = label[1:-1]
        prop1 = prop1[1:-1]
        val1 = val1[1:-1]
        wikipedia = False
        display = False
        if prop1 == "link":
          wikipedia = val1
        elif prop1 == "display":
          display = val1
        else:
          linemsg("WARNING: Unrecognized property '%s' in data line, skipping file: %s" % (prop1, line))
          return
        labels_seen.append(LabelData(label, [], "}", wikipedia, None, display, None, None, None, []))
        continue
      linemsg("WARNING: Unrecognized data line, skipping file: %s" % line)
      return

    elif in_label:
      origline = line
      line = line.strip()

      m = re.search("^link *= *%s,?( *--.*)?$" % either_quote_string_re, line)
      if m:
        wikipedia = m.group(1)[1:-1]
        wikipedia_comment = m.group(2)
      if not m:
        m = re.search("^display *= *%s,?( *--.*)?$" % either_quote_string_re, line)
        if m:
          display = m.group(1)[1:-1]
          display_comment = m.group(2)
      if not m:
        m = re.search("^appendix *= *%s,?( *--.*)?$" % either_quote_string_re, line)
        if m:
          appendix = m.group(1)[1:-1]
          appendix_comment = m.group(2)
      if not m:
        linemsg("WARNING: Unrecognized labels line: %s" % line)
        label_lines.append(line)

    elif line.startswith("alias("):
      m = re.search(r"""^alias\(%s, *{(.*?)}\)$""" % either_quote_string_re, line)
      if not m:
        linemsg("WARNING: Unable to parse alias line: %s" % line)
        label_lines.append(line)
        continue
      canon, aliases = m.groups()
      canon = canon[1:-1] # discard quotes
      if canon not in indexed_labels:
        linemsg("WARNING: Unable to locate canonical label '%s' for aliases: %s" % (canon, line))
        label_lines.append(line)
        continue
      aliases = re.split(", *", aliases)
      stripped_aliases = []
      must_continue = False
      for alias in aliases:
        if not re.search("^" + either_quote_string_re + "$", alias):
          linemsg("WARNING: Alias '%s' isn't surrounded by quotes: %s" % (alias, line))
          must_continue = True
          break
        stripped_aliases.append(alias[1:-1])
      if must_continue:
        continue
      labels_seen[indexed_labels[canon]].aliases.extend(stripped_aliases)

    elif line.startswith("local function alias("):
      pass

    elif line.strip() == "return {":
      in_return = True

    elif saw_data and line.strip() == "return data":
      pass

    elif re.search(r"^return *\{ *labels *= *labels *\}$", line):
      pass

    elif line.startswith("return "):
      errandpagemsg("WARNING: Unrecognized return statement, skipping file: %s" % line)
      return

    else:
      label_lines.append(line)

  if label_lines:
    labels_seen.append(label_lines)

  def canonicalize_quotes(quoteform):
    quoteform
  for labelobj in labels_seen:
    if isinstance(labelobj, LabelData):
      new_lines.append('labels["%s"] = {' % labelobj.label)
      if labelobj.aliases:
        new_lines.append("\taliases = {%s}," % ", ".join('"%s"' % alias for alias in labelobj.aliases))
      display = labelobj.display or labelobj.label
      if labelobj.appendix is not None:
        display = "[[%s|%s]]" % (labelobj.appendix, display)
      if display != labelobj.label:
        new_lines.append('\tdisplay = "%s",%s%s' % (
          display, labelobj.display_comment or "", labelobj.appendix_comment or ""))
      if labelobj.wikipedia is not None:
        new_lines.append("\tWikipedia = %s,%s" % (
          "true" if labelobj.wikipedia == labelobj.label else '"%s"' % labelobj.wikipedia,
          labelobj.wikipedia_comment or ""))
      new_lines.extend(labelobj.label_lines)
      new_lines.append(labelobj.last_label_line)

  text = "\n".join(new_lines) + "\n"
  text = text.replace("\n\n\n", "\n\n")
  text = re.sub("^    ", "\t", text, 0, re.M)

  notes = ["convert dialectal data module to labels data module"]
  return text, notes

parser = blib.create_argparser("Convert dialectal data module to labels data module", include_pagefile=True,
                               include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

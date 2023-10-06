#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errandmsg, site, tname

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  notes = []

  new_lines = []
  lines = text.split("\n")
  tag = False

  either_quote_string_re = '(".*?"|' + "'.*?')"

  for lineind, line in enumerate(lines):
    lineno = lineind + 1
    origline = line
    def linemsg(txt):
      pagemsg("Line %s: %s: %s" % (lineno, txt, origline.strip()))
    if line.startswith("tags["):
      if tag:
        errandpagemsg("WARNING: Saw nested tags on line %s, can't handle file" % lineno)
        return
      tag_lineno = lineno
      tag_type = {}
      glossary = {}
      glossary_type = {}
      shortcuts = {}
      wikidata = {}
      display = {}
      misc_keys = []
      m = re.search(r"^tags\[%s\] = \{([ \t]*--.*)?$" % (either_quote_string_re), line.rstrip())
      if not m:
        linemsg("WARNING: Unable to parse tags start line")
      else:
        tag = m.group(1)[1:-1]
      new_lines.append(line)
    elif line.strip().startswith("}") and tag:
      tag = False

      numbered_lines = []
      def output_numbered_item(dest, format_output):
        if not dest:
          numbered_lines.append("\tnil,")
        else:
          output = format_output(dest[0])
          comment = dest[1]
          numbered_lines.append("\t%s,%s" % (output, comment or ""))
      output_numbered_item(tag_type, lambda val: '"%s"' % val)

      def format_glossary(val):
        if glossary_type and glossary_type[1]:
          linemsg("WARNING: Ignoring comment '%s' to glossary_type" % glossary_type[1])
        if glossary_type:
          gltype = glossary_type[0]
        else:
          gltype = "APPENDIX"
        if val == True:
          return gltype
        elif gltype == "APPENDIX":
          return '"%s"' % val
        elif gltype == "WP":
          return '"w:%s"' % val
        elif gltype == "WIKT":
          return '"wikt:%s"' % val
        else:
          linemsg("WARNING: Something wrong, saw bad glossary type '%s'" % gltype)
          return '"%s"' % val

      def format_shortcuts(val):
        if len(val) == 1:
          return '"%s"' % val[0]
        else:
          return "{%s}" % ", ".join('"%s"' % v for v in val)

      output_numbered_item(glossary, format_glossary)
      output_numbered_item(shortcuts, format_shortcuts)
      output_numbered_item(wikidata, lambda val: val)
      while numbered_lines and numbered_lines[-1] == "\tnil,":
        del numbered_lines[-1]
      for numbered_line in numbered_lines:
        new_lines.append(numbered_line)
      def output_keyed_item(key, dest, format_output):
        if dest:
          output = format_output(dest[0])
          comment = dest[1]
          new_lines.append("\t%s = %s,%s" % (key, output, comment or ""))
      output_keyed_item("display", display, lambda val: '"%s"' % val)
      for k, v, comment in misc_keys:
        new_lines.append("\t%s = %s,%s" % (k, v, comment or ""))
      new_lines.append(origline)

    elif tag:
      line = line.strip()
      comment = None
      m = re.search(r"^(.*?)([ \t]*--.*)$", line)
      if m:
        line, comment = m.groups()
      if line.endswith(","):
        line = line[:-1]

      def process_shortcuts(value):
        if value == "nil":
          return False
        m = re.search(r"^\{(.*)\}$", value)
        if m:
          inside = m.group(1).strip()
          if not inside:
            linemsg("WARNING: Empty shortcuts line")
            return None
          if inside.endswith(","):
            inside = inside[:-1].strip()
          split_shortcuts = re.split(either_quote_string_re, m.group(1).strip())
          shortcuts = []
          for i, split_shortcut in enumerate(split_shortcuts):
            if i % 2 == 1:
              shortcuts.append(split_shortcut[1:-1])
            elif ((i == 0 or i == len(split_shortcuts) - 1) and split_shortcut.strip()
                  or (i > 0 and i < len(split_shortcuts) - 1) and split_shortcut.strip() != ","):
              linemsg("WARNING: Junk '%s' between shortcuts" % split_shortcut)
              return None
          return shortcuts
        if not re.search("^%s$" % either_quote_string_re, value):
          linemsg("WARNING: Unable to parse shortcut line")
          return None
        return [inside[1:-1]]

      def process_tag_type(value):
        if not re.search("^%s$" % either_quote_string_re, value):
          linemsg("WARNING: Unrecognized value for tag_type '%s'" % value)
          return None
        return value[1:-1]
      def process_glossary(value):
        if value == "true":
          return True
        if value == "nil":
          return False
        if not re.search("^%s$" % either_quote_string_re, value):
          linemsg("WARNING: Unrecognized value for glossary '%s'" % value)
          return None
        stripped_val = value[1:-1]
        if stripped_val == tag:
          return True
        return stripped_val
      def process_glossary_type(value):
        if value == "nil":
          return "APPENDIX"
        if value in ["WP", "WIKT", "APPENDIX"]:
          return value
        if not re.search("^%s$" % either_quote_string_re, value):
          return None
        stripped_val = value[1:-1]
        if stripped_val == "wp":
          return "WP"
        if stripped_val == "wikt":
          return "WIKT"
        if stripped_val == "app":
          return "APPENDIX"
        linemsg("WARNING: Unrecognized value for glossary_type '%s'" % value)
        return None
      def process_combined_glossary(value):
        gltype = None
        retval = None
        if value == "nil":
          gltype = "APPENDIX"
          retval = True
        elif value in ["WP", "WIKT", "APPENDIX"]:
          gltype = value
          retval = True
        else:
          if not re.search("^%s$" % either_quote_string_re, value):
            return None
          stripped_val = value[1:-1]
          if stripped_val.startswith("w:"):
            gltype = "WP"
            retval = stripped_val[2:]
          elif stripped_val.startswith("wikt:"):
            gltype = "WIKT"
            retval = stripped_val[5:]
          else:
            gltype = "APPENDIX"
            retval = stripped_val
          glossary_type[0] = gltype
          return retval
      def process_wikidata(value):
        if re.search("^[0-9]+$", value):
          return value
        if not re.search("^%s$" % either_quote_string_re, value):
          linemsg("WARNING: Unrecognized value for wikidata '%s'" % value)
          return None
        stripped_val = value[1:-1]
        if not re.search("^Q[0-9]+$", stripped_val):
          linemsg("WARNING: Unrecognized value for wikidata '%s'" % value)
          return None
        return stripped_val[1:]
      def process_display(value):
        if not re.search("^%s$" % either_quote_string_re, value):
          linemsg("WARNING: Unrecognized value for display '%s'" % value)
          return None
        return value[1:-1]

      def process_key_value(key, dest, process_value):
        m = re.search("^%s = (.*)$" % key, line)
        if m:
          value = m.group(1)
          processed_value = process_value(value)
          if process_value is None:
            new_lines.append(origline)
          elif process_value is not False:
            if dest:
              linemsg("WARNING: Saw key '%s' twice for tag '%s': %s" % (key, tag, origline.strip()))
              new_lines.append(origline)
            else:
              dest[0] = processed_value
              dest[1] = comment
          return True
        return False

      def process_numbered_value(dest, process_value):
        processed_value = process_value(line)
        if process_value is None:
          new_lines.append(origline)
        elif process_value is not False:
          if dest:
            linemsg("WARNING: Saw key '%s' twice for tag '%s': %s" % (key, tag, origline.strip()))
            new_lines.append(origline)
          else:
            dest[0] = processed_value
            dest[1] = comment
        return True

      if (not process_key_value("tag_type", tag_type, process_tag_type)
        and not process_key_value("glossary", glossary, process_glossary)
        and not process_key_value("glossary_type", glossary_type, process_glossary_type)
        and not process_key_value("wikidata", wikidata, process_wikidata)
        and not process_key_value("display", display, process_display)
        and not process_key_value("shortcuts", shortcuts, process_shortcuts)
      ):
        m = re.search("^(.+?) = (.*)$", line)
        if m:
          misc_keys.append((m.group(1), m.group(2), comment))
        elif not line.strip():
          new_lines.append(origline)
        else:
          offset = lineno - tag_lineno
          if offset == 1:
            process_numbered_value(tag_type, process_tag_type)
          elif offset == 2:
            process_numbered_value(glossary, process_combined_glossary)
          elif offset == 3:
            process_numbered_value(wikidata, process_wikidata)
          elif offset == 4:
            process_numbered_value(shortcuts, process_shortcuts)
          else:
            linemsg("WARNING: Unrecognized numbered line, offset %s > 4" % offset)
            new_lines.append(origline)

    else:
      new_lines.append(line)

  text = "\n".join(new_lines)

  return text, "clean data in form-of module"

parser = blib.create_argparser("Clean form-of data modules", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

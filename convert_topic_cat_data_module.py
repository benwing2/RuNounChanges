#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  notes = []

  new_lines = []
  lines = text.split("\n")
  label = None

  either_quote_string_re_no_parens = '".*?"|' + "'.*?'"
  either_quote_string_re = "(%s)" % either_quote_string_re_no_parens

  for lineind, line in enumerate(lines):
    lineno = lineind + 1
    origline = line
    def linemsg(txt):
      pagemsg("Line %s: %s: %s" % (lineno, txt, origline.strip()))
    if line.startswith("labels["):
      if label:
        errandpagemsg("WARNING: Saw nested labels on line %s, can't handle file" % lineno)
        return
      label_lineno = lineno
      typ = None
      keys_and_other_lines = []
      m = re.search(r"^labels\[%s\] *= *\{([ \t]*--.*)?$" % (either_quote_string_re), line.rstrip())
      if not m:
        linemsg("WARNING: Unable to parse tags start line")
      else:
        label = m.group(1)[1:-1]
      new_lines.append(line)
    elif line.strip().startswith("}") and label:
      new_keys_and_other_lines = [x for x in keys_and_other_lines]

      while True:
        value_by_key = {}
        for keyind, key_or_other_line in enumerate(keys_and_other_lines):
          if type(key_or_other_line) is not str:
            key, value, comment = key_or_other_line
            value_by_key[key] = (keyind, value, comment)

        def output_keys():
          for keyind, key_or_other_line in enumerate(keys_and_other_lines):
            if type(key_or_other_line) is str:
              new_lines.append(key_or_other_line)
            else:
              key, value, comment = key_or_other_line
              new_lines.append("\t%s = %s,%s" % (key, value, comment or ""))

        type_ind = None
        type_comment = ""
        if "type" in value_by_key:
          type_ind, typ, type_comment = value_by_key["type"]
        if "parents" in value_by_key:
          parents_ind, parents, parents_comment = value_by_key["parents"]
          def process_parents(value):
            nonlocal typ
            if value == "nil":
              return False
            m = re.search(r"^\{(.*)\}$", value)
            if m:
              inside = m.group(1).strip()
              if not inside:
                linemsg("WARNING: Empty parents line")
                return None
              if inside.endswith(","):
                inside = inside[:-1].strip()
              split_parents = re.split(r"(\{[^{}]*\}|%s)" % either_quote_string_re_no_parens, m.group(1).strip())
              parents = []
              for i, split_parent in enumerate(split_parents):
                if i % 2 == 1:
                  if split_parent.startswith("{"):
                    parents.append(split_parent)
                  else:
                    parent = split_parent[1:-1]
                    if parent == "list of sets":
                      if typ:
                        linemsg("WARNING: For label '%s', saw explicit 'type=%s' as well as 'list of sets' in parents %s"
                          % (label, typ, value))
                        return None
                      typ = "set"
                    elif parent == "list of topics":
                      if typ:
                        linemsg("WARNING: For label '%s', saw explicit 'type=%s' as well as 'list of topics' in parents %s"
                          % (label, typ, value))
                        return None
                      typ = "topic"
                    else:
                      parents.append('"%s"' % parent)
                elif (i == 0 and split_parent.strip()
                      or i == len(split_parents) - 1 and split_parent.strip() not in ["", ","]
                      or i > 0 and i < len(split_parents) - 1 and split_parent.strip() != ","):
                  linemsg("WARNING: Junk '%s' between parents, index %s" % (split_parent, i))
                  return None
              return parents
            linemsg("WARNING: Unable to parse parents line")
            return None
          parents = process_parents(parents)
          if parents is None:
            output_keys()
            break
          new_keys_and_other_lines[parents_ind] = ("parents", "{%s}" % ", ".join(parents), parents_comment)
        typ = typ or "topic"
        if "description" in value_by_key:
          desc_ind, desc, desc_comment = value_by_key["description"]
          desc = desc.strip()
          m = re.search("^" + either_quote_string_re + "$", desc)
          if not m:
            linemsg("WARNING: For label '%s', couldn't parse description '%s'" % (label, desc))
            output_keys()
            break
          desc = desc[1:-1]
          if desc.startswith("default-set"):
            if typ == "topic":
              linemsg("WARNING: For label '%s', saw 'default-set' but no 'list of sets' in parents, assuming set"
                % label)
              typ = "set"
            desc = re.sub("default-set", "default", desc)
            new_keys_and_other_lines[desc_ind] = ("description", '"%s"' % desc, desc_comment)

        new_type_tuple = ("type", '"%s"' % typ, type_comment)
        if type_ind is not None:
          new_keys_and_other_lines[type_ind] = new_type_tuple
        else:
          new_keys_and_other_lines = [new_type_tuple] + new_keys_and_other_lines

        keys_and_other_lines = new_keys_and_other_lines
        output_keys()
        break

      label = None
      new_lines.append("}")

    elif label:
      line = line.strip()
      comment = None
      m = re.search(r"^(.*?)([ \t]*--.*)$", line)
      if m:
        line, comment = m.groups()
      if line.endswith(","):
        line = line[:-1]

      m = re.search("^(.+?) = (.*)$", line)
      if m:
        keys_and_other_lines.append((m.group(1), m.group(2), comment))
      else:
        keys_and_other_lines.append(origline)

    else:
      new_lines.append(line)

  text = "\n".join(new_lines)

  return text, "convert data in 'topic cat' module"

parser = blib.create_argparser("Convert 'topic cat' data modules to new structure",
                               include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

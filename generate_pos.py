#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re

class Peeker:
  __slots__ = ['lineiter', 'next_lines']
  def __init__(self, lineiter):
    self.lineiter = lineiter
    self.next_lines = []
    self.lineno = 0

  def peek_next_line(self, n):
    while len(self.next_lines) < n + 1:
      try:
        self.next_lines.append(next(self.lineiter))
      except StopIteration:
        # print("peek_next_line(%s): return None" % n)
        return None
    # print("peek_next_line(%s): return %s" % (n, self.next_lines[n]))
    return self.next_lines[n]

  def get_next_line(self):
    if len(self.next_lines) > 0:
      retval = self.next_lines[0]
      del self.next_lines[0]
      # print("get_next_line(): return cached %s" % retval)
      self.lineno += 1
      return retval
    try:
      retval = next(self.lineiter)
      # print("get_next_line(): return new %s" % retval)
      self.lineno += 1
      return retval
    except StopIteration:
      # print("get_next_line(): return None")
      return None

def generate_multiline_defn(peeker):
  defnlines = []
  lineind = 0
  nextline = peeker.peek_next_line(0)
  if nextline != None and not nextline.strip():
    lineind = 1
    nextline = peeker.peek_next_line(1)
  nextline = peeker.peek_next_line(lineind)
  if nextline != None and re.search(r"^\[(def|defn|definition)\]$", nextline.strip()):
    for i in range(lineind + 1):
      peeker.get_next_line()
    if not (peeker.peek_next_line(0) or "").strip():
      peeker.get_next_line()
    while True:
      line = peeker.get_next_line()
      if not (line or "").strip():
        break
      defnlines.append(line.strip() + "\n")
    return "".join(defnlines)
  return None

def generate_dimaugpej(defn, template, pos, lang):
  parts = re.split(":", defn)
  assert len(parts) in [2, 3]
  defnline = "{{%s|%s|%s%s}}" % (template, lang,
    re.sub(r", *", ", ", parts[1]),
    "" if pos == "noun" else "|pos=%ss" % pos)
  if len(parts) == 3:
    defnline = "%s: %s" % (defnline, re.sub(r", *", ", ", parts[2]))
  return defnline

known_labels = {
  "or": "or",
  "also": ["also", "_"],
  "f": "figurative",
  "fig": "figurative",
  "a": "archaic",
  "arch": "archaic",
  "d": "dated",
  "dat": "dated",
  "p": "poetic",
  "poet": "poetic",
  "h": "historical",
  "hist": "historical",
  "n": "nonstandard",
  "lc": ["low", "_", "colloquial"],
  "v": "vernacular",
  "inf": "informal",
  "c": "colloquial",
  "col": "colloquial",
  "l": "literary",
  "lit": "literary",
  "tr": "transitive",
  "in": "intransitive",
  "intr": "intransitive",
  "io": "imperfective only",
  "po": "perfective only",
  "im": "impersonal",
  "imp": "impersonal",
  "pej": "pejorative",
  "vul": "vulgar",
  "reg": "regional",
  "dia": "dialectal",
  "joc": "jocular",
  "an": "animate",
  "inan": "inanimate",
  "refl": "reflexive",
  "rel": "relational",
}

def parse_off_labels(defn):
  labels = []
  while True:
    if defn.startswith("+"):
      labels.append("relational")
      defn = re.sub(r"^\+", "", defn)
    elif defn.startswith("#"):
      labels.append("figurative")
      defn = re.sub(r"^#", "", defn)
    elif defn.startswith("!"):
      labels.append("colloquial")
      defn = re.sub(r"^!", "", defn)
    else:
      m = re.search(r"^\((.*?)\)((?! ).*)$", defn)
      if m:
        shortlab = m.group(1)
        if shortlab in known_labels:
          longlab = known_labels[shortlab]
          if type(longlab) is list:
            labels.extend(longlab)
          else:
            labels.append(longlab)
        else:
          labels.append(shortlab)
        defn = m.group(2)
      else:
        defn = defn.replace(r"\(", "(").replace(r"\)", ")")
        break
  return defn, labels

def generate_defn(defns, pos, lang):
  defnlines = []
  addlprops = {}

  ever_saw_refl = False
  # the following regex uses a negative lookbehind so we split on a semicolon
  # but not on a backslashed semicolon, which we then replace with a regular
  # semicolon in the next line
  for defn in re.split(r"(?<![\\]);", defns):
    saw_refl = False
    saw_actual_defn = False
    defn = defn.replace(r"\;", ";")
    if defn == "-":
      defnlines.append("# {{rfdef|%s}}\n" % lang)
    elif defn.startswith("ux:"):
      defnlines.append("#: {{uxi|%s|%s}}\n" % (lang,
        re.sub("^ux:", "", re.sub(r", *", ", ", defn))))
    elif defn.startswith("uxx:"):
      defnlines.append("#: {{ux|%s|%s}}\n" % (lang,
        re.sub("^uxx:", "", re.sub(r", *", ", ", defn))))
    elif defn.startswith("quote:"):
      defnlines.append("#: {{quote|%s|%s}}\n" % (lang,
        re.sub("^quote:", "", re.sub(r", *", ", ", defn))))
    elif re.search("^(syn|ant|pf|impf):", defn):
      m = re.search("^(.*?):(.*)$", defn)
      tempname, defn = m.groups()
      defn, labels = parse_off_labels(defn)
      defntext = "#: {{%s|%s|%s}}" % (tempname, lang, re.sub(r", *", "|", defn))
      if labels:
        defntext += " {{i|%s}}" % ", ".join(labels)
      defnlines.append(defntext + "\n")
    else:
      saw_actual_defn = True
      prefix = ""
      defn, labels = parse_off_labels(defn)
      if labels:
        if lang == "bg" and labels[0] == "reflexive":
          prefix = "{{bg-reflexive%s}} " % "|".join([""] + labels[1:])
          saw_refl = True
        elif lang == "bg" and labels[0] == "reflsi":
          prefix = "{{bg-reflexive-си%s}} " % "|".join([""] + labels[1:])
          saw_refl = True
        else:
          prefix = "{{lb|%s|%s}} " % (lang, "|".join(labels))
      if defn.startswith("altof:"):
        defnline = "{{alt form|%s|%s}}" % (lang,
            re.sub("^altof:", "", defn))
      elif defn.startswith("oui:"):
        oui = re.sub("^oui:", "", defn)
        if "oui" in addlprops:
          addlprops["oui"].append(oui)
        else:
          addlprops["oui"] = [oui]
        defnline = "{{only used in|%s|%s}}" % (lang, oui)
      elif defn.startswith("dim:"):
        defnline = generate_dimaugpej(defn, "diminutive of", pos, lang)
      elif defn.startswith("end:"):
        defnline = generate_dimaugpej(defn, "endearing form of", pos, lang)
      elif defn.startswith("enddim:"):
        defnline = generate_dimaugpej(defn, "endearing diminutive of", pos, lang)
      elif defn.startswith("aug:"):
        defnline = generate_dimaugpej(defn, "augmentative of|nocap=1", pos, lang)
      elif defn.startswith("pej:"):
        defnline = generate_dimaugpej(defn, "pejorative of", pos, lang)
      elif defn.startswith("gn:"):
        gnparts = re.split(":", defn)
        assert len(gnparts) in [2]
        defnline = "{{given name|%s|%s}}" % (lang, gnparts[1])
      else:
        defnline = re.sub(r", *", ", ", defn)
      defnline = re.sub(r"\(\((.*?)\)\)", r"{{m|%s|\1}}" % lang, defnline)
      defnline = re.sub(r"g<<(.*?)>>", r"{{gloss|\1}}", defnline)
      defnline = re.sub(r"<<(.*?)>>", r"{{i|\1}}", defnline)
      defnline = re.sub(r"g\((.*?)\)", r"{{glossary|\1}}", defnline)
      defnlines.append("# %s%s\n" % (prefix, defnline))
    if saw_refl:
      ever_saw_refl = True
    elif ever_saw_refl and saw_actual_defn:
      return None, "Saw non-reflexive definition '%s' after reflexive definition" % defn

  return "".join(defnlines), addlprops

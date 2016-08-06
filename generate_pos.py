#!/usr/bin/python

import re

class Peeker:
  __slots__ = ['lineiter', 'next_lines']
  def __init__(self, lineiter):
    self.lineiter = lineiter
    self.next_lines = []

  def peek_next_line(self, n):
    while len(self.next_lines) < n + 1:
      try:
        self.next_lines.append(next(self.lineiter))
      except StopIteration:
        # print "peek_next_line(%s): return None" % n
        return None
    # print "peek_next_line(%s): return %s" % (n, self.next_lines[n])
    return self.next_lines[n]

  def get_next_line(self):
    if len(self.next_lines) > 0:
      retval = self.next_lines[0]
      del self.next_lines[0]
      # print "get_next_line(): return cached %s" % retval
      return retval
    try:
      retval = next(self.lineiter)
      # print "get_next_line(): return new %s" % retval
      return retval
    except StopIteration:
      # print "get_next_line(): return None"
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
    for i in xrange(lineind + 1):
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

def generate_defn(defns):
  defnlines = []

  # the following regex uses a negative lookbehind so we split on a semicolon
  # but not on a backslashed semicolon, which we then replace with a regular
  # semicolon in the next line
  for defn in re.split(r"(?<![\\]);", defns):
    defn = defn.replace(r"\;", ";")
    if defn == "-":
      defnlines.append("# {{rfdef|lang=ru}}\n")
    elif defn.startswith("ux:"):
      defnlines.append("#: {{ru-ux|%s|inline=y}}\n" % (
        re.sub("^ux:", "", re.sub(r", *", ", ", defn))))
    else:
      labels = []
      prefix = ""
      while True:
        if defn.startswith("+"):
          labels.append("attributive")
          defn = re.sub(r"^\+", "", defn)
        elif defn.startswith("#"):
          labels.append("figurative")
          defn = re.sub(r"^#", "", defn)
        elif defn.startswith("(or)"):
          labels.append("or")
          defn = re.sub(r"^\(or\)", "", defn)
        elif defn.startswith("(also)"):
          labels.extend(["also", "_"])
          defn = re.sub(r"^\(also\)", "", defn)
        elif defn.startswith("(f)"):
          labels.append("figurative")
          defn = re.sub(r"^\(f\)", "", defn)
        elif defn.startswith("(d)"):
          labels.append("dated")
          defn = re.sub(r"^\(d\)", "", defn)
        elif defn.startswith("(p)"):
          labels.append("poetic")
          defn = re.sub(r"^\(p\)", "", defn)
        elif defn.startswith("(h)"):
          labels.append("historical")
          defn = re.sub(r"^\(h\)", "", defn)
        elif defn.startswith("(n)"):
          labels.append("nonstandard")
          defn = re.sub(r"^\(n\)", "", defn)
        elif defn.startswith("(lc)"):
          labels.extend(["low", "_", "colloquial"])
          defn = re.sub(r"^\(lc\)", "", defn)
        elif defn.startswith("(v)"):
          labels.append("vernacular")
          defn = re.sub(r"^\(v\)", "", defn)
        elif defn.startswith("!"):
          labels.append("colloquial")
          defn = re.sub(r"^!", "", defn)
        elif defn.startswith("(c)"):
          labels.append("colloquial")
          defn = re.sub(r"^\(c\)", "", defn)
        elif defn.startswith("(l)"):
          labels.append("literary")
          defn = re.sub(r"^\(l\)", "", defn)
        elif defn.startswith("(tr)"):
          labels.append("transitive")
          defn = re.sub(r"^\(tr\)", "", defn)
        elif defn.startswith("(in)"):
          labels.append("intransitive")
          defn = re.sub(r"^\(in\)", "", defn)
        elif defn.startswith("(io)"):
          labels.append("imperfective only")
          defn = re.sub(r"^\(io\)", "", defn)
        elif defn.startswith("(po)"):
          labels.append("perfective only")
          defn = re.sub(r"^\(po\)", "", defn)
        elif defn.startswith("(im)"):
          labels.append("impersonal")
          defn = re.sub(r"^\(im\)", "", defn)
        elif defn.startswith("(pej)"):
          labels.append("pejorative")
          defn = re.sub(r"^\(pej\)", "", defn)
        elif defn.startswith("(vul)"):
          labels.append("vulgar")
          defn = re.sub(r"^\(vul\)", "", defn)
        elif defn.startswith("(reg)"):
          labels.append("regional")
          defn = re.sub(r"^\(reg\)", "", defn)
        elif defn.startswith("(joc)"):
          labels.append("jocular")
          defn = re.sub(r"^\(joc\)", "", defn)
        else:
          break
      if labels:
        prefix = "{{lb|ru|%s}} " % "|".join(labels)
      if defn.startswith("altof:"):
        defnline = "{{alternative form of|lang=ru|%s}}" % (
            re.sub("^altof:", "", defn))
      elif defn.startswith("dim:"):
        dimparts = re.split(":", defn)
        assert len(dimparts) in [2, 3]
        defnline = "{{diminutive of|lang=ru|%s}}" % dimparts[1]
        if len(dimparts) == 3:
          defnline = "%s: %s" % (defnline, dimparts[2])
      elif defn.startswith("gn:"):
        gnparts = re.split(":", defn)
        assert len(gnparts) in [2]
        defnline = "{{given name|lang=ru|%s}}" % gnparts[1]
      else:
        defnline = re.sub(r", *", ", ", defn)
      defnlines.append("# %s%s\n" % (prefix, defnline))
  return "".join(defnlines)

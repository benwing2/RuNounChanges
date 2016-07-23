#!/usr/bin/python

import re

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
        re.sub("^ux:", "", defn)))
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
        defnline = defn.replace(",", ", ")
      defnlines.append("# %s%s\n" % (prefix, defnline))
  return "".join(defnlines)

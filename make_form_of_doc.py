#!/usr/bin/env python
# -*- coding: utf-8 -*-

from blib import getparam, rmparam, msg, errmsg, site
import pywikibot, re, sys, codecs, argparse

parser = argparse.ArgumentParser(description="Generate form-of documentation pages.")
parser.add_argument('--direcfile', help="File containing directives.")
parser.add_argument('--save', help="Save pages.", action="store_true")
args = parser.parse_args()

lines = codecs.open(args.direcfile, "r", "utf-8")
in_multiline = False

nextpage = 0
def save_template_doc(tempname, doc, save):
  global nextpage
  msg("For [[Template:%s]]:" % tempname)
  msg("------- begin text --------")
  msg(doc.rstrip('\n'))
  msg("------- end text --------")
  comment = "Update form-of template documentation"
  nextpage += 1
  if save:
    page = pywikibot.Page(site, "Template:%s/documentation" % tempname)
    msg("Page %s %s: Saving with comment = %s" % (nextpage, tempname, comment))
    page.text = doc
    page.save(comment=comment)
  else:
    msg("Page %s %s: Would save with comment = %s" % (nextpage, tempname, comment))

while True:
  try:
    line = next(lines)
  except StopIteration:
    break
  if in_multiline and re.search("^-+ end text -+$", line):
    in_multiline = False
    save_template_doc(tempname, "".join(templines), args.save)
  elif in_multiline:
    if line.rstrip('\n').endswith(':'):
      errmsg("WARNING: Possible missing ----- end text -----: %s" % line.rstrip('\n'))
    templines.append(line)
  else:
    line = line.rstrip('\n')
    if line.endswith(':'):
      tempname = line[:-1]
      in_multiline = True
      templines = []
    else:
      m = re.search('^(.*?):(.*)$', line)
      assert m
      tempname = m.group(1)
      tempparams = m.group(2).split(",")
      params = {}
      for tp in tempparams:
        if tp in ["infldoc", "fulldoc", "withcap", "withfrom", "grammar",
            "decl", "conj"]:
          params[tp] = True
        else:
          m = re.search("^(cat|lang|exlang|form|sgdesc|pldesc|shortcut)=(.*)", tp)
          if m:
            params[m.group(1)] = m.group(2)
          else:
            assert False, "Unrecognized parameter %s" % tp
      if "infldoc" in params:
        doctempname = "form of/infldoc"
      elif "fulldoc" in params:
        doctempname = "form of/fulldoc"
      else:
        assert False, "Neither infldoc nor fulldoc specified"
      paramtext = []
      if "pldesc" in params:
        paramtext.append("|pldesc=%s" % params["pldesc"])
      if "sgdesc" in params:
        paramtext.append("|sgdesc=%s" % params["sgdesc"])
      if "from" in params:
        paramtext.append("|from=%s" % params["from"])
      if "withcap" in params:
        paramtext.append("|withcap=1")
      if "withfrom" in params:
        paramtext.append("|withfrom=1")
      if "cat" in params:
        for index, cat in enumerate(params["cat"].split(";")):
          paramtext.append("|cat%s=%s" % ("" if index == 0 else str(index + 1), cat))
      if "shortcut" in params:
        for index, cat in enumerate(params["shortcut"].split(";")):
          paramtext.append("|shortcut%s=%s" % ("" if index == 0 else str(index + 1), cat))
      if "lang" in params:
        paramtext.append("|lang=%s" % params["lang"])
      if "exlang" in params:
        for index, cat in enumerate(params["exlang"].split(";")):
          paramtext.append("|exlang%s=%s" % ("" if index == 0 else str(index + 1), cat))
      doctemp = "{{%s%s}}" % (doctempname, "".join(paramtext))
      doclines = []
      doclines.append(doctemp)
      doclines.append("<includeonly>")
      doclines.append("[[Category:Form-of templates]]")
      if "conj" in params:
        doclines.append("[[Category:Conjugation form-of templates]]")
      if "decl" in params:
        doclines.append("[[Category:Declension form-of templates]]")
      if "grammar" in params:
        doclines.append("[[Category:Grammar form-of templates]]")
      doclines.append("</includeonly>")
      save_template_doc(tempname, "\n".join(doclines) + "\n", args.save)

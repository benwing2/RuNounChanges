#!/usr/bin/env python
#coding: utf-8

#    add_ru_etym.py is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

import pywikibot, re, sys, codecs, argparse, time
import blib
from blib import site, msg, errmsg, group_notes, iter_items
import rulib

# Split text on a separator, but not if separator is preceded by
# a backslash, and remove such backslashes
def do_split(sep, text):
  elems = re.split(r"(?<![\\])%s" % sep, text)
  return [re.sub(r"\\(%s)" % sep, r"\1", elem) for elem in elems]

def process_line(index, line, save, verbose):
  def error(text):
    errmsg("ERROR: Processing line: %s" % line)
    errmsg("ERROR: %s" % text)
    assert False

  def check_stress(word):
    word = re.sub(r"|.*", "", word)
    if word.startswith("-") or word.endswith("-"):
      # Allow unstressed prefix (e.g. разо-) and unstressed suffix (e.g. -овать)
      return
    if rulib.needs_accents(word, split_dash=True):
      error("Word %s missing an accent" % word)

  # Skip lines consisting entirely of comments
  if line.startswith("#"):
    return
  els = do_split(r"\s+", line)

  # Replace _ with space and \u
  els = [el.replace("_", " ").replace(r"\u", "_") for el in els]
  if len(els) != 2:
    error("Expected two fields, saw %s" % len(els))
  term = rulib.remove_accents(els[0])
  etym = els[1]

  pagetitle = term

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  # Handle etymology
  adjformtext = ""
  if etym == "?":
    error("Etymology consists of bare question mark")
  elif etym == "-":
    etymtext = "===Etymology===\n{{rfe|lang=ru}}\n\n"
  elif etym == "--":
    etymtext = ""
  elif re.search(r"^(part|adj|partadj)([fnp]):", etym):
    m = re.search(r"^(part|adj|partadj)([fnp]):(.*)", etym)
    forms = {"f":["nom|f|s"], "n":["nom|n|s", "acc|n|s"], "p":["nom|p", "in|acc|p"]}
    infleclines = ["# {{inflection of|lang=ru|%s||%s}}" %
        (m.group(3), form) for form in forms[m.group(2)]]
    if m.group(1) in ["adj", "partadj"]:
      adjinfltext = """===Adjective===
{{head|ru|adjective form|head=%s%s}}

%s\n\n""" % (headterm, trtext, "\n".join(infleclines))
    else:
      adjinfltext = ""
    if m.group(1) in ["part", "partadj"]:
      partinfltext = """===Participle===
{{head|ru|participle form|head=%s%s}}

%s\n\n""" % (headterm, trtext, "\n".join(infleclines))
    else:
      partinfltext = ""
    adjformtext = partinfltext + adjinfltext
    etymtext = ""
  else:
    if etym.startswith("acr:"):
      _, fullexpr, meaning = do_split(":", etym)
      etymtext = "{{ru-etym acronym of|%s||%s}}." % (fullexpr, meaning)
    elif etym.startswith("deverb:"):
      _, sourceterm = do_split(":", etym)
      etymtext = "Deverbal from {{m|ru|%s}}." % sourceterm
    elif etym.startswith("back:"):
      _, sourceterm = do_split(":", etym)
      etymtext = "{{back-form|lang=ru|%s}}" % sourceterm
    elif etym.startswith("raw:"):
      etymtext = re.sub(", *", ", ", re.sub("^raw:", "", etym))
    elif ":" in etym and "+" not in etym:
      if etym.startswith("?"):
        prefix = "Perhaps borrowed from "
        etym = re.sub(r"^\?", "", etym)
      elif etym.startswith("<<"):
        prefix = "Ultimately borrowed from "
        etym = re.sub(r"^<<", "", etym)
      else:
        prefix = "Borrowed from "
      m = re.search(r"^([a-zA-Z.-]+):(.*)", etym)
      if not m:
        error("Bad etymology form: %s" % etym)
      etymtext = "%s{{bor|ru|%s|%s}}." % (prefix, m.group(1), m.group(2))
    else:
      prefix = ""
      suffix = ""
      if etym.startswith("?"):
        prefix = "Perhaps from "
        suffix = "."
        etym = re.sub(r"^\?", "", etym)
      elif etym.startswith("<<"):
        prefix = "Ultimately from "
        suffix = "."
        etym = re.sub(r"^<<", "", etym)
      m = re.search(r"^([a-zA-Z.-]+):(.*)", etym)
      if m:
        langtext = "|lang1=%s" % m.group(1)
        etym = m.group(2)
      else:
        langtext = ""
      etymtext = "%s{{affix|ru|%s%s}}%s" % (prefix,
          "|".join(do_split(r"\+", re.sub(", *", ", ", etym))), langtext,
          suffix)
    etymtext = "===Etymology===\n%s\n\n" % etymtext

  if not etymtext:
    pagemsg("No etymology text, skipping")

  # Load page
  page = pywikibot.Page(site, pagetitle)

  if not blib.try_repeatedly(lambda: page.exists(), pagemsg,
      "check page existence"):
    pagemsg("Page doesn't exist, can't add etymology")
    return
    
  pagemsg("Adding etymology")
  notes = []
  pagetext = unicode(page.text)

  # Split into sections
  splitsections = re.split("(^==[^=\n]+==\n)", pagetext, 0, re.M)
  # Extract off pagehead and recombine section headers with following text
  pagehead = splitsections[0]
  sections = []
  for i in xrange(1, len(splitsections)):
    if (i % 2) == 1:
      sections.append("")
    sections[-1] += splitsections[i]

  # Go through each section in turn, looking for existing Russian section
  for i in xrange(len(sections)):
    m = re.match("^==([^=\n]+)==$", sections[i], re.M)
    if not m:
      pagemsg("Can't find language name in text: [[%s]]" % (sections[i]))
    elif m.group(1) == "Russian":
      if "==Etymology==" in sections[i] or "==Etymology 1==" in sections[i]:
        pagemsg("WARNING: Already found etymology, skipping")
        return

      subsections = re.split("(^===+[^=\n]+===+\n)", sections[i], 0, re.M)
          
      insert_before = 1
      if "===Alternative forms===" in subsections[insert_before]:
        insert_before += 2

      subsections[insert_before] = etymtext + subsections[insert_before]

      sections[i] = "".join(subsections)
      newtext = "".join(sections)
      notes.append("add Etymology section to Russian lemma")
      break
  else:
    pagemsg("WARNING: Can't find Russian section, skipping")
    return

  if newtext != pagetext:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (pagetext, newtext))
    assert notes
    comment = "; ".join(group_notes(notes))
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = newtext
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

if __name__ == "__main__":
  parser = blib.create_argparser("Fix params in RQ:Wodehouse Offing templates")
  parser.add_argument('--direcfile', help="File containing directives.")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  lines = codecs.open(args.direcfile, "r", "utf-8")
  for i, line in iter_items(lines, start, end):
    line = line.strip()
    process_line(i, line, args.save, args.verbose)

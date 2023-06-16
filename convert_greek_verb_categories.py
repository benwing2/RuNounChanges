#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site, tname

outtext = []

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  def replace_links(description):
    def replace_raw_link(m):
      linktext = m.group(1)
      mm = re.search(r":Category:Greek verbs conjugating like '(.*)'\|'''like'''$", linktext)
      if mm:
        return "like(%s)" % mm.group(1)
      if ":" in linktext:
        return m.group(0)
      if "|" in linktext:
        parts = linktext.split("|")
        if len(parts) != 2:
          pagemsg("WARNING: More than two parts in linktext: %s" % linktext)
          return m.group(0)
        link, display = parts
        link = re.sub("#Greek$", "", link)
        if display.replace("'", "") == link:
          return "<<%s>>" % display
        retval = "<<%s|%s>>" % (link, display)
        pagemsg("WARNING: Returning two-part link %s" % retval)
        return retval
      return "<<%s>>" % linktext
    description = re.sub(r"\[\[(.*?)\]\]", replace_raw_link, description)
    def replace_like(m):
      link, display = m.groups()
      if display.replace("'", "") == link:
        return "like<<%s>>" % display
      pagemsg("WARNING: Can't collapse like(...) expression: %s" % m.group(0))
      return m.group(0)
    description = re.sub(r"like\((.*?)\) <<(.*?)>>", replace_like, description)
    return description

  if "verb conjugation group" in pagename:
    label = re.sub("^Category:Greek ", "", pagename)
    breadcrumb = re.sub("^.*'(.*)'.*$", r"\1", label)
    lines = text.split("\n")
    breadcrumbs = lines[0]
    if not breadcrumbs.startswith("<small>>>"):
      pagemsg("WARNING: Breadcrumb line doesn't look right: %s" % breadcrumbs)
      return
    breadcrumbs = re.sub("^<small>>>", "", re.sub("</small><br>$", "", breadcrumbs)).split(" >> ")
    breadcrumbs = [x.strip() for x in breadcrumbs]
    last_breadcrumb = blib.remove_links(breadcrumbs[-1]).replace("'", "")
    if last_breadcrumb == "Vowel ending stems":
      parent = "vowel-stem verbs"
    else:
      last_breadcrumb = re.sub("<sup>(.*?)</sup>", r"(\1)", last_breadcrumb)
      parent = "consonant-stem verbs in -%s-" % last_breadcrumb
    category = lines[-1]
    m = re.search(r"^\[\[Category:(.*)\|(.*?)\]\]$", category)
    if not m:
      pagemsg("WARNING: Last line doesn't look like a category line: %s" % category)
      return
    parent2, conj_group_sort = m.groups()
    m = re.search(r"^Greek (.*) conjugation groups$", parent2)
    if not m:
      pagemsg("WARNING: Category doesn't look like a conjugation group: %s" % parent2)
      return
    conj_group = m.group(1)
    textlines = lines[1:-1]
    if not textlines[-1]:
      textlines = textlines[0:-1]
    description = '"' + '\\n" ..\n\t"'.join(textlines) + '"'
    description = replace_links(description)
    cattext = """
groups["%s"] = {"%s", "%s", "%s",
\t%s
}

""" % (breadcrumb, conj_group, conj_group_sort, parent, description)
    pagemsg("Appended <%s>" % cattext)
    outtext.append(cattext)
  elif "verbs conjugating like" in pagename:
    m = re.search("^Category:Greek verbs conjugating like '(.*?)'$", pagename)
    if not m:
      pagemsg("WARNING: Can't parse 'verbs conjugating like' pagename")
      return
    likeverb = m.group(1)
    lines = text.split("\n")
    breadcrumbs = lines[0]
    if not breadcrumbs.startswith(":: >> "):
      pagemsg("WARNING: Breadcrumb line doesn't look right: %s" % breadcrumbs)
      return
    breadcrumbs = re.sub("^:: >> ", "", breadcrumbs).split(" >> ")
    breadcrumbs = [x.strip() for x in breadcrumbs]
    parent_group = breadcrumbs[0]
    if len(breadcrumbs) == 1:
      breadcrumb_desc = None
    elif len(breadcrumbs) == 2:
      breadcrumb_desc = re.sub(", like.*", "", breadcrumbs[1])
    else:
      pagemsg("WARNING: Too many breadcrumbs for 'verbs conjugating like' page: %s" % breadcrumbs)
      return
    m = re.search(r"^\[\[:Category:Greek verb conjugation group '(.*)'\]\]$", parent_group)
    if not m:
      pagemsg("WARNING: Can't parse 'verbs conjugating like' parent-group breadcrumb: %s" % parent_group)
      return
    parent_group = m.group(1)
    if len(lines) < 3:
      pagemsg("WARNING: Not enough lines for 'verbs conjugating like' page: <<%s>>" % text)
      return
    if not lines[-1].startswith("[[Category:") or not lines[-2].startswith("[[Category:"):
      pagemsg("WARNING: Last two lines aren't category references in 'verbs conjugating like' page: <<%s>>" % text)
      return
    m = re.search(r"^\[\[Category:Greek (.*?) conjugation verbs", lines[-2])
    if not m:
      m = re.search(r"^\[\[Category:Greek (.*?) conjugation verbs", lines[-1])
    if not m:
      pagemsg("WARNING: Can't parse conjugation number out of last two category lines: <%s>, <%s>" % (
        lines[-2], lines[-1]))
      return
    conj = m.group(1)
    desctext = []
    if len(lines) > 3:
      desctext = lines[1:-2]
      desctext = [x for x in desctext if x]
    if not desctext:
      description = None
    else:
      description = '"' + '\\n" ..\n\t"'.join(desctext) + '"'
      description = replace_links(description)
    if not breadcrumb_desc and not description:
      cattext = 'like_verbs["%s"] = {"%s", "%s"}' % (likeverb, conj, parent_group)
    elif not description:
      cattext = 'like_verbs["%s"] = {"%s", "%s", "%s"}' % (likeverb, conj, parent_group, breadcrumb_desc)
    else:
      breadcrumb_desc = '"' + breadcrumb_desc + '"' if breadcrumb_desc else "nil"
      cattext = 'like_verbs["%s"] = {"%s", "%s", %s,\n\t%s\n}' % (likeverb, conj, parent_group, breadcrumb_desc, description)
    cattext += "\n"
    pagemsg("Appended <%s>" % cattext)
    outtext.append(cattext)
  else:
    pagemsg("WARNING: Can't parse pagename")

parser = blib.create_argparser("Convert Greek verb categories to module", include_pagefile=True,
    include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

msg("".join(outtext))

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

from fix_cog_usage import etym_language_to_parent, language_name_to_code
from fix_links import language_codes_to_properties, sh_remove_accents

global_params = [
  "bor", "lbor", "slb", "translit", "der", "clq", "cal", "calq", "calque", "pclq", "sml", "unc", "nolb", "sclb"
]
global_params_at_end = ["q", "alts"]
item_params = ["alt", "g", "gloss", "t", "id", "lit", "pos", "tr", "ts", "sc"]
def process_text_on_page(index, pagetitle, pagetext):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if not args.stdin:
    pagemsg("Processing")

  notes = []

  def sub_link(m, langname, link_langcode, link_langcode_remove_accents, origtext, add_sclb):
    linktext = m.group(0)
    link = m.group(1)
    parts = re.split(r"\|", link)
    if len(parts) > 2:
      pagemsg("WARNING: Too many parts in %s, not converting raw link %s: %s" %
          (link, linktext, origtext))
      return linktext
    page = None
    if len(parts) == 1:
      accented = link
    else:
      page, accented = parts
      page = re.sub("#%s$" % langname, "", page)
    if page:
      if (not link_langcode_remove_accents and accented == page or
          link_langcode_remove_accents and link_langcode_remove_accents(accented) == page):
        page = None
      elif re.search("[#:]", page):
        pagemsg("WARNING: Found special chars # or : in left side of %s, not converting raw link %s: %s" %
            (link, linktext, origtext))
        return origtext
      else:
        pagemsg("WARNING: Page %s doesn't match accented %s in %s, converting to two-part link in raw link %s: %s" %
            (page, accented, link, linktext, origtext))
    if add_sclb:
      sclb_text = "|sclb=1"
    else:
      sclb_text = ""
    if page:
      return "{{l|%s|%s|%s%s}}" % (link_langcode, page, accented, sclb_text)
    else:
      return "{{l|%s|%s%s}}" % (link_langcode, accented, sclb_text)

  def replace_serbo_croatian_with_desc(m):
    bullets1, spacing1, langname, terms = m.groups()
    origtext = m.group(0)

    if "{{desc|" not in langname:
      if u"→" in spacing1:
        spacing1 = re.sub(u"→ *", "", spacing1)
        langname = "{{desc|sh|-|bor=1}}"
      else:
        langname = "{{desc|sh|-}}"

    def replace_sh_term(m):
      termlink = m.group(1)
      if termlink.startswith("[["):
        termlink = re.sub(r"^\[\[(.*?)\]\]$", 
          lambda m: sub_link(m, "Serbo-Croatian", "sh", sh_remove_accents, origtext,
            add_sclb=True), termlink)
      else:
        parsed = blib.parse_text(termlink)
        for t in parsed.filter_templates():
          if tname(t) in ["l", "m"] and getparam(t, "1") == "sh":
            rmparam(t, "sc")
            t.add("sclb", "1")
            blib.set_template_name(t, "desc")
        termlink = str(parsed)
      return termlink

    terms = re.sub(r"(?:Latin|Roman|Cyrillic): *(\[\[[^\[\]\n]*?\]\]|\{\{[lm]\|sh\|[^{}\n]*?\}\})",
      replace_sh_term, terms)

    newtext = "%s%s%s%s" % (bullets1, spacing1, langname, terms)
    pagemsg("Replacing <%s> with <%s>" % (origtext, newtext))
    return newtext

  def replace_with_desc(m):
    bullets, desc, links = m.groups()
    origtext = m.group(0)

    parsed_desc = blib.parse_text(desc)
    desct = list(parsed_desc.filter_templates())[0]
    if tname(desct) != "desc":
      pagemsg("WARNING: Internal error: Putative {{desc}} template does not have 'desc' as template name: %s" %
          str(desct))
      return origtext

    langcode = getparam(desct, "1")
    non_etym_langcode = etym_language_to_parent.get(langcode, langcode)

    # Find the set of language codes (hopefully at most one) among the
    # templated links.
    seen_langcodes = set()
    for mm in re.finditer(r"\{\{[lm]\|([^{}|\n]*?)\|.*?\}\}", links):
      seen_langcodes.add(mm.group(1))
    if len(seen_langcodes) > 1:
      pagemsg("WARNING: Saw multiple lang codes %s, skipping: %s" % (
        ",".join(seen_langcodes), origtext))
      return origtext

    # If there is one, use it to replace raw links, otherwise use language
    # code of name (or parent language, if it's an etym language).
    if len(seen_langcodes) == 1:
      link_langcode = list(seen_langcodes)[0]
    else:
      link_langcode = non_etym_langcode

    if link_langcode != langcode and link_langcode != non_etym_langcode:
      pagemsg("WARNING: {{desc}} langcode %s is not same as or etymology language child of link langcode %s: %s"
        % (langcode, link_langcode, origtext))
      return origtext

    desc_params_at_beginning = []
    desc_params_at_end = []
    for param in desct.params:
      pn = pname(param)
      pv = str(param.value)
      if pn in ["1", "2"] or pn in item_params:
        pass
      elif pn in global_params:
        desc_params_at_beginning.append((pn, pv))
      elif pn in global_params_at_end:
        desc_params_at_end.append((pn, pv))
      else:
        pagemsg("WARNING: Can't yet handle param %s=%s in {{desc}}: %s"
          % (pn, pv, origtext))
        return origtext
    for pn, pv in desc_params_at_beginning:
      rmparam(desct, pn)
      if pv:
        desct.add(pn, pv, before="1", preserve_spacing=False)

    link_langcode_remove_accents = None
    if link_langcode in language_codes_to_properties:
      _, link_langcode_remove_accents, _, _ = (
        language_codes_to_properties[link_langcode])

    # Replace raw links with templated links.
    def replace_raw_link(m):
      linktext = m.group(0)
      if linktext.startswith("["):
        mm = re.search(r"^\[\[([^\[\]\n]*?)\]\]$", linktext)
        if not mm:
          pagemsg("WARNING: Internal error: Something wrong, not a raw link: %s: %s" % (linktext, origtext))
          return linktext
        if non_etym_langcode in blib.languages_byCode:
          langname = blib.languages_byCode[non_etym_langcode]["canonicalName"]
        else:
          pagemsg("WARNING: For langcode %s, non-etym parent %s isn't a language: %s"
            % (langcode, non_etym_langcode, origtext))
          langname = "UNKNOWN"
        retval = sub_link(mm, langname, link_langcode, link_langcode_remove_accents,
          origtext, add_sclb=False)
        if retval != linktext:
          notes.append("replace raw link %s with %s" % (linktext, retval))
        return retval
      return linktext
    # We don't want to replace raw links inside of templates, so we match both templates
    # and raw links and don't change the templates.
    new_links = re.sub(r"\{\{[^{}\n]*?\}\}|\[\[[^\[\]\n]*?\]\]", replace_raw_link, links)
    if new_links != links:
      pagemsg("Replacing raw link <%s> with <%s>" % (links, new_links))
      links = new_links

    # Replace {{m|...}} links with {{l|...}} links.
    new_links = re.sub(r"\{\{m\|(.*?)\}\}", r"{{l|\1}}", links)
    if new_links != links:
      pagemsg("Replacing m-type link <%s> with <%s>" % (links, new_links))
      links = new_links
      notes.append("replace {{m}} link(s) with {{l}} in {{desc}} line")

    # Incorporate {{l}} links into {{desc}}.
    parsed_links = blib.parse_text(new_links)
    term_index = 1
    for t in parsed_links.filter_templates():
      def getp(param):
        return getparam(t, param)
      tn = tname(t)
      if tn != "l":
        pagemsg("WARNING: Internal error: Saw non-{{l}} template %s in links: %s" %
            (str(t), origtext))
        return origtext
      term_index += 1
      tlang = getp("1")
      if tlang != link_langcode:
        pagemsg("WARNING: Internal error: Langcode %s of template %s is not %s: %s" %
          (tlang, str(t), link_langcode, origtext))
        return origtext
      term = getp("2")
      desct.add(str(term_index + 1), term)
      genders = []
      g = getp("g")
      if g:
        genders.append(g)
      for i in range(2, 20):
        g = getp("g%s" % i)
        if g:
          genders.append(g)
      if genders:
        desct.add("g%s" % term_index, ",".join(genders))
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if pn == "1" or pn == "2" or not pv:
          continue
        if re.search("^g[0-9]*$", pn):
          continue
        if pn == "3":
          desct.add("alt%s" % term_index, pv)
        elif pn == "4":
          desct.add("t%s" % term_index, pv)
        elif re.search("^[0-9]+$", pn):
          pagemsg("WARNING: Saw numbered param > 4 %s=%s in {{l}} template %s: %s" %
            (pn, pv, str(t), origtext))
          return origtext
        elif re.search("[0-9]", pn):
          pagemsg("WARNING: Saw indexed param %s=%s in {{l}} template %s: %s" %
            (pn, pv, str(t), origtext))
          return origtext
        else:
          desct.add("%s%s" % (pn, term_index), pv)
    notes.append("incorporate %s {{l}} link%s into {{desc|%s}}" % (
      term_index - 1, "s" if term_index - 1 > 1 else "", langcode))
    for pn, pv in desc_params_at_end:
      rmparam(desct, pn)
      if pv:
        desct.add(pn, pv, preserve_spacing=False)

    newtext = "%s%s" % (bullets, str(desct))
    pagemsg("Replacing <%s> with <%s>" % (origtext, newtext))
    return newtext

  if args.do_all_sections:
    pagehead = ""
    sections = [pagetext]
  else:
    # Split into (sub)sections
    splitsections = re.split("(^===*[^=\n]+=*==\n)", pagetext, 0, re.M)
    # Extract off pagehead and recombine section headers with following text
    pagehead = splitsections[0]
    sections = []
    for i in range(1, len(splitsections)):
      if (i % 2) == 1:
        sections.append("")
      sections[-1] += splitsections[i]

  # Go through each section in turn, looking for Descendants sections
  for i in range(len(sections)):
    if args.do_all_sections or re.match("^===*Descendants=*==\n", sections[i]):
      text = sections[i]
      #text = re.sub(r"^(\*+:?)( *(?:→ *)?)(Serbo-Croat(?:ian):|\{\{desc(?:\|.*?)?\|sh(?:\|.*?)?\|-(?:\|.*?)?\}\})((?:\n\1[*:] *(?:Latin|Roman|Cyrillic): *(?:\[\[[^\[\]\n]*?\]\]|\{\{[lm]\|sh\|[^{}\n]*?\}\}))+)",
      #   replace_serbo_croatian_with_desc, text, 0, re.M)
      text = re.sub(r"^(\*+ *(?:→ *)?)(\{\{desc\|[^{}\n]*\}\})((?:, *(?:\{\{[lm]\|[^{}|\n]*?\|[^{}\n]*?\}\}|\[\[[^\[\]\n]*?\]\]))+)",
         replace_with_desc, text, 0, re.M)
      sections[i] = text

  return pagehead + "".join(sections), notes

parser = blib.create_argparser("Use {{desc}} with multiple terms in place of {{desc|...}}, {{l|...}}, ...",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--do-all-sections", action="store_true", help="Do all sections, not only Descendants sections")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

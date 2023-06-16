#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

from fix_cog_usage import etym_language_to_parent, language_name_to_code
from fix_links import language_codes_to_properties, sh_remove_accents

langcode_langname_to_correct_langcode = {
  # Don't do the following; they aren't correct.
  # ("Middle Chinese", "zh"): "ltc",
  # ("Old Chinese", "zh"): "och",
  ("Middle French", "fr"): "frm",
  ("Old French", "fr"): "fro",
  ("Low German", "nds-de"): "nds-de",
  # Arabic, xng
  ("Middle English", "en"): "enm",
  ("Mamluk-Kipchak", "qwm"): "trk-mmk",
  ("Old Spanish", "es"): "osp",
  # Chinese, xng
  ("French", "en"): "fr",
  # Solon, evn
  ("Norwegian", "nb"): "nb",
  ("Spanish", "pt"): "es",
  # English, enm: do by hand?
  ("Norwegian", "nn"): "nn",
  ("Portuguese", "es"): "pt",
  ("Aromanian", "ro"): "rup",
  # West Frisian, ofs
  ("Old Portuguese", "pt"): "roa-opt",
  # Uyghur, xng
  ("Galician", "ga"): "gl",
  ("Old Danish", "da"): "gmq-oda",
  ("Cornish", "co"): "kw",
  ("Sardinian", "sn"): "sc",
  ("English", "fr"): "en",
  # Armenian, xcl
  ("Sicilian", "sc"): "scn",
  ("Old Ukrainian", "uk"): "zle-ouk",
  ("Old Swedish", "sv"): "gmq-osw",
  ("Middle Welsh", "mwl"): "wlm",
  # Hebrew, arc
  # Greek, grc: do by hand?
  # Dutch, dum
  ("Livvi", "liv"): "olo",
  # Faroese, is
  ("Spanish", "it"): "es",
  ("Old Norse", "no"): "non",
  ("English", "la"): "en",
  # Crimean Tatar, krc
  # Chagatai, tt
  ("Tagalog", "en"): "tl",
  ("Scots", "en"): "sco",
  ("Old Catalan", "ca"): "roa-oca",
  # Middle Low German, gmh
  ("Middle Dutch", "nl"): "dum",
  # Latin, mul
  ("Italian", "en"): "it",
  # Irish, sga
  # French, fro
  # French, frm
  ("English", "tl"): "en",
  ("Swedish", "sw"): "sv",
  ("Swedish", "se"): "sv",
  ("Old Welsh", "wlo"): "owl",
  ("Old Latin", "la"): "itc-ola",
  ("Old Belarusian", "be"): "zle-obe",
  ("Norwegian", "non"): "no",
  ("Middle High German", "de"): "gmh",
  ("Middle Breton", "mbr"): "xbm",
  ("Middle Armenian", "hy"): "axm",
  ("Italian", "pt"): "it",
  ("Italian", "fr"): "it",
  # Icelandic, fo 
  ("Galician", "pt"): "gl",
  # Chinese, cmn 
  ("Catalan", "en"): "ca",
  # Don't do the following; it isn't correct.
  # ("Cantonese", "zh"): "yue",
  # Wa, prk
  ("Ukrainian", "ru"): "uk",
  # Swedish, gmq-osw
  ("Spanish", "fr"): "es",
  ("Old Italian", "ito"): "roa-oit",
  # Norwegian, da
  # Middle English, ang
  ("Middle Breton", "mbt"): "xbm",
  ("Latvian", "lt"): "lv",
  ("Latin", "en"): "la",
  ("German", "fr"): "de",
  ("Friulian", "fr"): "fur",
  ("Estonian", "es"): "et",
  ("Dutch", "en"): "nl",
  ("Walloon", "wal"): "wa",
  # Swedish, no
  ("Swabian", "gsw"): "swg",
  # Silesian, gmw-ecg (dialect of gmw-ecg)
  ("Old Polish", "pl"): "zlw-opl",
  ("Old Irish", "ga"): "sga",
  # Occitan, ca 
  ("Norwegian Nynorsk", "no"): "nn",
  ("Norman", "fr"): "nrf",
  ("Middle Welsh", "mlw"): "wlm",
  ("Middle Low German", "mgl"): "gml",
  # Livvi, krl
  ("Italian", "la"): "it",
  # German, gmh
  ("Galician", "es"): "gl",
  # French, nrf
  ("English", "es"): "en",
}
  
non_canonical_to_canonical_names = {
  "Romansh": "Romansch",
  "Nynorsk": "Norwegian Nynorsk",
  # Nynorsk: more specific than Norwegian
  "Azeri": "Azerbaijani",
  "Old Frankish": "Frankish",
  "Cuman": "Kipchak", # is this correct?
  "Khorezmian": "Khwarezmian",
  "East Frisian": "Saterland Frisian",
  "Uighur": "Uyghur",
  "Meadow Mari": "Eastern Mari",
  "Hill Mari": "Western Mari",
  "Komi": "Komi-Zyrian", # is this correct?
  # Croatian: ? map to Serbo-Croatian?
  # Nancowry: more specific than Central Nicobarese
  # Mari: less specific than Eastern Mari
  "Malaccan Creole Portuguese": "Kristang",
  "Modern Greek": "Greek",
  "Odia": "Oriya",
  # Languedocien: more specific than Occitan
  # Gascon: more specific than Occitan
  "Nogay": "Nogai",
  "Kurripako": "Curripaco",
  "Official Aramaic": "Imperial Aramaic",
  "Southern Altay": "Southern Altai",
  "Ludic": "Ludian",
  "Sorani": "Central Kurdish",
  "Sinhala": "Sinhalese",
  "Car": "Car Nicobarese",
  # Serbian: ? map to Serbo-Croatian?
  "Kurmanji": "Northern Kurdish",
  # Chakavian: more specific than Serbo-Croatian
  # Valencian: more specific than Catalan
  # Logudorese Sardinian: more specific than Sardinian
  # Campidanese: more specific than Sardinian
  "Awakatek": "Aguacateca",
  # Auvergnat: more specific than Occitan
  "Yukuna": "Yucuna",
  "West Greenlandic Pidgin": "Greenlandic Pidgin",
  # Walser: more specific than Alemannic German
  # Swiss German: more specific than German
  "Papiamento": "Papiamentu",
  "Low Saxon": "Low German",
  # Kinyarwanda: ? more specific than Rwanda-Rundi?
  # Kajkavian: more specific than Serbo-Croatian
  "Izhorian": "Ingrian",
  # Flemish: ? more specific than Dutch?
  "Belarussian": "Belarusian",
  "Sipakapa": "Sipakapense",
  # Ripuarian: ? more specific than Central Franonian?
  # Nuorese: more specific than Sardinian
  # Moselle Franconian: ? more specific than Central Franconian?
  # Logudorese: more specific than Sardinian
  "Inupiaq": "Inupiak",
  # Frisian: not same as West Frisian
  "Abkhazian": "Abkhaz",
  "Tangkhul": "Tangkhul Naga",
  # Siglitun: ? more specific than Inuktitut?
  "Salako": "Kendayan",
  "Proto-Sami": "Proto-Samic",
  "Poitevin": "Poitevin-Saintongeais",
  "Old Uighur": "Old Uyghur",
  # Nunatsiavummiut: ? more specific than Inuktitut?
  "Khamnigan": "Khamnigan Mongol",
  # Inuinnaqtun: ? more specific than Inkutitut?
  "Ilokano": "Ilocano",
  # "High German": "German",
  # Erzgebirgisch: more specific than East Central German
  # Bontok: not same as Central Bontoc
  "Bikol": "Bikol Central",
  "Balochi": "Baluchi",
  # Amuzgo: not same as Guerrero Amuzgo
  ###
  ### Names formerly unrecognized, now non-canonical
  ###
  "Khalkha": "Khalkha Mongolian",
  "Eastern Yugur": "East Yugur",
  "Orkhon": "Old Turkic",
  "Sgaw": "S'gaw Karen",
  "Faeroese": "Faroese",
}

unrecognized_to_canonical_names = {
  "Written Tibetan": ("Written", "Tibetan"),
  "Written Burmese": ("Written", "Burmese"),
}

def process_text_on_page(index, pagetitle, pagetext):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if not args.stdin:
    pagemsg("Processing")

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
    bullets, langname, links = m.groups()
    origtext = m.group(0)

    if langname in non_canonical_to_canonical_names:
      new_langname = non_canonical_to_canonical_names[langname]
      pagemsg("Replacing non-canonical or unrecognized %s with %s: %s" % (
        langname, new_langname, origtext))
      langname = new_langname

    pretext = ""
    if langname in unrecognized_to_canonical_names:
      spec = unrecognized_to_canonical_names[langname]
      if type(spec) is tuple:
        new_pretext, new_langname = spec
        pretext = new_pretext + " "
      else:
        new_langname = spec
      pagemsg("Replacing unrecognized %s with %s%s: %s" % (
        langname, new_langname, ' (with pretext "%s")' % pretext if pretext else "",
        origtext))
      langname = new_langname

    if langname not in language_name_to_code:
      pagemsg("WARNING: Saw unrecognized lang name <%s>" % langname)
      return origtext
    langcodes, etymcode, isetymcanon = language_name_to_code[langname]

    # Find the language whose canonical name is the given language name.
    potential_langcodes = set()
    for code, iscanon in langcodes:
      if iscanon:
        potential_langcodes.add(code)
    if len(potential_langcodes) > 1:
      pagemsg("WARNING: Language name %s has multiple canonical codes %s, skipping: %s" % (
        langname, ",".join(potential_langcodes), origtext))
      return origtet
    if len(potential_langcodes) == 1 and isetymcanon:
      pagemsg("WARNING: Language name %s has both regular canonical code %s and etym language canonical code %s, skipping: %s" % (
        langname, list(potential_langcodes)[0], etymcode, origtext))
      return origtext
    if len(potential_langcodes) == 1:
      langcode = list(potential_langcodes)[0]
    elif isetymcanon:
      langcode = etymcode
    else:
      pagemsg("WARNING: Language name %s isn't a canonical name of any language, skipping: %s" % (
        langname, origtext))
      return origtext

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
      link_langcode = etym_language_to_parent.get(langcode, langcode)

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
          pagemsg("WARNING: Something wrong, not a raw link: %s: %s" % (linktext, origtext))
          return linktext
        return sub_link(m, langname, link_langcode, link_langcode_remove_accents,
          origtext, add_sclb=False)
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

    # Replace bad language codes in templated links with better ones, based
    # on langname.
    parsed = blib.parse_text(links)
    made_mod = False
    for t in parsed.filter_templates():
      if tname(t) in ["l", "m"]:
        template_langcode = getparam(t, "1")
        if (langname, template_langcode) in langcode_langname_to_correct_langcode:
          new_langcode = langcode_langname_to_correct_langcode[(langname, template_langcode)]
          if new_langcode == template_langcode:
            if template_langcode in blib.languages_byCode:
              new_langname = blib.languages_byCode[template_langcode]["canonicalName"]
            elif template_langcode in blib.etym_languages_byCode:
              pagemsg("WARNING: Encountered template langcode %s that's an etymology language: %s" % (
                template_langcode, origtext))
              break
            else:
              pagemsg("WARNING: Encountered unrecognized template langcode %s: %s" % (
                template_langcode, origtext))
              break
            pagemsg("Replacing language name %s with %s based on template langcode %s in %s: %s" % (
              langname, new_langname, template_langcode, str(t), origtext))
            langname = new_langname
            langcode = template_langcode
            break
          if new_langcode != langcode:
            pagemsg("Replacing language code %s with %s based on language name %s and template langcode %s in %s: %s" % (
              langcode, new_langcode, langname, template_langcode, str(t), origtext))
            langcode = new_langcode
          link_langcode = etym_language_to_parent.get(langcode, langcode)
          origt = str(t)
          t.add("1", link_langcode)
          if langcode == link_langcode:
            pagemsg("Replacing langcode %s in template %s with %s based on language name %s, producing %s: %s" %
              (template_langcode, origt, link_langcode, langname, str(t), origtext))
          else:
            pagemsg("Replacing langcode %s in template %s with %s based on etymology language name %s with langcode %s, producing %s: %s" %
              (template_langcode, origt, link_langcode, langname, langcode, str(t), origtext))
          made_mod = True
    if made_mod:
      links = str(parsed)

    # Replace leftmost templated link with {{desc}}.

    # (1) Find lang code of leftmost templated link.
    mm = re.search(r"\{\{[lm]\|([^{}|\n]*?)\|.*?\}\}", links)
    if not mm:
      pagemsg("WARNING: Something wrong, no links, skipping: %s" % origtext)
      return origtext
    # (2) Check that it's replaceable by language code of name.
    template_langcode = mm.group(1)
    if not (langcode == template_langcode or etym_language_to_parent.get(langcode, "NONE") == template_langcode):
      pagemsg("WARNING: Language name %s inferred code %s not same as or (if etym lang a child of) template code %s, skipping: %s" % (
        langname, langcode, template_langcode, origtext))
      return origtext
    # (3) Actually replace.
    if u"→" in bullets:
      bullets = re.sub(u"→ *", "", bullets)
      bortext = "|bor=1"
    else:
      bortext = ""
    links = re.sub(r"\{\{[lm]\|[^{}|\n]*?\|(.*?)\}\}",
        r"{{desc|%s|\1%s}}" % (langcode, bortext), links, 1)
    newtext = "%s%s%s" % (bullets, pretext, links.lstrip())
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
      text = re.sub(ur"^(\*+:?)( *(?:→ *)?)(Serbo-Croat(?:ian):|\{\{desc(?:\|.*?)?\|sh(?:\|.*?)?\|-(?:\|.*?)?\}\})((?:\n\1[*:] *(?:Latin|Roman|Cyrillic): *(?:\[\[[^\[\]\n]*?\]\]|\{\{[lm]\|sh\|[^{}\n]*?\}\}))+)",
         replace_serbo_croatian_with_desc, text, 0, re.M)
      text = re.sub(ur"^(\*+ *(?:→ *)?)([A-Z][A-Za-z-]+(?: [A-Za-z-]+)*?):((?: *(?:\{\{[lm]\|[^{}|\n]*?\|[^{}\n]*?\}\}|\[\[[^\[\]\n]*?\]\]),?)+)",
         replace_with_desc, text, 0, re.M)
      sections[i] = text

  return pagehead + "".join(sections), "Use {{desc}} for descendants in place of LANG {{l|CODE|...}} or LANG [[LINK]]"

parser = blib.create_argparser("Use {{desc}} for descendants in place of LANG {{l|CODE|...}} or LANG [[LINK]]",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--do-all-sections", action="store_true", help="Do all sections, not only Descendants sections")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

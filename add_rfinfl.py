#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

AA = "\u093e"
M = "\u0901"
IND_AA = "आ"

pos_to_headword_template = {
  "be": {
    "noun": "be-noun",
    "proper noun": "be-proper noun",
    "adjective": "be-adj",
    "verb": "be-verb",
  },
  "bg": {
    "noun": "bg-noun",
    "proper noun": "bg-proper noun",
    "adjective": "bg-adj",
    "verb": "bg-verb",
  },
  "ru": {
    "noun": r"ru-noun\+?",
    "proper noun": r"ru-proper noun\+?",
    "adjective": "ru-adj",
    "verb": "ru-verb",
  },
  "uk": {
    "noun": "uk-noun",
    "proper noun": "uk-proper noun",
    "adjective": "uk-adj",
    "verb": "uk-verb",
  },
  "cs": {
    "noun": "cs-noun",
    "proper noun": "cs-proper noun",
    "adjective": "cs-adj",
    "verb": "cs-verb",
  },
  "is": {
    "noun": "(is-noun|is-noun/old)",
    "proper noun": "(is-proper noun|is-proper noun/old)",
    "adjective": "is-adj",
    "verb": "is-verb.*",
  },
  "hi": {
    "noun": "hi-noun",
    "proper noun": "hi-proper noun",
    "adjective": "hi-adj",
    "verb": "hi-verb",
  },
}

def be_lemma_is_indeclinable(t, pagetitle, pagemsg):
  if tname(t) == "be-noun" and getparam(t, "decl") in ["off", "no", "indeclinable"]:
    return True
  return False

def bg_lemma_is_indeclinable(t, pagetitle, pagemsg):
  return not not getparam(t, "indecl")

def ru_lemma_is_indeclinable(t, pagetitle, pagemsg):
  if tname(t) in ["ru-noun", "ru-proper noun"] and getparam(t, "3") == "-":
    return True
  if tname(t) == "ru-adj" and getparam(t, "indecl"):
    return True
  return False

def uk_lemma_is_indeclinable(t, pagetitle, pagemsg):
  if tname(t) in ["uk-noun", "uk-proper noun"]:
    if getparam(t, "3") == "-":
      return True
    headword = getparam(t, "1")
    if headword and headword == getparam(t, "3") and (not re.search("я́?$", headword) or not getparam(t, "2").startswith("n")):
      pagemsg("WARNING: Indeclinable noun not marked as such: %s" % str(t))
      return True
  if tname(t) == "uk-adj" and getparam(t, "indecl"):
    return True
  return False

def cs_lemma_is_indeclinable(t, pagetitle, pagemsg):
  return not not getparam(t, "indecl")

def is_lemma_is_indeclinable(t, pagetitle, pagemsg):
  return not not getparam(t, "indec")

def hi_lemma_is_indeclinable(t, pagetitle, pagemsg):
  if tname(t) in ["hi-noun", "hi-proper noun"]:
    return not not getparam(t, "ind")
  if tname(t) == "hi-adj":
    if getparam(t, "ind"):
      return True
    pagename = blib.remove_links(getparam(t, "head") or pagetitle)
    # If the lemma doesn't end with any of the declinable suffixes, it's
    # definitely indeclinable. Some indeclinable adjectives end with these
    # same suffixes, but we have no way to know that these are indeclinable,
    # so assume declinable.
    return not (pagename.endswith(AA) or pagename.endswith(IND_AA) or
        pagename.endswith(AA + M))
  return False

lemma_is_indeclinable = {
  "be": be_lemma_is_indeclinable,
  "bg": bg_lemma_is_indeclinable,
  "ru": ru_lemma_is_indeclinable,
  "uk": uk_lemma_is_indeclinable,
  "cs": cs_lemma_is_indeclinable,
  "is": is_lemma_is_indeclinable,
  "hi": hi_lemma_is_indeclinable,
}

pos_to_nonlemma_template = {
  "be": None,
  "bg": "(bg-verbal noun|bg-verbal noun form|bg-part|bg-part form)",
  "cs": None,
  "is": None,
  "ru": "(ru-noun form|ru-.*alt-ё|ru-verb-cform)",
  "uk": None,
  "hi": "(hi-verb-form|hi-noun-form|hi-adj-form)",
}

pos_to_infl_template = {
  "be": {
    "noun": "(be-decl-noun.*|be-noun-.*)",
    "proper noun": "(be-decl-noun.*|be-noun-.*)",
    "verb": "be-conj-.*",
    "adjective": "(be-decl-adj.*|be-adj-.*)",
  },
  "bg": {
    "noun": "bg-ndecl",
    "proper noun": "bg-ndecl",
    "verb": "bg-conj.*",
    "adjective": "bg-adecl",
  },
  "ru": {
    "noun": "(ru-noun-table|ru-decl-noun.*)",
    "proper noun": "(ru-noun-table|ru-decl-noun.*)",
    "verb": "ru-conj.*",
    "adjective": "(ru-decl-adj.*)",
  },
  "uk": {
    "noun": "(uk-decl-noun.*)",
    "proper noun": "(uk-decl-noun.*)",
    "verb": "uk-conj.*",
    "adjective": "(uk-decl-adj.*|uk-adj-.*)",
  },
  "cs": {
    "noun": "cs-ndecl",
    "proper noun": "cs-ndecl",
    "verb": "cs-conj.*",
    "adjective": "cs-adecl",
  },
  "is": {
    "noun": "is-ndecl",
    "proper noun": "is-ndecl",
    "verb": "is-conj.*",
    "adjective": "is-decl-adj.*",
  },
  "hi": {
    "noun": "hi-ndecl",
    "proper noun": "hi-ndecl",
    "verb": "hi-conj.*",
    "adjective": "hi-adecl",
  },
}

pos_to_infl_template_exclude = {
  "hi": {
    "noun": "hi-noun-form",
    "proper noun": "hi-noun-form",
    "adjective": "hi-adj-form",
  }
}

lang_to_name = {
  "be": "Belarusian",
  "bg": "Bulgarian",
  "ru": "Russian",
  "uk": "Ukrainian",
  "cs": "Czech",
  "is": "Icelandic",
  "hi": "Hindi",
}

def get_indentation_level(header):
  return len(re.sub("[^=].*", "", header, 0, re.S))

def process_text_on_page(index, pagetitle, text, lang, pos):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  origtext = text
  cappos = pos.capitalize()
  notes = []

  pagemsg("Processing")

  retval = blib.find_modifiable_lang_section(text, lang_to_name[lang], pagemsg)
  if retval is None:
    pagemsg("WARNING: Couldn't find %s section" % lang_to_name[lang])
    return
  sections, j, secbody, sectail, has_non_lang = retval
  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)
  k = 1
  last_pos = None
  if "indeclinable %ss" % pos in secbody + sectail:
    pagemsg("Saw 'indeclinable %ss' in text, skipping" % pos)
    return
  while k < len(subsections):
    if re.search(r"=\s*%s\s*=" % cappos, subsections[k]):
      level = get_indentation_level(subsections[k])
      last_pos = cappos
      endk = k + 2
      while endk < len(subsections) and get_indentation_level(subsections[endk]) > level:
        endk += 2
      if endk < len(subsections) and re.search(r"=\s*(Declension|Inflection|Conjugation)\s*=", subsections[endk]):
        pagemsg("WARNING: Found probably misindented inflection header after ==%s== header: %s" %
            (cappos, subsections[endk].strip()))
        k = endk + 2
        continue
      pos_text = "".join(subsections[k:endk])
      parsed = blib.parse_text(pos_text)
      saw_head = False
      saw_head_form = False
      head_is_indeclinable = False
      saw_inflection_of = False
      inflt = None
      found_rfinfl = False
      for t in parsed.filter_templates():
        tn = tname(t)
        if re.search("^" + pos_to_headword_template[lang][pos] + "$", tn) or (
          tn == "head" and getparam(t, "1") == lang and getparam(t, "2") in [pos, "%ss" % pos]
        ):
          if saw_head:
            pagemsg("WARNING: Found two heads under one POS section: second is %s" % str(t))
          saw_head = True
          if tn != "head" and lemma_is_indeclinable[lang](t, pagetitle, pagemsg):
            pagemsg("Headword template is indeclinable: %s" % str(t))
            head_is_indeclinable = True
            break
        if re.search("^" + pos_to_infl_template[lang][pos] + "$", tn):
          exclude_re = pos_to_infl_template_exclude.get(lang, {}).get(pos, None)
          if not exclude_re or not re.search("^" + exclude_re + "$", tn):
            if inflt:
              pagemsg("WARNING: Found two inflection templates under one POS section: %s and %s" % (
                str(inflt), str(t)))
            inflt = t
            pagemsg("Found %s inflection: %s" % (pos, str(t)))
        if tn in ["inflection of", "infl of"]:
          pagemsg("Saw 'inflection of': %s" % str(t))
          saw_inflection_of = True
        if pos_to_nonlemma_template[lang] and re.search("^" + pos_to_nonlemma_template[lang] + "$", tn) or (
          tn == "head" and getparam(t, "1") == lang and re.search(" forms?$", getparam(t, "2"))
        ):
          pagemsg("Saw non-lemma headword template: %s" % str(t))
          saw_head_form = True
      if not inflt:
        pagemsg("Didn't find %s inflection" % pos)
        if saw_head_form:
          pagemsg("Saw non-lemma headword template, not adding {{rfinfl}}")
        elif saw_inflection_of:
          pagemsg("WARNING: Didn't see non-lemma headword template but saw 'inflection of'; not adding {{rfinfl}}")
        elif not saw_head:
          pagemsg("WARNING: Didn't see lemma or non-lemma headword template; not adding {{rfinfl}}")
        elif head_is_indeclinable:
          pagemsg("Headword template is indeclinable, not adding {{rfinfl}}")
        else:
          for l in range(k, endk, 2):
            if re.search(r"=\s*(Declension|Inflection|Conjugation)\s*=", subsections[l]):
              secparsed = blib.parse_text(subsections[l + 1])
              for t in secparsed.filter_templates():
                tn = tname(t)
                if tname(t) != "rfinfl":
                  pagemsg("WARNING: Saw unknown template %s in existing inflection section, skipping" % (
                    str(t)))
                  break
                else:
                  pagemsg("Found %s" % str(t))
              break
          else: # no break
            insert_k = k + 2
            while insert_k < endk and "Usage notes" in subsections[insert_k]:
              insert_k += 2
            if not subsections[insert_k - 1].endswith("\n\n"):
              subsections[insert_k - 1] = re.sub("\n*$", "\n\n",
                subsections[insert_k - 1] + "\n\n")
            subsections[insert_k:insert_k] = [
              "%s%s%s\n" % ("=" * (level + 1), "Conjugation" if pos == "verb" else "Declension",
                "=" * (level + 1)),
              "{{rfinfl|%s|%s}}\n\n" % (lang, pos)
            ]
            pagemsg("Inserted level-%s inflection section with {{rfinfl|%s|%s}}" % (
              level + 1, lang, pos))
            notes.append("add {{rfinfl|%s|%s}}" % (lang, pos))
            endk += 2 # for the two subsections we inserted

      k = endk
    else:
      m = re.search(r"=\s*(Noun|Proper noun|Pronoun|Determiner|Verb|Adverb|Adjective|Interjection|Conjunction)\s*=", subsections[k])
      if m:
        last_pos = m.group(1)
      if re.search(r"=\s*(Declension|Inflection|Conjugation)\s*=", subsections[k]):
        if not last_pos:
          pagemsg("WARNING: Found inflection header before seeing any parts of speech: %s" %
              (subsections[k].strip()))
        elif last_pos == cappos:
          pagemsg("WARNING: Found probably misindented inflection header after ==%s== header: %s" %
              (cappos, subsections[k].strip()))
      k += 2

  secbody = "".join(subsections)
  sections[j] = secbody + sectail
  text = "".join(sections)
  text = re.sub("\n\n\n+", "\n\n", text)
  if not notes and origtext != text:
    notes.append("convert 3+ newlines to 2")
  return text, notes

parser = blib.create_argparser("Add {{rfinfl}} where missing",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--pos", help="Part of speech (noun, proper noun, verb, adjective)", required=True)
parser.add_argument("--lang", help="Language code", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def do_process_text_on_page(index, pagetitle, text):
  return process_text_on_page(index, pagetitle, text, args.lang, args.pos)

blib.do_pagefile_cats_refs(args, start, end, do_process_text_on_page,
    edit=True, stdin=True, default_cats=["%s %ss" % (lang_to_name[args.lang], args.pos)])

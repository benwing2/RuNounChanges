#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, unicodedata
from dataclasses import dataclass
from typing import Any

import blib
from blib import getparam, rmparam, tname, pname, msg, site


def singularize(text):
  m = re.search("^(.*?)ies$", text)
  if m:
    return m.group(1) + "y"
  # Handle cases like "[[parish]]es"
  m = re.search(r"^(.*?[sc]h\]*)es$", text)
  if m:
    return m.group(1)
  # Handle cases like "[[box]]es"
  m = re.search(r"^(.*?x\]*)es$", text)
  if m:
    return m.group(1)
  m = re.search("^(.*?)s$", text)
  if m:
    return m.group(1)
  return text


def canonicalize_existing_linked_head(head, pagemsg, link_the=True):
  orighead = head
  head = head.replace("’", "'").replace("[[one's|one's]]", "[[one's]]").replace("[['s|'s]]", "[['s]]")
  head = re.sub(r"\]\]'s\b", "]][[-'s|'s]]", head)
  head = re.sub(r"\]\]'( |-|$)", r"]][[-'|']]\1", head)
  head = re.sub(r"\[\[([\[\]]*)\|\1's\]\]", r"[[\1]][[-'s|'s]]", head)
  words = re.split(r"(\[\[.*?\]\][a-z]*|[^- \[\]]+)", head)
  modwords = []
  for i, word in enumerate(words):
    if word == "[[one]][['s]]":
      modwords.append("[[one's]]")
    elif word == "[[someone]][['s]]":
      modwords.append("[[someone's]]")
    elif not link_the and (word in ["the", "[[the]]"]):
      modwords.append("the")
    elif word in ["an", "and", "as", "at", "by", "for", "from", "in", "much", "of", "on", "one", "or", "over",
                  "someone", "the", "to", "with", "under"] or (
        word == "a" and i > 0 and words[i - 1] == " " and i < len(words) - 1 and words[i + 1] == " "):
      modwords.append("[[%s]]" % word)
    elif word and "[" not in word and "]" not in word and " " not in word and "-" not in word:
      # Link all remaining words
      #modwords.append("[[%s]]" % word)
      pagemsg("Saw unlinked word '%s' in %s" % (word, orighead))
      modwords.append(word)
    else:
      modwords.append(word)
  retval = "".join(modwords)
  #retval = re.sub(r"^\[\[to\]\] ", "", retval)
  if orighead:
    pagemsg("Canonicalized %s to %s" % (orighead, retval))
  return retval


def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  # Default function to split a word on apostrophes. Don't split apostrophes at the beginning or end of a word (e.g.
  # [['ndrangheta]] or [[po']]). Handle multiple apostrophes correctly, e.g. [[l'altr'ieri]] -> [[l']][altr']][[ieri]].
  def default_split_apostrophe(word):
    m = re.search("^('*)(.*?)('*)$", word)
    begapo, inner_word, endapo = m.groups()
    apostrophe_parts = word.split("'")
    linked_apostrophe_parts = []
    apostrophes_at_beginning = ""
    i = 0
    # Apostrophes at beginning get attached to the first word after (which will always exist but may
    # be blank if the word consists only of apostrophes).
    while i < len(apostrophe_parts) - 1: # -1 in case the word consists only of apostrophes
      apostrophe_part = apostrophe_parts[i]
      i = i + 1
      if apostrophe_part == "":
        apostrophes_at_beginning += "'"
      else:
        break
    apostrophe_parts[i] = apostrophes_at_beginning + apostrophe_parts[i]
    # Now, do the remaining parts. A blank part indicates more than one apostrophe in a row; we join
    # all of them to the preceding word.
    while i < len(apostrophe_parts):
      apostrophe_part = apostrophe_parts[i]
      if apostrophe_part == "":
        linked_apostrophe_parts[-1] += "'"
      elif i == len(apostrophe_parts) - 1:
        linked_apostrophe_parts.append(apostrophe_part)
      else:
        linked_apostrophe_parts.append(apostrophe_part + "'")
      i = i + 1
    return "".join("[[" + tolink + "]]" for tolink in linked_apostrophe_parts)


  @dataclass
  class MultiwordLinksData:
    split_hyphen_when_space: Any
    split_apostrophe: Any
    no_split_apostrophe_words: set
    include_hyphen_prefixes: set

  # Auto-add links to a word that should not have spaces but may have hyphens and/or apostrophes. We split off final
  # punctuation,: split on hyphens if `data.split_hyphen` is given, and also split on apostrophes if
  # `data.split_apostrophe` is given. We only split on hyphens if they are in the middle of the word, not at the
  # beginning or end (hyphens at the beginning or end indicate suffixes or prefixes, respectively).
  # `include_hyphen_prefixes`, if given, is a set of prefixes (not including the final hyphen) where we should include
  # the final hyphen in the prefix. Hence, e.g. if "anti" is in the set, a Portuguese word like [[anti-herói]]
  # "anti-hero" will be split [[anti-]][[herói]] (whereas a word like [[código-fonte]] "source code" will be split as
  # [[código]]-[[fonte]]).
  # 
  # If `data.split_apostrophe` is specified, we split on apostrophes unless `data.no_split_apostrophe_words` is given
  # and the word is in the specified set, such as French [[c'est]] and [[quelqu'un]]. If `data.split_apostrophe` is
  # True, the default algorithm applies, which splits on all apostrophes except those at the beginning and end of a word
  # (as in Italian [['ndrangheta]] or [[po']]), and includes the apostrophe in the link to its left (so we auto-split
  # French [[l'eau]] as [[l']][[eau]] and [[l'altr'ieri]] as [[l']][altr']][[ieri]]). If `data.split_apostrophe` is
  # specified but not `True`, it should be a function of one argument that does custom apostrophe-splitting. The
  # argument is the word to split, and the return value should be the split and linked word.
  def add_single_word_links(space_word, data):
    m = re.search("^(.*)([,;:?!])$", space_word)
    if m:
      space_word_no_punct, punct = m.groups()
    else:
      space_word_no_punct = space_word
      punct = ""
    words = None
    if re.search("^-", space_word_no_punct) or re.search("-$", space_word_no_punct):
      # don't split prefixes and suffixes
      words = [space_word_no_punct]
    elif callable(data.split_hyphen_when_space):
      words = data.split_hyphen_when_space(space_word_no_punct)
      if type(words) is str:
        return words + punct
    if not words:
      if data.split_hyphen_when_space:
        words = space_word_no_punct.split("-")
      else:
        words = [space_word_no_punct]
    linked_words = []
    for j, word in enumerate(words):
      if j < len(words) - 1 and data.include_hyphen_prefixes and word in data.include_hyphen_prefixes:
        word = "[[" + word + "-]]"
      else:
        # Don't split on apostrophes if the word is in `no_split_apostrophe_words`.
        if ((not data.no_split_apostrophe_words or word not in data.no_split_apostrophe_words) and
            data.split_apostrophe and "'" in word):
          if data.split_apostrophe is True:
            word = default_split_apostrophe(word)
          else: # custom apostrophe splitter/linker
            word = data.split_apostrophe(word)
        else:
          word = "[[" + word + "]]"
        if j < len(words) - 1:
          word = word + "-"
      linked_words.append(word)
    return "".join(linked_words) + punct

  # Auto-add links to a multiword term. Links are not added to single-word terms. We split on spaces, and also on
  # hyphens if `split_hyphen` is given or the word has no spaces. In addition, we split on apostrophes, including the
  # apostrophe in the link to its left (so we auto-split "de l'eau" "[[de]] [[l']][[eau]]"). We don't always split on
  # hyphens because of cases like "boire du petit-lait" where "petit-lait" should be linked as a whole, but provide the
  # option to do it for cases like "croyez-le ou non". If there's no space, however,: it makes sense to split on hyphens
  # by default (e.g. for "avant-avant-hier"). Cases where only some of the hyphens should be split can always be handled
  # by explicitly specifying the head (e.g. "Nord-Pas-de-Calais" given as head=[[Nord]]-[[Pas-de-Calais]]).
  #
  # `no_split_apostrophe_words` and `include_hyphen_prefixes` allow for special-case handling of particular words and
  # are as described in the comment above add_single_word_links().
  def add_links_to_multiword_term(term, data):
    if "[" in term or "]" in term:
      return term
    if " " not in term:
      data = MultiwordLinksData(True, data.split_apostrophe, data.no_split_apostrophe_words,
                                data.include_hyphen_prefixes)
    words = term.split(" ")
    linked_words = []
    for word in words:
      linked_words.append(add_single_word_links(word, data))
    retval = " ".join(linked_words)
    # If we ended up with a single link consisting of the entire term,
    # remove the link.
    m = re.search(r"^\[\[([^\[\]]*)\]\]$", retval)
    if m:
      return m.group(1)
    return retval

  def get_autohead(pagename, t):
    def getp(param):
      return getparam(t, param)
    if getp("nolinkhead") or not re.search(r"[ '-\[\]]", pagename): 
      return pagename
    else:
      en_no_split_apostrophe_words = {
        "one's",
        "someone's",
        "he's",
        "she's",
        "it's",
      }

      en_include_hyphen_prefixes = {
        # We don't include things that are also words even though they are often (perhaps mostly) prefixes, e.g.
        # "be", "counter", "cross", "extra", "half", "mid", "over", "pan", "under".
        "acro",
        "acousto",
        "Afro",
        "agro",
        "anarcho",
        "angio",
        "Anglo",
        "ante",
        "anti",
        "arch",
        "auto",
        "bi",
        "bio",
        "cis",
        "co"
        "cryo",
        "crypto",
        "de",
        "demi",
        "eco",
        "electro",
        "Euro",
        "ex",
        "Greco",
        "hemi",
        "hydro",
        "hyper",
        "hypo",
        "infra",
        "Indo",
        "inter",
        "intra",
        "Judeo",
        "macro",
        "meta",
        "micro",
        "mini",
        "multi",
        "neo",
        "neuro",
        "non",
        "para",
        "peri",
        "post",
        "pre",
        "pro",
        "proto",
        "pseudo",
        "re",
        "semi",
        "sub",
        "super",
        "trans",
        "un",
        "vice",
      }

      def is_english(term):
        page = pywikibot.Page(site, term)
        content = blib.safe_page_text(page, errandpagemsg)
        if content and "==English==\n" in content:
            return True
        return False

      def en_split_hyphen_when_space(word):
        if "-" not in word:
          return None
        if getp("hyphspace"):
          return "[[" + word.replace("-", " ") + "|" + word + "]]"
        if getp("nosplithyph"):
          return "[[" + word + "]]"
        if not getp("splithyph"):
          space_word = word.replace("-", " ")
          if is_english(space_word):
            return "[[" + space_word + "|" + word + "]]"
          if is_english(word):
            return "[[" + word + "]]"
        return None

      def en_split_apostrophe(word):
        m = re.search("^(.*)'s$", word)
        if m:
          return "[[" + m.group(1) + "]][[-'s|'s]]"
        m = re.search("^(.*)'$", word)
        if m:
          base = m.group(1)
          if base.endswith("s"):
            sg = singularize(base)
            if is_english(sg):
              return "[[" + sg + "|" + base + "]][[-'|']]"
          return "[[" + base + "]][[-'|']]"
        return "[[" + word + "]]"

      return add_links_to_multiword_term(pagename, MultiwordLinksData(
        en_split_hyphen_when_space, en_split_apostrophe, en_no_split_apostrophe_words, en_include_hyphen_prefixes
      ))

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param)
    tn = tname(t)
    origt = str(t)
    params_to_check = None
    if tn in [
        "en-adj", "en-adjective",
        "en-adv", "en-adverb",
        "en-con", "en-conjunction",
        # "en-cont", "en-contraction", ## not Lua-ized yet
        # "en-det", ## not Lua-ized yet
        "en-interj", "en-interjection", "en-intj",
        "en-noun",
        # "en-part", "en-particle", ## not Lua-ized yet
        # "en-prefix", ## not Lua-ized yet
        # "en-prep", "en-preposition", ## not Lua-ized yet
        # "en-prep phrase", "en-prepositional phrase", "en-PP", "en-pp", ## not Lua-ized yet
        # "en-pron", "en-pronoun", ## not Lua-ized yet
        "en-proper noun", "en-proper-noun", "en-prop", "en-propn",
        # "en-proverb", "en-prov", ## not Lua-ized yet
        # "en-suffix", "en-suf", ## not Lua-ized yet
        # "en-symbol", ## not Lua-ized yet
        "en-verb",
    ]:
      params_to_check = ["head"]
    if params_to_check:
      default_head = pagetitle or getparam(t, "pagename")
      if default_head.startswith("Unsupported titles/"):
        pagemsg("WARNING: Skipping unsupported title")
        continue
      default_head = get_autohead(default_head, t)
      for param in params_to_check:
        paramval = getp(param)
        m = re.search(r"^(?:the|\[\[the\]\]) (.*)$", paramval)
        if m:
          has_the = True
          pagemsg("Removing 'the' from %s=%s in {{%s}} and converting to def=1" % (param, paramval, tn))
          t.add("def", "1")
          notes.append("remove 'the' from %s=%s in {{%s}} and convert to def=1" % (param, paramval, tn))
          paramval = m.group(1)
        else:
          has_the = False
        if " " in paramval and paramval == pagetitle:
          pagemsg("Converting %s=%s in {{%s}} that's identical to pagename to nolinkhead=1" % (param, paramval, tn))
          rmparam(t, param)
          t.add("nolinkhead", "1")
          notes.append("convert %s=%s in {{%s}} that's identical to pagename to nolinkhead=1" % (param, paramval, tn))
          continue
        if paramval == default_head:
          pagemsg("Removing redundant %s=%s in {{%s}}" % (param, paramval, tn))
          rmparam(t, param)
          notes.append("remove redundant %s=%s in {{%s}}" % (param, paramval, tn))
          continue
        canonval = None
        if "[[" in paramval:
          canonval = canonicalize_existing_linked_head(paramval, pagemsg)
          if canonval == paramval:
            canonval = None
          elif canonval == default_head:
            pagemsg("Removing redundant %s=%s (canonicalized to %s) in {{%s}}" % (param, paramval, canonval, tn))
            rmparam(t, param)
            notes.append("remove redundant %s=%s (canonicalized to %s) in {{%s}}" % (param, paramval, canonval, tn))
            continue
        if paramval:
          if canonval and canonval != paramval:
            pagemsg("Canonicalizing %s=%s%s to %s in {{%s}}; not same as auto-generated head '%s'" % (
              param, paramval, " (with 'the' removed)" if has_the else "", canonval, tn, default_head))
            t.add(param, canonval)
            notes.append("canonicalize %s=%s%s to %s in {{%s}}" % (
              param, paramval, " (with 'the' removed)" if has_the else "", canonval, tn))
            continue
          if has_the:
            pagemsg("Re-adding %s=%s in {{%s}} (same as canonicalization with 'the' removed, but different from auto-generated head '%s')" % (
              param, paramval, tn, default_head))
            t.add(param, paramval)
            notes.append("re-add %s=%s in {{%s}}" % (param, paramval, tn))
            continue
          pagemsg("Not removing %s=%s (same as canonicalization) in {{%s}}; not same as auto-generated head '%s'" % (
            param, paramval, tn, default_head))
    if origt != str(t):
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  text = str(parsed)
  return text, notes

parser = blib.create_argparser("Remove redundant head parameters from {{en-*}}", include_pagefile=True,
                               include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, default_cats=["English lemmas"], edit=True,
                           stdin=True)

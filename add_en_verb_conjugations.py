#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

dont_singularize = {
  "Browns",
  "Cheerios",
  "Jesus",
  "Thames",
  "Wheaties",
  "arms",
  "as",
  "backwards",
  "balls",
  "bejeebers",
  "blues",
  "bourgeois",
  "bowels",
  "brains",
  "breeches",
  "bus",
  "cahoots",
  "chops",
  "creeps",
  "dickens",
  "edgeways",
  "gas",
  "goods",
  "guts",
  "halfsies",
  "has",
  "his",
  "hots",
  "is",
  "its",
  "jeans",
  "jim-jams",
  "knickers",
  "nuts",
  "odds",
  "pants",
  "panties",
  "pros",
  "shits",
  "shorts",
  "this",
  "trousers",
  "upstairs",
  "us",
  "vitals",
  "wits",
  "yes",
  "yours",
}

singularize_as_such = {
  "cookies": "cookie",
  "eyeteeth": "eyetooth",
  "eye-teeth": "eye-tooth",
  "feet": "foot",
  "geese": "goose",
  "halves": "half",
  "lies": "lie",
  "pies": "pie",
  "presses": "press",
  "stompies": "stompie",
  "teeth": "tooth",
  "torpedoes": "torpedo",
  "walkies": "walkie",
}

def singularize(word):
  if word in singularize_as_such:
    singular = singularize_as_such[word]
    if word.startswith(singular):
      return "[[%s]]%s" % (singular, word[len(singular):])
    else:
      return "[[%s|%s]]" % (singular, word)
  if word.endswith("ies"):
    return "[[%s|%s]]" % (word[:-3] + "y", word)
  if re.search("(ch|sh|x)es$", word):
    return "[[%s]]es" % word[:-2]
  m = re.search(r"(^.*)([bcdfgjklmnpqrtv])\2ing$", word) # not s z h w x y
  if m:
    return "[[%s]]%sing" % (m.group(1) + m.group(2), m.group(2))
  m = re.search(r"(^[bcdfghjklmnpqrstvwxyz]*[aeiou][bcdfgjklmnpqrstvz])ing$", word) # not h w x y
  if m:
    return "[[%se|%sing]]" % (m.group(1), m.group(1))
  if word.endswith("ing"):
    return "[[%s]]ing" % word[:-3]
  return "[[%s]]s" % word[:-1]

def singularizable(word):
  return word in singularize_as_such or (
    word.endswith("s") and not word.endswith("ss") and not word.endswith("'s") and
    word not in dont_singularize) or (
    not word.endswith("thing") and re.search("^.*[aeiou].*ing$", word)
  )

def link(word):
  if singularizable(word):
    return singularize(word)
  elif word == "the":
    return word
  else:
    return "[[" + word + "]]"

def canonicalize_existing_linked_head(head, pagemsg, link_the=False):
  head = head.replace("’", "'").replace("[[one's|one's]]", "[[one's]]").replace("[['s|'s]]", "[['s]]")
  words = re.split(r"((?:\[\[.*?\]\]|[^ \[\]])+)", head)
  modwords = []
  for word in words:
    if word == "[[one]][['s]]":
      modwords.append("[[one's]]")
    elif word == "[[someone]][['s]]":
      modwords.append("[[someone's]]")
    elif not link_the and (word in ["the", "[[the]]"]):
      modwords.append("the")
    elif word and "[" not in word and "]" not in word and " " not in word:
      modwords.append("[[%s]]" % word)
    else:
      modwords.append(word)
  retval = "".join(modwords)
  retval = re.sub(r"^\[\[to\]\] ", "", retval)
  if head:
    pagemsg("Canonicalized %s to %s" % (head, retval))
  return retval

def process_text_on_page(index, pagename, text, verbs):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  if args.mode == "full-conj":
    if pagename not in verbs:
      pagemsg("WARNING: Couldn't find entry for pagename")
      return

    parsed = blib.parse_text(text)
    for t in parsed.filter_templates():
      tn = tname(t)
      origt = str(t)
      if tn == "head" and getparam(t, "1") == "en" and getparam(t, "2") == "verb":
        if getparam(t, "3"):
          pagemsg("WARNING: Already has 3=, not touching: %s" % str(t))
          continue
        blib.set_template_name(t, "en-verb")
        t.add("1", verbs[pagename])
        rmparam(t, "2")
        notes.append("convert {{head|en|verb}} of multiword expression to {{en-verb}}")
      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))

  else:
    first, rest = pagename.split(" ", 1)
    if first not in verbs:
      pagemsg("WARNING: Couldn't find entry for first=%s" % first)
      return

    parsed = blib.parse_text(text)
    for t in parsed.filter_templates():
      tn = tname(t)
      origt = str(t)
      if tn == "head" and getparam(t, "1") == "en" and getparam(t, "2") == "verb":
        if getparam(t, "3"):
          pagemsg("WARNING: Already has 3=, not touching: %s" % str(t))
          continue
        blib.set_template_name(t, "en-verb")
        done = False
        words = pagename.split(" ")
        plural = False
        for word in words:
          if singularizable(word):
            plural = True
            break
        if plural:
          if verbs[first].startswith("<"):
            restwords = []
            for word in words[1:]:
              restwords.append(link(word))
            param1 = "[[%s]]%s %s" % (first, verbs[first], " ".join(restwords))
            head_from_param = re.sub("<.*?>", "", param1)
            existing_head = getparam(t, "head")
            canon_existing_head = canonicalize_existing_linked_head(existing_head, pagemsg)
            if canon_existing_head == head_from_param:
              pagemsg("Removing existing head %s" % existing_head)
              rmparam(t, "head")
              t.add("1", param1)
              done = True
            elif canon_existing_head != existing_head:
              pagemsg("Replacing existing head %s with canonicalized %s" % (existing_head, canon_existing_head))
              t.add("head", canon_existing_head)
              pagemsg("WARNING: Existing head not removed (canonicalized to %s, different from head-from-param %s): %s" %
                  (canon_existing_head, head_from_param, origt))
            elif existing_head:
              pagemsg("WARNING: Existing head not removed (different from head-from-param %s): %s" %
                  (head_from_param, origt))
            else:
              t.add("1", param1)
              done = True
          else:
            t.add("1", verbs[first])
            headwords = []
            for word in words:
              if not headwords: # first word
                headwords.append("[[" + word + "]]")
              else:
                headwords.append(link(word))
            head_from_param = " ".join(headwords)
            existing_head = getparam(t, "head")
            canon_existing_head = canonicalize_existing_linked_head(existing_head, pagemsg)
            if canon_existing_head == head_from_param:
              pagemsg("Removing existing head %s" % existing_head)
              rmparam(t, "head")
            elif canon_existing_head != existing_head:
              pagemsg("Replacing existing head %s with canonicalized %s" % (existing_head, canon_existing_head))
              t.add("head", canon_existing_head)
              pagemsg("WARNING: Existing head not removed (canonicalized to %s, different from head-from-param %s): %s" %
                  (canon_existing_head, head_from_param, origt))
            elif existing_head:
              pagemsg("WARNING: Existing head not removed (different from head-from-param %s): %s" %
                  (head_from_param, origt))
            else:
              t.add("head", head_from_param)
            done = True
        if not done:
          existing_head = getparam(t, "head")
          if existing_head:
            head_from_param = " ".join("[[%s]]" % word if word != "the" else word for word in pagename.split(" "))
            canon_existing_head = canonicalize_existing_linked_head(existing_head, pagemsg)
            if canon_existing_head == head_from_param:
              pagemsg("Removing existing head %s" % existing_head)
              rmparam(t, "head")
            elif canon_existing_head != existing_head:
              pagemsg("Replacing existing head %s with canonicalized %s" % (existing_head, canon_existing_head))
              t.add("head", canon_existing_head)
              pagemsg("WARNING: Existing head not removed (canonicalized to %s, different from head-from-param %s): %s" %
                  (canon_existing_head, head_from_param, origt))
            else:
              pagemsg("WARNING: Existing head not removed (different from head-from-param %s): %s" %
                  (head_from_param, origt))
          if verbs[first].startswith("<"):
            t.add("1", "%s%s %s" % (first, verbs[first], rest))
          else:
            t.add("1", verbs[first])
        rmparam(t, "2")

        notes.append("convert {{head|en|verb}} of multiword expression to {{en-verb}}")
      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Convert {{head|en|verb}} to {{en-verb}} with specified conjugation",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--direcfile", help="File of conjugated verbs")
parser.add_argument("--mode", choices=["full-conj", "single-word"], help="Operating mode. If 'full-conj', --direcfile contains full conjugations with <>. If 'single-word', --direcfile contains the first word followed by the conjugation of that word.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

verbs = {}
for line in blib.yield_items_from_file(args.direcfile):
  if args.mode == "full-conj":
    verb = re.sub("<.*?>", "", line)
    verbs[verb] = line
  else:
    if " " not in line:
      msg("WARNING: No space in line: %s" %  line)
      continue
    verb, spec = line.split(" ", 1)
    verbs[verb] = spec
def do_process_text_on_page(index, pagename, text):
  return process_text_on_page(index, pagename, text, verbs)
blib.do_pagefile_cats_refs(args, start, end, do_process_text_on_page, edit=True, stdin=True)

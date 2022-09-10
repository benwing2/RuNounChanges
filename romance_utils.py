#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re

all_specials = ["first", "second", "first-second", "first-last", "last", "each"]

def add_endings(bases, endings):
  if bases is None or endings is None:
    return None
  retval = []
  if type(bases) is not list:
    bases = [bases]
  if type(endings) is not list:
    endings = [endings]
  for base in bases:
    for ending in endings:
      retval.append(base + ending)
  return retval

def handle_multiword(form, special, inflect, prepositions):
  if special == "first":
    m = re.search("^(.*?)( .*)$", form)
    if not m:
      return None
    first, rest = m.groups()
    return add_endings(inflect(first), rest)
  elif special == "second":
    m = re.search("^(.+? )(.+?)( .*)$", form)
    if not m:
      return None
    first, second, rest = m.groups()
    return add_endings(add_endings([first], inflect(second)), rest)
  elif special == "first-second":
    m = re.search("^([^ ]+)( )([^ ]+)( .*)$", form)
    if not m:
      return None
    first, space, second, rest = m.groups()
    return add_endings(add_endings(add_endings(inflect(first), space), inflect(second)), rest)
  elif special == "first-last":
    m = re.search("^(.*?)( .* )(.*?)$", form)
    if not m:
      m = re.search("^(.*?)( )(.*)$", form)
    if not m:
      return None
    first, middle, last = m.groups()
    return add_endings(add_endings(inflect(first), middle), inflect(last))
  elif special == "last":
    m = re.search("^(.* )(.*?)$", form)
    if not m:
      return None
    rest, last = m.groups()
    return add_endings(rest, inflect(last))
  elif special == "each":
    if " " not in form:
      return None
    terms = form.split(" ")
    inflected_terms = []
    for i, term in enumerate(terms):
      term = inflect(term)
      if i > 0:
        term = add_endings(" ", term)
      inflected_terms.append(term)
    result = ""
    for term in inflected_terms:
      result = add_endings(result, term)
    return result
  else:
    assert not special, "Saw unrecognized special=%s" % special

  m = re.search("^(.*?)( (?:%s))(.*)$" % "|".join(prepositions), form)

  if m:
    first, space_prep, rest = m.groups()
    return add_endings(inflect(first), space_prep + rest)

  if " " in form:
    return handle_multiword(form, "first-last", inflect, prepositions)

  return None

# Auto-add links to a word that should not have spaces but may have hyphens and/or apostrophes. We split off final
# punctuation, then split on hyphens if `splithyph` is given, and also split on apostrophes. The apostrophe is
# included in the link to its left (so we auto-split "l'eau" as "[[l']][[eau]]). `no_split_apostrophe_words`, if
# given, is a set of words that contain apostrophes but which should not be split on the apostrophes, such as
# "[[c'est]]" and "[[quelqu'un]]".
def add_single_word_links(space_word, splithyph, no_split_apostrophe_words=None):
  m = re.search("^(.*)([,;:?!])$", space_word)
  if m:
    space_word_no_punct, punct = m.groups()
  else:
    space_word_no_punct = space_word
    punct = ""
  # don't split prefixes and suffixes
  if not splithyph or re.search("^-", space_word_no_punct) or re.search("-$", space_word_no_punct):
    words = [space_word_no_punct]
  else:
    words = space_word_no_punct.split("-")
  linked_words = []
  for word in words:
    # Don't split on apostrophes if the word is in `no_split_apostrophe_words` or begins or ends with an apostrophe
    # (e.g. [['ndrangheta]] or [[po']]). Handle multiple apostrophes correctly, e.g. [[l'altr'ieri]].
    if ((not no_split_apostrophe_words or word not in no_split_apostrophe_words) and "'" in word
        and not re.search("^'", word) and not re.search("'$", word)):
      apostrophe_parts = word.split("'")
      for i, apostrophe_part in enumerate(apostrophe_parts):
        if i == len(apostrophe_parts) - 1:
          apostrophe_parts[i] = "[[" + apostrophe_part + "]]"
        else:
          apostrophe_parts[i] = "[[" + apostrophe_part + "']]"
      word = "".join(apostrophe_parts)
    else:
      word = "[[" + word + "]]"
    linked_words.append(word)
  return "-".join(linked_words) + punct

# Auto-add links to a lemma. Links are not added to single-word lemmas. We split on spaces, and also on hyphens if
# splithyph is given or the word has no spaces. In addition, we split on apostrophes, including the apostrophe in
# the link to its left (so we auto-split "de l'eau" "[[de]] [[l']][[eau]]"). We don't always split on hyphens because
# of cases like "boire du petit-lait" where "petit-lait" should be linked as a whole, but provide the option to do it
# for cases like "croyez-le ou non". If there's no space, however, then it makes sense to split on hyphens by default
# (e.g. for "avant-avant-hier"). Cases where only some of the hyphens should be split can always be handled by
# explicitly specifying the head (e.g. "Nord-Pas-de-Calais" given as head=[[Nord]]-[[Pas-de-Calais]]).
def add_lemma_links(lemma, splithyph, no_split_apostrophe_words=None):
  if " " not in lemma:
    splithyph = True
  words = lemma.split(" ")
  linked_words = []
  for word in words:
    linked_words.append(add_single_word_links(word, splithyph, no_split_apostrophe_words))
  retval = " ".join(linked_words)
  # If we ended up with a single link consisting of the entire lemma,
  # remove the link.
  m = re.search(r"^\[\[([^\[\]]*)\]\]$", retval)
  return m.group(1) if m else retval

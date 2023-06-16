#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re

all_specials = [
  "+", # requests the default behavior with preposition handling
  "first",
  "second",
  "first-second",
  "first-last",
  "last",
  "each",
]

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

# Inflect a possibly multiword or hyphenated term `form` using the function `inflect`, which is a function of one
# argument that is called on a single word to inflect and should return either the inflected word or a list of
# inflected words. `special` indicates how to inflect the multiword term and should be e.g. "first" to inflect only the
# first word, "first-last" to inflect the first and last words, "each" to inflect each word, etc. See
# `allowed_special_indicators` above for the possibilities. If `special` is '+', or is omitted and the term is
# multiword (i.e. containing a space character), the function checks for multiword or hyphenated terms containing the
# prepositions in `prepositions`, e.g. Italian [[senso di marcia]] or [[succo d'arancia]] or Portuguese
# [[tartaruga-do-mar]]. If such a term is found, only the first word is inflected. Otherwise, the default is
# "first-last". `prepositions` is a list of regular expressions matching prepositions. The regular expressions will
# automatically have the separator character (space or hyphen) added to the left side but not the right side, so they
# should contain a space character (which will automatically be converted to the appropriate separator) on the right
# side unless the preposition is joined on the right side with an apostrophe. Examples of preposition regular
# expressions for Italian are "di ", "sull'" and "d?all[oae] " (which matches "dallo ", "dalle ", "alla ", etc.).
#
# The return value is always either a list of inflected multiword or hyphenated terms, or nil if `special` is omitted
# and `form` is not multiword. (If `special` is specified and `form` is not multiword or hyphenated, an error results.)
def handle_multiword(form, special, inflect, prepositions, sep=None):
  sep = sep or (" " if " " in form else "-")
  # Given a regex, replace space with the appropriate separator.
  def hack_re(regex):
    if sep == " ":
      return regex
    else:
      return regex.replace(" ", re.escape(sep))

  if special == "first":
    m = re.search(hack_re("^(.*?)( .*)$"), form)
    if not m:
      return None
    first, rest = m.groups()
    return add_endings(inflect(first), rest)
  elif special == "second":
    m = re.search(hack_re("^([^ ]+ )([^ ]+)( .*)$"), form)
    #m = re.search("^(.+? )(.+?)( .*)$", form)
    if not m:
      return None
    first, second, rest = m.groups()
    return add_endings(add_endings([first], inflect(second)), rest)
  elif special == "first-second":
    m = re.search(hack_re("^([^ ]+)( )([^ ]+)( .*)$"), form)
    if not m:
      return None
    first, space, second, rest = m.groups()
    return add_endings(add_endings(add_endings(inflect(first), space), inflect(second)), rest)
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
  elif special == "first-last":
    m = re.search(hack_re("^(.*?)( .* )(.*?)$"), form)
    if not m:
      m = re.search(hack_re("^(.*?)( )(.*)$"), form)
    if not m:
      return None
    first, middle, last = m.groups()
    return add_endings(add_endings(inflect(first), middle), inflect(last))
  elif special == "last":
    m = re.search(hack_re("^(.* )(.*?)$"), form)
    if not m:
      return None
    rest, last = m.groups()
    return add_endings(rest, inflect(last))
  elif special != "+":
    assert not special, "Saw unrecognized special=%s" % special

  # Only do default behavior if special indicator '+' explicitly given or separator is space; otherwise we will
  # break existing behavior with hyphenated words.
  if (special == "+" or sep == " ") and sep in form:
    m = re.search(hack_re("^(.*?)( (?:%s).*)$" % "|".join(prepositions)), form)

    if m:
      first, space_prep_rest = m.groups()
      return add_endings(inflect(first), space_prep_rest)

    # multiword or hyphenated expressions default to first-last; we need to pass in the separator to avoid
    # problems with multiword terms containing hyphens in the individual words
    return handle_multiword(form, "first-last", inflect, prepositions, sep)

  return None

# Auto-add links to a word that should not have spaces but may have hyphens and/or apostrophes. We split off final
# punctuation, then split on hyphens if `splithyph` is given, and also split on apostrophes. We only split on hyphens
# and apostrophes if they are in the middle of the word, not at the beginning of end (hyphens at the beginning or end
# indicate suffixes or prefixes, respectively, and apostrophes at the beginning or end are also possible, as in
# Italian [['ndrangheta]] or [[po']]). The apostrophe is included in the link to its left (so we auto-split French
# [[l'eau]] as [[l']][[eau]]). `no_split_apostrophe_words`, if given, is a set of words that contain apostrophes but
# which should not be split on the apostrophes, such as French [[c'est]] and [[quelqu'un]]. `include_hyphen_prefixes`,
# if given, is a set of prefixes (not including the final hyphen) where we should include the final hyphen in the
# prefix. Hence, e.g. if "anti" is in the set, a Portuguese word like [[anti-herói]] "anti-hero" will be split
# [[anti-]][[herói]] (whereas a word like [[código-fonte]] "source code" will be split as [[código]]-[[fonte]]).
def add_single_word_links(space_word, splithyph, no_split_apostrophe_words=None, include_hyphen_prefixes=None):
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
  for j, word in enumerate(words):
    if j < len(words) - 1 and include_hyphen_prefixes and word in include_hyphen_prefixes:
      word = "[[" + word + "-]]"
    else:
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
      if j < len(words) - 1:
        word = word + "-"
    linked_words.append(word)
  return "".join(linked_words) + punct

# Auto-add links to a multiword term. Links are not added to single-word terms. We split on spaces, and also on hyphens
# if `splithyph` is given or the word has no spaces. In addition, we split on apostrophes, including the apostrophe in
# the link to its left (so we auto-split "de l'eau" "[[de]] [[l']][[eau]]"). We don't always split on hyphens because
# of cases like "boire du petit-lait" where "petit-lait" should be linked as a whole, but provide the option to do it
# for cases like "croyez-le ou non". If there's no space, however, then it makes sense to split on hyphens by default
# (e.g. for "avant-avant-hier"). Cases where only some of the hyphens should be split can always be handled by
# explicitly specifying the head (e.g. "Nord-Pas-de-Calais" given as head=[[Nord]]-[[Pas-de-Calais]]).
#
# `no_split_apostrophe_words` and `include_hyphen_prefixes` allow for special-case handling of particular words and
# are as described in the comment above add_single_word_links().
def add_links_to_multiword_term(term, splithyph, no_split_apostrophe_words=None, include_hyphen_prefixes=None):
  if " " not in term:
    splithyph = True
  words = term.split(" ")
  linked_words = []
  for word in words:
    linked_words.append(add_single_word_links(word, splithyph, no_split_apostrophe_words, include_hyphen_prefixes))
  retval = " ".join(linked_words)
  # If we ended up with a single link consisting of the entire term,
  # remove the link.
  m = re.search(r"^\[\[([^\[\]]*)\]\]$", retval)
  return m.group(1) if m else retval

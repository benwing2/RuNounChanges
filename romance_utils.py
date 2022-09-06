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

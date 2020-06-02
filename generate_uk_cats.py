#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re
import pywikibot

dosave = True
overwrite = False
donouns = False
doadjs = True
doverbs = False

site = pywikibot.Site()

def msg(text):
  print text.encode('utf-8')

adj_decls = [
  ["hard-stem stem-stressed", (u"-ий", u"-а", u"-е", u"-і")],
  ["hard-stem ending-stressed", (u"-и́й", u"-а́", u"-е́", u"-і́")],
  ["soft-stem", (u"-ій", u"-я", u"-є", u"-і")],
  [u"ц-stem", (u"-ий", u"-я", u"-е", u"-і")],
  ["vowel-stem", (u"-їй", u"-я", u"-є", u"-ї")],
  ["possessive", (u"-", u"-а", u"-е", u"-і")],
]

def create_cat(cat, args, adj=False, verb=False):
  if verb:
    cat = "Category:Ukrainian " + cat.replace("~", "verbs")
    text = "{{uk-verb cat}}"
  elif adj:
    cat = "Category:Ukrainian " + cat.replace("~", "adjectives")
    text = "{{uk-adj cat|%s}}" % "|".join(args)
  else:
    cat = "Category:Ukrainian " + cat.replace("~", "nouns")
    text = "{{uk-noun cat|%s}}" % "|".join(args)
  page = pywikibot.Page(site, cat)
  if not overwrite and page.exists():
    msg("Page %s already exists, not overwriting" % cat)
    return
  page.text = unicode(text)
  changelog = "Creating '%s' with text '%s'" % (cat, text)
  msg("Changelog = %s" % changelog)
  if dosave:
    page.save(comment = changelog)

if doadjs:
  for ty, endings in adj_decls:
    create_cat(ty + " ~", ["adj"] + list(endings), adj=True)

if doverbs:
  for class_ in range(1, 16):
    create_cat("class %s ~" % class_, [], verb=True)
  for subclass in ["1a", "2a", "2b", "3a", u"3°a", "3b", u"3°b", "3c", u"3°c",
      "4a", "4b", "4c", "5a", "5b", "5c",
      "6a", u"6°a", "6b", u"6°b", "6c", u"6°c",
      "7a", "7b", "7c", "8a", "8b", "8c", "9a", "9b", "10a", "10c",
      "11a", "11b", "12a", "12b", "13b", "14a", "14b", "14c",
      "15a"
  ]:
    create_cat("class %s ~" % subclass, [], verb=True)

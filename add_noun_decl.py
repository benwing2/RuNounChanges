#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Fix ru-noun headers to be ru-noun+ and ru-proper noun to ru-proper noun+
# for multiword nouns by looking up the individual declensions of the words.

# Example page:
# 
# ==Russian==
# 
# ===Pronunciation===
# * {{ru-IPA|са́харная ва́та}}
# 
# ===Noun===
# {{ru-noun|[[сахарный|са́харная]] [[вата|ва́та]]|f-in}}
# 
# # [[cotton candy]], [[candy floss]], [[fairy floss]]
# 
# ====Declension====
# {{ru-decl-noun-see|сахарный|вата}}
# 
# [[Category:ru:Foods]]

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam

import rulib as ru

site = pywikibot.Site()

def msg(text):
  print text.encode("utf-8")

def errmsg(text):
  print >>sys.stderr, text.encode("utf-8")

def arg1_is_stress(arg1):
  if not arg1:
    return False
  for arg in re.split(",", arg1):
    if not (re.search("^[a-f]'?'?$", arg) or re.search(r"^[1-6]\*?$", arg)):
      return False
  return True

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  origtext = page.text
  parsed = blib.parse_text(origtext)

  # Find the declension arguments for LEMMA and inflected form INFL,
  # the WORDINDth word in the expression. Return value is a tuple of
  # four items: a list of (NAME, VALUE) tuples for the arguments, whether
  # the word is an adjective, the value of n= (if given), and the value
  # of a= (if given).
  def find_decl_args(lemma, infl, wordind):
    declpage = pywikibot.Page(site, lemma)
    if ru.remove_accents(infl) == lemma:
      wordlink = "[[%s]]" % infl
    else:
      wordlink = "[[%s|%s]]" % (lemma, infl)

    if not declpage.exists():
      pagemsg("WARNING: Page doesn't exist, can't locate decl for %s" % lemma)
      return None
    parsed = blib.parse_text(declpage.text)
    decl_template = None
    for t in parsed.filter_templates():
      if unicode(t.name) in ["ru-noun-table", "ru-decl-adj"]:
        if decl_template:
          pagemsg("WARNING: Multiple decl templates during decl lookup for %s" % lemma)
          return None
        decl_template = t

    if not decl_template:
      pagemsg("WARNING: No decl template during decl lookup for %s" % lemma)
      return None

    if unicode(decl_template.name) == "ru-decl-adj":
      if re.search(ur"\bь\b", getparam(decl_template, "2")):
        return [("1", wordlink), ("2", u"+ь")], True, None, None
      else:
        return [("1", wordlink), ("2", "+")], True, None, None

    # ru-noun-table
    # FIXME!!! We need to be a lot more sophisticated in reality to handle
    # plurals.
    assert unicode(decl_template.name) == "ru-noun-table"
    if ru.remove_accents(infl) != lemma:
      pagemsg("WARNING: Inflection %s not same as lemma %s, probably plural, can't handle yet, skipping" %
          (infl, lemma))
      return None

    # Substitute the wordlink for any lemmas in the declension. This means
    # we need to split out the arg sets in the declension and check the
    # lemma of each one, taking care to handle cases where there is no lemma
    # (it would default to the page name).

    highest_numbered_param = 0
    for p in decl_template.params:
      pname = unicode(p.name)
      if re.search("^[0-9]+$", pname):
        highest_numbered_param = max(highest_numbered_param, int(pname))
    for i in xrange(1, highest_numbered_param + 1)

    # Now gather the numbered arguments into arg sets. Code taken from
    # ru-noun.lua.
    offset = 0
    arg_sets = []
    arg_set = []
    for i in xrange(1, highest_numbered_param + 2):
      end_arg_set = False
      val = getparam(decl_template, str(i))
      if i == highest_numbered_param + 1:
        end_arg_set = True
      elif val == "_" or val == "-" or re.search("^join:", val):
        pagemsg("WARNING: Found multiword decl during decl lookup for %s, skipping" %
            lemma)
        return
      elif val == "or":
        end_arg_set = True

      if end_arg_set:
        arg_sets.append(arg_set)
        arg_set = []
        offset = i
      else:
        arg_set.append(val)

    # Concatenate all the numbered params, substituting the wordlink into
    # the lemma as necessary.
    numbered_params = []
    for arg_set in arg_sets:
      lemma_arg = 0
      if len(arg_set) > 0 and arg1_is_stress(arg_set[0]):
        lemma_arg = 1
      if len(arg_set) <= lemma_arg:
        arg_set.append("")
      if not arg_set[lemma_arg] or arg_set[lemma_arg] == infl or (
          ru.is_monosyllabic(infl) and ru.remove_accents(arg_set[lemma_arg]) ==
          ru.remove_accents(infl)):
        arg_set[lemma_arg] = wordlink
      else:
        pagemsg("WARNING: Can't sub word link %s into decl lemma %s" % (
          wordlink, arg_set[lemma_arg]))
      if numbered_params:
        numbered_params.append("or")
      numbered_params.extend(arg_set)

    # Now gather all params, including named ones.
    params = []
    params.extend(numbered_params)
    num = None
    anim = None
    for p in decl_template.params:
      pname = unicode(p.name)
      val = unicode(p.value)
      if pname == "a":
        anim = val
      elif pname == "n":
        num = val
      elif pname == "notes":
        pagemsg("WARNING: Found notes= during decl lookup for %s, skipping: notes=%s" % (
          lemma, val))
        return None
      elif re.search("^[0-9]+$", pname):
        pass
      else:
        pname += str(wordind)
        params.append((pname, val))

    return params, False, num, anim


  headword_template = None
  see_template = None
  for t in parsed.filter_templates():
    tname = unicode(t.name)
    if tname == "ru-decl-noun-see":
      if see_template:
        pagemsg("WARNING: Multiple ru-decl-noun-see templates, skipping")
        return
      see_template = t
    if tname in ["ru-noun+", "ru-proper noun+"]:
      pagemsg("Found %s, skipping" % tname)
      return
    if tname in ["ru-noun", "ru-proper noun"]:
      if headword_template:
        pagemsg("WARNING: Multiple ru-noun or ru-proper noun templates, skipping")
        return
      headword_template = t

  if not see_template:
    pagemsg("No ru-decl-noun-see templates, skipping")
    return
  if not headword_template:
    pagemsg("WARNING: Can't find headword template, skipping")
    return

  inflected_words = set(ru.remove_accents(ru.remove_links(x.value)) for x in see_template.params)
  headword = getparam(headword_template, "1")
  if "-" in headword:
    pagemsg("WARNING: Can't handle hyphens in headword, yet, skipping")
    return
  # FIXME! This won't work if the words are separated by hyphens.
  headwords = re.findall(r"\[\[(.*?)\]\]|[^ ]+", headword)
  pagemsg("Found headwords: %s" % " @@ ".join(headwords))

  params = []
  saw_noun = False
  overall_num = None
  overall_anim = None

  wordind = 0
  offset = 0
  for word in headwords:
    wordind += 1
    m = re.search("^\[\[([^|]+)\|([^|]+\]\]$", word)
    if m:
      lemma, infl = m.groups()
      lemma = ru.remove_accents(lemma)
    else:
      m = re.search("^\[\[([^|]+)\]\]$", word)
      if m:
        infl = m.group(1)
      else:
        infl = word
      lemma = ru.remove_accents(infl)

    # If not first word, add _ separator between words
    if wordind > 1:
      params.append((str(offset + 1), "_"))
      offset += 1

    if lemma in inflected_words:
      pagemsg("Looking up declension for lemma %s, infl %s" % (lemma, infl))
      retval = find_decl_args(lemma, infl, wordind)
      if not retval:
        pagemsg("WARNING: Can't get declension for %s, skipping" % headword)
        return
      wordparams, isadj, num, anim = retval
      num_numbered_params = 0
      if not isadj:
        if saw_noun:
          pagemsg("WARNING: Multiple inflected nouns, can't handle, skipping")
          return
        overall_num = num
        overall_anum = anim
      for name, val in wordparams:
        if re.search("^[0-9]+$", name):
          name = str(int(name) + offset)
          num_numbered_params += 1
        params.append((name, val))
      offset += num_numbered_params

    else:
      # Invariable
      if rulib.is_unstressed(infl):
        word = "*" + word
      params.append((str(offset + 1), word))
      params.append((str(offset + 2), "$"))
      offset += 2

  ...
  # FIXME: Set the number and animacy, and extract the gender/num/animacy
  # values using generate_args(), and compare with the gender/num/animacy
  # values found in the template. Error if not same. The animacy comes
  # directly from overall_anim, while the number should be singular if
  # the noun is proper, else ceom from overall_num.

  # {{ru-noun|[[сахарный|са́харная]] [[вата|ва́та]]|f-in}}

  ...

  new_text = unicode(parsed)

  if new_text != origtext:
    comment = "Replace ru-(proper )noun with ru-(proper )noun+ with appropriate declension"
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = new_text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = argparse.ArgumentParser(description="Convert ru-noun to ru-noun+, ru-proper noun to ru-proper noun+ for multiword nouns")
parser.add_argument('start', help="Starting page index", nargs="?")
parser.add_argument('end', help="Ending page index", nargs="?")
parser.add_argument('--save', action="store_true", help="Save results")
parser.add_argument('--verbose', action="store_true", help="More verbose output")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for pos in ["nouns", "proper nouns"]:
  refpage = "Template:tracking/ru-headword/space-in-headword/%s" % pos
  msg("PROCESSING REFERENCES TO: %s" % refpage)
  for i, page in blib.references(refpage, start, end):
    msg("Page %s %s: Processing" % (i, unicode(page.title())))
    process_page(i, page, args.save, args.verbose)

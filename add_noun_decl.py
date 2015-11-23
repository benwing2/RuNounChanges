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

# FIXME:
#
# 1. (DONE, NEEDS TESTING) Warnings like this should be fixable:
#    Page 99 Дедушка Мороз: WARNING: Can't sub word link [[мороз|Моро́з]] into decl lemma моро́з
# 2. This warning should be fixable:
#    Page 756 десертное вино: WARNING: case nom_sg, existing forms [[десе́ртный|десе́ртное]] [[вино́]] not same as proposed [[десертный|десе́ртное]] [[вино́]]
# 3. Plural nouns
# 4. Multiple inflected nouns, esp. in hyphenated compounds

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam

import rulib as ru
import runounlib as runoun

site = pywikibot.Site()

def msg(text):
  print text.encode("utf-8")

def errmsg(text):
  print >>sys.stderr, text.encode("utf-8")

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    if verbose:
      pagemsg("Expanding text: %s" % tempcall)
    result = site.expand_text(tempcall, title=pagetitle)
    if verbose:
      pagemsg("Raw result is %s" % result)
    if result.startswith('<strong class="error">'):
      result = re.sub("<.*?>", "", result)
      pagemsg("WARNING: Got error: %s" % result)
      return False
    return result

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
      if re.search(u"(ий|ый|ой)$", lemma):
        pagemsg("WARNING: Page doesn't exist, assuming word #%s adjectival: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
        return [("1", wordlink), ("2", "+")], True, None, None
      else:
        pagemsg("WARNING: Page doesn't exist, can't locate decl for word #%s, skipping: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
        return None
    parsed = blib.parse_text(declpage.text)
    decl_templates = []
    for t in parsed.filter_templates():
      if unicode(t.name) in ["ru-noun-table", "ru-decl-adj"]:
        decl_templates.append(t)

    if not decl_templates:
      pagemsg("WARNING: No decl template during decl lookup for word #%s, skipping: lemma=%s, infl=%s" %
          (wordind, lemma, infl))
      return None

    if len(decl_templates) == 1:
      decl_template = decl_templates[0]
    else:
      # Multiple decl templates
      for t in decl_templates:
        if unicode(t.name) == "ru-decl-adj" and re.search(u"(ий|ый|ой)$", lemma):
          pagemsg("WARNING: Multiple decl templates during decl lookup for word #%s, assuming adjectival: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
          decl_template = t
          break
      else:
        pagemsg("WARNING: Multiple decl templates during decl lookup for word #%s and not adjectival, skipping: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
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
    if ru.remove_accents(infl).lower() != lemma.lower():
      pagemsg("WARNING: For word#%s, inflection not same as lemma, probably plural, can't handle yet, skipping: lemma=%s, infl=%s" %
          (wordind, lemma, infl))
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
        pagemsg("WARNING: Found multiword decl during decl lookup for word #%s, skipping: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
        return None
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
      if len(arg_set) > 0 and runoun.arg1_is_stress(arg_set[0]):
        lemma_arg = 1
      if len(arg_set) <= lemma_arg:
        arg_set.append("")
      if not arg_set[lemma_arg] or arg_set[lemma_arg].lower() == infl.lower() or (
          ru.is_monosyllabic(infl) and ru.remove_accents(arg_set[lemma_arg]).lower() ==
          ru.remove_accents(infl).lower()):
        arg_set[lemma_arg] = wordlink
      else:
        pagemsg("WARNING: Can't sub word link %s into decl lemma %s" % (
          wordlink, arg_set[lemma_arg]))
      if numbered_params:
        numbered_params.append("or")
      numbered_params.extend(arg_set)

    # Now gather all params, including named ones.
    params = []
    params.extend((str(i+1), val) for i, val in zip(xrange(len(numbered_params)), numbered_params))
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
        pagemsg("WARNING: Found notes= during decl lookup for word #%s, skipping: lemma=%s, infl=%s, notes=%s" % (
          wordind, lemma, infl, val))
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

  if not headword_template:
    pagemsg("WARNING: Can't find headword template, skipping")
    return

  pagemsg("Found headword template: %s" % unicode(headword_template))

  headword_is_proper = unicode(headword_template.name) == "ru-proper noun"

  headword_trs = blib.process_arg_chain(headword_template, "tr", "tr")
  if headword_trs:
    pagemsg("WARNING: Found headword manual translit, skipping: %s" %
        ",".join(headword_trs))
    return

  headword = getparam(headword_template, "1")
  if "-" in headword:
    pagemsg("WARNING: Can't handle hyphens in headword, yet, skipping")
    return
  for badparam in ["head2", "gen2", "pl2"]:
    val = getparam(headword_template, badparam)
    if val:
      pagemsg("WARNING: Found extra param, can't handle, skipping: %s=%s" % (
        badparam, val))
      return

  # Here we use a capturing split, and treat what we want to capture as
  # the splitting text, backwards from what you'd expect. The separators
  # will fall at 0, 2, ... and the headwords as 1, 3, ... There will be
  # an odd number of items, and the first and last should be empty.
  headwords_separators = re.split(r"(\[\[.*?\]\]|[^ \-]+)", headword)
  if headwords_separators[0] != "" or headwords_separators[-1] != "":
    pagemsg("WARNING: Found junk at beginning or end of headword, skipping")
    return
  headwords = []
  # Separator at index 0 is the separator that goes after the first word
  # and before the second word.
  separators = []
  wordind = 0
  # FIXME, Here we try to handle hyphens, but we'll still have problems with
  # words like изба́-чита́льня with conjoined nouns, both inflected, because
  # we assume only one inflected noun (should be fixable without too much
  # work). We'll also have problems with e.g. пистолет-пулемёт Томпсона,
  # because the words are linked individually but the ru-decl-noun-see
  # has пистолет-пулемёт given as a single entry. We have a check below
  # to try to catch this case, because no inflected nouns will show up.
  for i in xrange(1, len(headwords_separators), 2):
    hword = headwords_separators[i]
    separator = headwords_separators[i+1]
    if separator != " " and separator != "-":
      pagemsg("WARNING: Separator after word #%s isn't a space or hyphen, can't handle: word=<%s>, separator=<%s>" %
          (wordind + 1, hword, separator))
      return
    headwords.append(hword)
    separators.append(separator)

  pagemsg("Found headwords: %s" % " @@ ".join(headwords))

  # Extract lemmas and inflections for each word in headword
  lemmas_infls = []
  saw_unlinked_word = False
  for word in headwords:
    m = re.search(r"^\[\[([^|]+)\|([^|]+)\]\]$", word)
    if m:
      lemma, infl = m.groups()
      lemma = ru.remove_accents(lemma)
    else:
      m = re.search(r"^\[\[([^|]+)\]\]$", word)
      if m:
        infl = m.group(1)
      else:
        infl = word
        saw_unlinked_word = True
      lemma = ru.remove_accents(infl)
    lemmas_infls.append((lemma, infl))

  if see_template:
    pagemsg("Found decl-see template: %s" % unicode(see_template))
    inflected_words = set(ru.remove_accents(blib.remove_links(unicode(x.value)))
        for x in see_template.params)
  else:
    # Try to figure out which words are inflected and which words aren't
    pagemsg("No ru-decl-noun-see template, inferring which headword words are inflected")
    if saw_unlinked_word:
      pagemsg("WARNING: Unlinked word(s) in headword, skipping: %s" % headword)
      return
    inflected_words = set()
    saw_noun = False
    reached_uninflected = False
    wordind = 0
    for word, lemmainfl in zip(headwords, lemmas_infls):
      wordind += 1
      is_inflected = False
      lemma, infl = lemmainfl
      if re.search(u"(ый|ий|ой)$", lemma):
        if re.search(u"(ый|ий|о́й|[ая]́?я|[ое]́?е|[ыи]́?е)$", infl):
          is_inflected = True
          pagemsg("Assuming word #%s is adjectival, inflected: lemma=%s, infl=%s" %
              (wordind, lemma, infl))
          if saw_noun:
            pagemsg("WARNING: Word #%s is adjectival inflected and follows inflected noun: lemma=%s, infl=%s" %
                (wordind, lemma, infl))
        else:
          pagemsg("Assuming word #%s is adjectival, uninflected: lemma=%s, infl=%s" %
              (wordind, lemma, infl))
      elif lemma.lower() == ru.remove_accents(infl.lower()):
        is_inflected = True
        pagemsg("Assuming word #%s is noun, inflected: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
        if saw_noun:
          pagemsg("WARNING: Saw second apparently inflected noun at word #%s, skipping: lemma=%s, infl=%s" %
              (wordind, lemma, infl))
          return
        else:
          saw_noun = True
      else:
        # FIXME, be smarter about plural nouns
        # FIXME, be smarter about nouns conjoined with и, e.g. Адам и Ева,
        # (might not be worth it, only five such nouns)
        pagemsg("Assuming word #%s is non-adjectival, uninflected: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
        if not saw_noun:
          pagemsg("WARNING: No inflected noun in headword, skipping: %s" %
              headword)
          return
      if is_inflected:
        if reached_uninflected:
          pagemsg("WARNING: Word #%s is apparently inflected and follows uninflected words, something might be wrong (or could be accusative after preposition), skipping: lemma=%s, infl=%s" %
                (wordind, lemma, infl))
          # FIXME, compile list where this is allowed
          return
        inflected_words.add(lemma)
      else:
        reached_uninflected = True
        if lemma in inflected_words:
          pagemsg("WARNING: Lemma appears both in inflected and uninflected words, can't handle skipping: lemma=%s (infl=%s at second appearance at word#%s)" %
              (lemma, infl, wordind))

  params = []
  saw_noun = False
  overall_num = None
  overall_anim = None

  wordind = 0
  offset = 0
  for word, lemmainfl in zip(headwords, lemmas_infls):
    wordind += 1
    lemma, infl = lemmainfl
    # If not first word, add _ separator between words
    if wordind > 1:
      if separators[wordind - 2] == "-":
        separator = "-"
      elif separators[wordind - 2] == " ":
        separator = "_"
      else:
        pagemsg("WARNING: Something wrong, separator for word #%2 isn't space or hyphen: <%s>" %
            separators[wordind - 2])
        return
      params.append((str(offset + 1), separator)
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
        overall_anim = anim
        saw_noun = True
      for name, val in wordparams:
        if re.search("^[0-9]+$", name):
          name = str(int(name) + offset)
          num_numbered_params += 1
        params.append((name, val))
      offset += num_numbered_params

    else:
      # Invariable
      if ru.is_unstressed(infl):
        word = "*" + word
      params.append((str(offset + 1), word))
      params.append((str(offset + 2), "$"))
      offset += 2

  if not saw_noun:
    pagemsg(u"WARNING: No inflected nouns, something might be wrong (e.g. the пистоле́т-пулемёт То́мпсона problem), can't handle, skipping")
    return

  genders = blib.process_arg_chain(headword_template, "2", "g")

  saw_in = -1
  saw_an = -1
  for i,g in enumerate(genders):
    if re.search(r"\bin\b", g) and saw_in < 0:
      saw_in = i
    if re.search(r"\ban\b", g) and saw_an < 0:
      saw_an = i
  if saw_in >= 0 and saw_an >= 0 and saw_in < saw_an:
    headword_anim = "ia"
  elif saw_in >= 0 and saw_an >= 0:
    headword_anim = "ai"
  elif saw_an >= 0:
    headword_anim = "an"
  elif saw_in >= 0:
    headword_anim = "in"
  else:
    headword_anim = overall_anim

  if overall_anim in ["i", "in", "inan"] or not overall_anim:
    overall_anim = "in"
  elif overall_anim in ["a", "an", "anim"]:
    overall_anim = "an"

  if overall_anim != headword_anim:
    pagemsg("WARNING: Overriding decl anim %s with headword anim %s" % (
      overall_anim, headword_anim))
  if headword_anim and headword_anim != "in":
    params.append(("a", headword_anim))

  if overall_num:
    overall_num = overall_num[0:1]
    canon_nums = {"s":"sg", "p":"pl", "b":"both"}
    if overall_num in canon_nums:
      overall_num = canon_nums[overall_num]
    else:
      pagemsg("WARNING: Bogus value for overall num in decl, skipping: %s" % overall_num)
      return
    if headword_is_proper:
      plval = getparam(headword_template, "4")
      if plval and plval != "-":
        if overall_num != "both":
          pagemsg("WARNING: Proper noun is apparently sg/pl but main noun not, skipping: %s" %
              headword)
          return
      elif overall_num == "both":
        pagemsg("WARNING: Proper noun has sg/pl main noun underlying it, assuming singular: %s" %
            headword)
        overall_num = None
      elif overall_num == "sg":
        overall_num = None
    if overall_num:
      params.append(("n", overall_num))

  generate_template = (blib.parse_text("{{ru-generate-noun-args}}").
      filter_templates()[0])
  for name, value in params:
    generate_template.add(name, value)
  proposed_template_text = unicode(generate_template)
  if headword_is_proper:
    proposed_template_text = re.sub(r"^\{\{ru-generate-noun-args",
        "{{ru-proper noun+", proposed_template_text)
  else:
    proposed_template_text = re.sub(r"^\{\{ru-generate-noun-args",
        "{{ru-noun+", proposed_template_text)
  proposed_decl_text = re.sub(r"^\{\{ru-generate-noun-args",
        "{{ru-noun-table", unicode(generate_template))

  def pagemsg_with_proposed(text):
    pagemsg("Proposed new template (WARNING, omits explicit gender and params to preserve from old template): %s" % proposed_template_text)
    pagemsg(text)

  if headword_is_proper:
    generate_template.add("ndef", "sg")
  generate_result = expand_text(unicode(generate_template))
  if not generate_result:
    pagemsg_with_proposed("WARNING: Error generating noun args, skipping")
    return
  args = ru.split_generate_args(generate_result)

  genders = runoun.check_old_noun_headword_forms(headword_template, args,
      subpagetitle, pagemsg_with_proposed)
  if genders == None:
    return None

  orig_headword_template = unicode(headword_template)
  params_to_preserve = runoun.fix_old_headword_params(headword_template,
      params, genders, pagemsg_with_proposed)
  if params_to_preserve == None:
    return None

  headword_template.params.extend(params_to_preserve)

  notes = []
  ru_noun_changed = 0
  ru_proper_noun_changed = 0
  if unicode(headword_template.name) == "ru-noun":
    headword_template.name = "ru-noun+"
    notes.append("convert multi-word ru-noun to ru-noun+ by looking up decls")
  else:
    headword_template.name = "ru-proper noun+"
    notes.append("convert multi-word ru-proper noun to ru-proper noun+ by looking up decls")

  pagemsg("Replacing headword %s with %s" % (orig_headword_template, unicode(headword_template)))

  newtext = unicode(parsed)
  if not see_template:
    if "==Declension==" in newtext:
      pagemsg("WARNING: No ru-decl-noun-see template, but found declension section, not adding new declension, proposed declension follows: %s" %
          proposed_decl_text)
    else:
      nounsecs = re.findall("^===(?:Noun|Proper noun)===$", newtext, re.M)
      if len(nounsecs) == 0:
        pagemsg("WARNING: Found no noun sections, not adding new declension, proposed declension follows: %s" %
            proposed_decl_text)
      elif len(nounsecs) > 1:
        pagemsg("WARNING: Found multiple noun sections, not adding new declension, proposed declension follows: %s" %
            proposed_decl_text)
      else:
        text = newtext
        # Sub in after Noun or Proper noun section, before a following section
        # (====Synonyms====) or a wikilink ([[pl:гонка вооружений]]).
        newtext = re.sub(r"^(===(?:Noun|Proper noun)===$.*?)^(==|\[\[)",
            r"\1====Declension====\n%s\n\n" % proposed_decl_text, 1, re.M|re.S)
        if text == newtext:
          pagemsg("WARNING: Something wrong, can't sub in new declension, proposed declension follows: %s" %
              proposed_decl_text)
        else:
          pagemsg("Subbed in new declension: %s" % proposed_decl_text)
          notes.append("create declension from headword")
          if verbose:
            pagemsg("Replaced <%s> with <%s>" % text, newtext)

  comment = "; ".join(notes)
  if save:
    pagemsg("Saving with comment = %s" % comment)
    page.text = newtext
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

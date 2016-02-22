#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Replace as follows:
#
# * Replace uses of {{temp|reference-book}} with either {{temp|cite-book}} (if it is used within <nowiki><ref></nowiki> tags or in <code><nowiki>==References==</nowiki></code> sections) or {{temp|quote-book}} (if it is used elsewhere, mostly to provide quotations for definitions of lemmas). The following parameters may need changing:
# ** If {{para|origyear}} and {{para|year}} are used together, {{para|origyear}} → {{para|year}} and {{para|year}} → {{para|year_published}}.
# ** {{para|origdate}} → {{para|date}}.
# ** {{para|origmonth}} → {{para|month}}.
# ** <code>id=ISBN</code> → <code>isbn=</code>.
# * Replace uses of {{temp|cite wikipedia}} with {{temp|quote-wikipedia}}.
# * Replace uses of {{temp|cite-usenet}} and {{temp|quote-usenet}} with {{temp|quote-newsgroup}}.
# ** There appear to be some uses of {{temp|cite-usenet}} with the parameter "<tt>|prefix=#</tt>" or "<tt>|prefix=#*</tt>". These should be changed to "<tt><nowiki>#* {{quote-newsgroup|...</nowiki></tt>".
# * Replace uses of {{temp|cite book}} (a redirect) with {{temp|cite-book}}.
# * Replace uses of {{temp|cite journal}} (a redirect) with {{temp|cite-journal}}.
# * Replace uses of {{temp|cite news}} (a redirect) with {{temp|cite-journal}}.
# * Replace uses of {{temp|cite web}} (a redirect) with {{temp|cite-web}}.
# * Replace uses of {{temp|quote-news}} (a redirect) with {{temp|quote-journal}}.
# * Replace uses of {{temp|reference-journal}} (a redirect) with either {{temp|cite-journal}} (if it is used within <nowiki><ref></nowiki> tags or in <code><nowiki>==References==</nowiki></code> sections) or {{temp|quote-journal}} (if it is used elsewhere).
# * Replace uses of {{temp|reference-news}} (a redirect) with either {{temp|cite-journal}} (if it is used within <nowiki><ref></nowiki> tags or in <code><nowiki>==References==</nowiki></code> sections) or {{temp|quote-journal}} (if it is used elsewhere).
# * Replace uses of {{temp|reference-song}} (a redirect) with {{temp|quote-song}}.
# * Replace uses of {{temp|reference-us-patent}} (a redirect) with {{temp|quote-us-patent}}.
# * Replace uses of {{temp|reference-video}} (a redirect) with {{temp|quote-video}}.

import pywikibot, re, sys, codecs, argparse
import mwparserfromhell as mw

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site

import rulib

replace_templates = [
    "reference-book", "cite wikipedia",
    "cite-usenet", "quote-usenet",
    "cite book", "cite journal", "cite news", "cite web",
    "quote-news", "reference-journal", "reference-news", "reference-song",
    "reference-us-patent", "reference-video"
    ]

simple_replace = [
    ("cite wikipedia", "quote-wikipedia"),
    ("cite book", "cite-book"),
    ("cite journal", "cite-journal"),
    ("cite news", "cite-journal"),
    ("cite web", "cite-web"),
    ("quote-news", "quote-journal"),
    ("reference-song", "quote-song"),
    ("reference-us-patent", "quote-us-patent"),
    ("reference-video", "quote-video"),
]

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if not page.exists():
    pagemsg("WARNING: Page doesn't exist")
    return

  if ":" in pagetitle and not re.search(
      "^(Citations|Appendix|Reconstruction|Transwiki|Talk|Wiktionary|[A-Za-z]+ talk):", pagetitle):
    pagemsg("WARNING: Colon in page title and not a recognized namespace to include, skipping page")
    return

  text = unicode(page.text)
  notes = []

  subsections = re.split("(^==.*==\n)", text, 0, re.M)
  newtext = text

  def move_param(t, fr, to, frob_from=None):
    if t.has(fr):
      oldval = getparam(t, fr)
      if not oldval.strip():
        rmparam(t, fr)
        pagemsg("Removing blank param %s" % fr)
        return
      if frob_from:
        newval = frob_from(oldval)
        if not newval or not newval.strip():
          return
      else:
        newval = oldval

      if getparam(t, to).strip():
          pagemsg("WARNING: Would replace %s= -> %s= but %s= is already present: %s"
              % (fr, to, to, unicode(t)))
      elif oldval != newval:
        rmparam(t, to) # in case of blank param
        tfr = t.get(fr)
        tfr.name = to
        tfr.value = newval
        pagemsg("%s=%s -> %s=%s" % (fr, oldval.replace("\n", r"\n"), to,
          newval.replace("\n", r"\n")))
      else:
        rmparam(t, to) # in case of blank param
        t.get(fr).name = to
        pagemsg("%s -> %s" % (fr, to))

  def fix_page_params(t):
    origt = unicode(t)
    for param in ["page", "pages"]:
      pageval = getparam(t, param)
      if re.search(r"^\s*pp?\.\s*", pageval):
        pageval = re.sub(r"^(\s*)pp?\.\s*", r"\1", pageval)
        t.add(param, pageval)
        notes.append("remove p(p). from %s=" % pageval)
        pagemsg("remove p(p). from %s=" % pageval)
    if re.search(r"^[0-9]+$", getparam(t, "pages").strip()):
      move_param(t, "pages", "page")
    if re.search(r"^[0-9]+[-–—]$", getparam(t, "page").strip()):
      move_param(t, "page", "pages")
    return origt != unicode(t)

  def fix_cite_book_params(t):
    origt = unicode(t)
    if getparam(t, "origyear").strip() and getparam(t, "year").strip():
      if getparam(t, "year_published"):
        pagemsg("WARNING: Would set year_published= but is already present: %s"
            % unicode(t))
      else:
        rmparam(t, "year_published") # in case of blank param
        t.get("year").name = "year_published"
        t.get("origyear").name = "year"
        pagemsg("year -> year_published, origyear -> year")
    move_param(t, "origdate", "date")
    move_param(t, "origmonth", "month")
    def frob_isbn(idval):
      isbn_re = r"^(\s*)(10-ISBN +|ISBN-13 +|ISBN:? +|ISBN[-=] *)"
      if re.search(isbn_re, idval, re.I):
        return re.sub(isbn_re, r"\1", idval, 0, re.I)
      elif re.search(r"^[0-9]", idval.strip()):
        return idval
      else:
        pagemsg("WARNING: Would replace id= -> isbn= but id=%s doesn't begin with 'ISBN '" %
            idval.replace("\n", r"\n"))
        return None
    move_param(t, "id", "isbn", frob_isbn)
    fix_page_params(t)
    return origt != unicode(t)

  def replace_in_reference(parsed, in_what):
    for t in parsed.filter_templates():
      tname = unicode(t.name)
      origt = unicode(t)
      if tname.strip() in ["reference-journal", "reference-news"]:
        set_template_name(t, "cite-journal", tname)
        pagemsg("%s -> cite-journal" % tname.strip())
        notes.append("%s -> cite-journal" % tname.strip())
        fix_page_params(t)
        pagemsg("Replacing %s with %s in %s" %
            (origt, unicode(t), in_what))
      if tname.strip() == "reference-book":
        set_template_name(t, "cite-book", tname)
        pagemsg("reference-book -> cite-book")
        fixed_params = fix_cite_book_params(t)
        notes.append("reference-book -> cite-book%s" % (
          fixed_params and " and fix book cite params" or ""))
        pagemsg("Replacing %s with %s in %s" %
            (origt, unicode(t), in_what))

  for j in xrange(0, len(subsections), 2):
    parsed = blib.parse_text(subsections[j])
    if j > 0 and re.search(r"^===*References===*\n", subsections[j-1]):
      replace_in_reference(parsed, "==References== section")
      subsections[j] = unicode(parsed)
    else:
      for t in parsed.filter_tags():
        if unicode(t.tag) == "ref":
          tagparsed = mw.wikicode.Wikicode([t])
          replace_in_reference(tagparsed, "<ref>")
          subsections[j] = unicode(parsed)
    need_to_replace_double_quote_prefixes = False
    for t in parsed.filter_templates():
      tname = unicode(t.name)
      origt = unicode(t)
      for fr, to in simple_replace:
        if tname.strip() == fr:
          set_template_name(t, to, tname)
          pagemsg("%s -> %s" % (fr, to))
          notes.append("%s -> %s" % (fr, to))
          fix_page_params(t)
          pagemsg("Replacing %s with %s" % (origt, unicode(t)))
      if tname.strip() in ["reference-journal", "reference-news"]:
        set_template_name(t, "quote-journal", tname)
        pagemsg("%s -> quote-journal" % tname.strip())
        notes.append("%s -> quote-journal" % tname.strip())
        fix_page_params(t)
        pagemsg("Replacing %s with %s outside of reference section" %
            (origt, unicode(t)))
      if tname.strip() == "reference-book":
        set_template_name(t, "quote-book", tname)
        pagemsg("reference-book -> cite-book")
        fixed_params = fix_cite_book_params(t)
        notes.append("reference-book -> cite-book%s" % (
          fixed_params and " and fix book cite params" or ""))
        pagemsg("Replacing %s with %s outside of reference section" %
            (origt, unicode(t)))
      if tname.strip() in ["cite-usenet", "quote-usenet"]:
        move_param(t, "text", "passage")
        set_template_name(t, "quote-newsgroup", tname)
        pagemsg("%s -> quote-newsgroup" % tname.strip())
        prefix = getparam(t, "prefix").strip()
        removed_prefix = False
        if prefix:
          if prefix in ["#", "#*"]:
            parsed.insert_before(t, "#* ")
            rmparam(t, "prefix")
            pagemsg("remove prefix=%s, insert #* before template" % prefix)
            need_to_replace_double_quote_prefixes = True
            removed_prefix = True
          else:
            pagemsg("WARNING: Found prefix=%s, not # or #*: %s" %
                (prefix, unicode(t)))
        notes.append("%s -> quote-newsgroup%s" % (tname.strip(),
          removed_prefix and
            ", remove prefix=%s, insert #* before template" % prefix or ""))
        pagemsg("Replacing %s with %s outside of reference section" %
            (origt, unicode(t)))
    subsections[j] = unicode(parsed)
    if need_to_replace_double_quote_prefixes:
      newval = re.sub("^#\* #\* ", "#* ", subsections[j], 0, re.M)
      if newval != subsections[j]:
        notes.append("remove double #* prefix")
        pagemsg("Removed double #* prefix")
      subsections[j] = newval
  newtext = "".join(subsections)

  if text != newtext:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, newtext))
    assert notes
    comment = "; ".join(blib.group_notes(notes))
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = newtext
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

if __name__ == "__main__":
  parser = blib.create_argparser("Fix old cite/quote/reference templates")
  args = parser.parse_args()
  start, end = blib.get_args(args.start, args.end)

  for template in replace_templates:
    msg("Processing references to Template:%s" % template)
    errmsg("Processing references to Template:%s" % template)
    for i, page in blib.references("Template:%s" % template, start, end,
        includelinks=True):
      process_page(i, page, args.save, args.verbose)

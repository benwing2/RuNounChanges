#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Replace quote-poem -> quote-book and change params.
# Replace quote-magazine and quote-news -> quote-journal.
# Replace quote-Don Quixote -> RQ:Don Quixote.

import pywikibot, re, sys, argparse
import mwparserfromhell as mw

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site, tname, pname

quote_templates = [
  "quote-av",
  "quote-book",
  "quote-hansard",
  "quote-journal",
  "quote-mailing list",
  "quote-newsgroup",
  "quote-song",
  "quote-text",
  "quote-us-patent",
  "quote-video game",
  "quote-web",
  "quote-wikipedia",
]

recognized_named_params_list = [
  "accessdate", "accessdaymonth", "accessmonthday", "accessmonth", "accessyear", "actor", "album", "archivedate",
  "archiveurl", "article", "artist", "at", "author", "authorlabel", "authorlink", "authors", "autodate", "bibcode",
  "blog", "book", "brackets", "by", "chapter", "chapterurl", "city", "coauthors", "column", "columns", "columnurl",
  "column_end", "column_start", "composer", "date", "debate", "director", "directors", "DOI", "doi", "edition",
  "editor", "editors", "email", "entry", "entryurl", "episode", "first", "footer", "format", "genre", "googleid",
  "group", "house", "id", "indent", "ISBN", "isbn", "ISSN", "issn", "issue", "journal", "jstor", "lang", "last",
  "laydate", "laysource", "laysummary", "LCCN", "lccn", "line", "lines", "lit", "location", "lyricist",
  "lyrics-translator", "magazine", "mainauthor", "medium", "month", "network", "newsgroup", "newspaper", "newversion",
  "nocat", "nodate", "note", "notitle", "number", "OCLC", "oclc", "ol", "origdate", "original", "origmonth", "origyear",
  "other", "others", "page", "pages", "pageref", "pageurl", "page_end", "page_start", "passage", "periodical", "PMID",
  "pmid", "publisher", "quote", "quoted_in", "quotee", "report", "role", "scene", "season", "section", "sectionurl",
  "series", "seriesvolume", "site", "sort", "speaker", "ssrn", "start_date", "start_year", "subst", "t", "termlang",
  "text", "time", "title", "titleurl", "tr", "trans", "trans-album", "trans-chapter", "trans-entry", "trans-episode",
  "trans-journal", "trans-title", "trans-work", "transcription", "translation", "translator", "translators",
  "transliteration", "ts", "type", "url", "urls", "url-access", "url-status", "version", "volume", "volume_plain",
  "work", "worklang", "writer", "writers", "year", "year_published", "2ndauthor", "2ndauthorlink", "2ndfirst", "2ndlast"
]

recognized_named_params = set(p for param in recognized_named_params_list for p in [param, param + "2"])

unrecognized_named_params_list = [
  "archive-date", "archive_date", "archiv-datum", "access", "access-date", "accessed", "archiveorg", "archive-url",
  "asin", "author1", "digitized", "fulltext", "i2", "isbn10", "meeting", "new version", "newsfeed", "oldurl",
  "originalpassage", "p", "paragraph", "part", "pos", "producer", "publish-date", "rfc", "retrieved", "stanza", "via",
  "website",
  # misspellings:
  "Chapter", "colunm", "Id", "IISBN", "isn", "Jnewsgroup", "oage", "Page", "pge", "Section", "tirle", "year_publsihed",
]

unrecognized_named_params = set(p for param in unrecognized_named_params_list for p in [param, param + "2"])

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if ":" in pagetitle and not re.search(
      "^(Citations|Appendix|Reconstruction|Transwiki|Talk|Wiktionary|[A-Za-z]+ talk):", pagetitle):
    pagemsg("WARNING: Colon in page title and not a recognized namespace to include, skipping page")
    return None, None

  notes = []

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    changed = False

    def move_params(params, frob_from=None):
      tparams = []
      for param in t.params:
        tparams.append((str(param.name), str(param.value), param.showkey))
      for fr, to in params:
        if t.has(fr):
          oldval = getparam(t, fr)
          if not oldval.strip():
            rmparam(t, fr)
            pagemsg("%s: Removing blank param %s" % (tn, fr))
            continue
          if frob_from:
            newval = frob_from(oldval)
            if not newval or not newval.strip():
              continue
          else:
            newval = oldval

          existing_val = getparam(t, to).strip()
          if existing_val:
              pagemsg("WARNING: Would replace %s=%s -> %s= but %s=%s is already present: %s"
                  % (fr, oldval.strip(), to, to, existing_val, str(t)))
              # put back old params
              del t.params[:]
              for (pn, pv, showkey) in tparams:
                t.add(pn, pv, showkey=showkey, preserve_spacing=False)
              return
          elif oldval != newval:
            rmparam(t, to) # in case of blank param
            # If either old or new name is a number, use remove/add to automatically set the
            # showkey value properly; else it's safe to just change the name of the param,
            # which will preserve its location.
            if re.search("^[0-9]+$", fr) or re.search("^[0-9]+$", to):
              t.add(to, newval, before=fr, preserve_spacing=False)
              rmparam(t, fr)
            else:
              tfr = t.get(fr)
              tfr.name = to
              tfr.value = newval
            pagemsg("%s: %s=%s -> %s=%s" % (tn, fr, oldval.replace("\n", r"\n"), to, newval.replace("\n", r"\n")))
          else:
            rmparam(t, to) # in case of blank param
            # See comment above.
            if re.search("^[0-9]+$", fr) or re.search("^[0-9]+$", to):
              t.add(to, newval, before=fr, preserve_spacing=False)
              rmparam(t, fr)
            else:
              t.get(fr).name = to
            pagemsg("%s: %s -> %s" % (tn, fr, to))

    if tn in ["quote-magazine", "quote-news"]:
      blib.set_template_name(t, "quote-journal")
      notes.append("%s -> quote-journal" % tn)
      changed = True
    if tn in ["quote-Don Quixote"]:
      blib.set_template_name(t, "RQ:Don Quixote")
      notes.append("quote-Don Quixote -> RQ:Don Quixote")
      changed = True

    def escape_newline(val):
      return val.replace("\n", r"\n")

    must_continue = False
    if tn in quote_templates:
      last_url_like = None
      last_url_like_value = None
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if pn in unrecognized_named_params:
          pagemsg("WARNING: Saw bad (unrecognized or misspelled) param %s=%s: %s" % (
            pn, escape_newline(pv), escape_newline(str(t))))
        if ((re.search("^[0-9]+$", pn) or pn not in recognized_named_params) and pn not in unrecognized_named_params
            and pv.strip() and last_url_like and not (pn in ["6", "7"] and re.search("^[0-9]+$", pv))):
          pagemsg("WARNING: Possible unescaped vertical bar, saw %s=%s after %s=%s: %s" % (
            pn, escape_newline(pv), last_url_like, escape_newline(last_url_like_value), escape_newline(str(t))))
          must_continue = True
          break
        if "://" in pv: # re.search("^(url|section)[0-9]*$", pn):
          last_url_like = pn
          last_url_like_value = pv
        else:
          last_url_like = None
          last_url_like_value = None
    if must_continue:
      continue

    if tn in quote_templates:
      params_to_move = [("trans", "tlr")]
      for trans_param in ["title", "chapter", "journal", "work", "album", "author", "entry", "episode",
                          "lyricist", "section", "series", "section", "newspaper"]:
        params_to_move.append(("trans-%s" % trans_param, "%s-t" % trans_param))
        params_to_move.append(("trans-%s2" % trans_param, "%s2-t" % trans_param))
        params_to_move.append(("trans-%s3" % trans_param, "%s3-t" % trans_param))
        move_params(params_to_move)

    if tn == "quote-poem":
      move_params([
        ("title", "chapter"),
        ("poem", "chapter"),
        ("work", "title"),
        ("7", "t"),
        ("6", "text"),
        ("5", "url"),
        ("4", "title"),
        ("3", "chapter"),
      ])
      blib.set_template_name(t, "quote-book")
      changed = origt != str(t)
      if changed:
        notes.append("quote-poem -> quote-book with fixed params")
    if tn == "quote-av":
      move_params([
        ("9", "t"),
        ("8", "text"),
        ("7", "time"),
        ("6", "number"),
        ("5", "season"),
        ("4", "title"),
        ("3", "actor"),
        ("2", "year"),
      ])
      changed = origt != str(t)
      if changed:
        notes.append("rename numbered params in {{quote-av}} to named params and remove blank ones")
    if tn == "quote-book":
      move_params([
        ("8", "t"),
        ("7", "text"),
        ("6", "page"),
        ("5", "url"),
        ("4", "title"),
        ("3", "author"),
        ("2", "year"),
      ])
      changed = origt != str(t)
      if changed:
        notes.append("rename numbered params in {{quote-book}} to named params and remove blank ones")
    if tn == "quote-hansard":
      move_params([
        ("10", "t"),
        ("9", "text"),
        ("8", "column"),
        ("7", "page"),
        ("6", "url"),
        ("5", "report"),
        ("4", "debate"),
        ("3", "speaker"),
        ("2", "year"),
      ])
      changed = origt != str(t)
      if changed:
        notes.append("rename numbered params in {{quote-hansard}} to named params and remove blank ones")
    if tn == "quote-journal":
      move_params([
        ("9", "t"),
        ("8", "text"),
        ("7", "page"),
        ("6", "url"),
        ("5", "journal"),
        ("4", "title"),
        ("3", "author"),
        ("2", "year"),
      ])
      changed = origt != str(t)
      if changed:
        notes.append("rename numbered params in {{quote-journal}} to named params and remove blank ones")
    if tn == "quote-mailing list":
      move_params([
        ("8", "t"),
        ("7", "text"),
        ("6", "url"),
        ("5", "list"),
        ("4", "title"),
        ("3", "author"),
        ("2", "date"),
      ])
      changed = origt != str(t)
      if changed:
        notes.append("rename numbered params in {{quote-mailing list}} to named params and remove blank ones")
    if tn == "quote-newsgroup":
      move_params([
        ("8", "t"),
        ("7", "text"),
        ("6", "url"),
        ("5", "newsgroup"),
        ("4", "title"),
        ("3", "author"),
        ("2", "date"),
      ])
      changed = origt != str(t)
      if changed:
        notes.append("rename numbered params in {{quote-newsgroup}} to named params and remove blank ones")
    if tn == "quote-song":
      move_params([
        ("8", "t"),
        ("7", "text"),
        ("6", "url"),
        ("5", "album"),
        ("4", "title"),
        ("3", "author"),
        ("2", "year"),
      ])
      changed = origt != str(t)
      if changed:
        notes.append("rename numbered params in {{quote-song}} to named params and remove blank ones")
    if tn == "quote-text":
      move_params([
        ("8", "t"),
        ("7", "text"),
        ("6", "page"),
        ("5", "url"),
        ("4", "title"),
        ("3", "author"),
        ("2", "year"),
      ])
      changed = origt != str(t)
      if changed:
        notes.append("rename numbered params in {{quote-text}} to named params and remove blank ones")
    if tn == "quote-us-patent":
      move_params([
        ("8", "t"),
        ("7", "text"),
        ("6", "page"),
        ("5", "number"),
        ("4", "title"),
        ("3", "author"),
        ("2", "year"),
      ])
      changed = origt != str(t)
      if changed:
        notes.append("rename numbered params in {{quote-us-patent}} to named params and remove blank ones")
    if tn == "quote-video game":
      move_params([
        ("8", "t"),
        ("7", "text"),
        ("6", "level"),
        ("5", "platform"),
        ("4", "title"),
        ("3", "author"),
        ("2", "date"),
      ])
      changed = origt != str(t)
      if changed:
        notes.append("rename numbered params in {{quote-video game}} to named params and remove blank ones")
    if tn == "quote-web":
      move_params([
        ("8", "t"),
        ("7", "text"),
        ("6", "url"),
        ("5", "work"),
        ("4", "title"),
        ("3", "author"),
        ("2", "date"),
      ])
      changed = origt != str(t)
      if changed:
        notes.append("rename numbered params in {{quote-web}} to named params and remove blank ones")

    if changed:
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("quote-poem -> quote-book with changed params; quote-magazine/quote-news -> quote-journal; quote-Don Quixote -> RQ:Don Quixote",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:quote-poem", "Template:quote-magazine", "Template:quote-news", "Template:quote-Don Quixote"])

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site, tname, pname
from collections import defaultdict

quote_templates_by_highest_numbered_param = {
  "quote-av": 9,
  "quote-book": 8,
  "quote-hansard": 10,
  "quote-journal": 9,
  "quote-mailing list": 8,
  "quote-newsgroup": 8,
  "quote-song": 8,
  "quote-text": 8,
  "quote-us-patent": 8,
  "quote-video game": 8,
  "quote-web": 8,
  "quote-wikipedia": 1,
}

quote_templates = set(quote_templates_by_highest_numbered_param.keys())

recognized_named_params_1_to_n_list = [
  "author", "last", "first", "authorlink", "trans-author", "trans-last", "trans-first", "trans-authorlink"
]

recognized_named_params_1_to_2_list = [
  "chapter", "chapterurl", "trans-chapter", "notitle", "trans", "translator", "translators", "editor", "editors",
  "mainauthor", "title", "trans-title", "series", "seriesvolume", "archiveurl", "url", "urls", "edition", "volume",
  "volume_plain", "issue", "lang", "worklang", "termlang", "genre", "format", "others", "quoted_in", "city", "location",
  "publisher", "original", "by", "type", "year_published", "date", "year", "bibcode", "doi", "isbn", "issn", "jstor",
  "lccn", "oclc", "ol", "pmid", "ssrn", "id", "archivedate", "accessdate", "nodate", "laysummary", "laysource",
  "laydate", "section", "sectionurl", "line", "lines", "page", "pages", "pageurl", "column", "columns", "columnurl",
  "other",
]

recognized_named_params_list = [
  "accessdaymonth", "accessmonthday", "accessmonth", "accessyear", "actor", "album",
  "article", "artist", "at", "authorlabel", "authors", "autodate",
  "blog", "book", "brackets", "coauthors",
  "column_end", "column_start", "composer", "debate", "developer", "director", "directors", "DOI",
  "email", "entry", "entryurl", "episode", "footer",
  "googleid", "group", "house", "indent", "ISBN", "ISSN", "issue", "inventor", "journal",
  "LCCN", "level", "list", "lit",
  "lyricist", "lyrics-translator", "magazine", "medium", "month", "network", "newsgroup",
  "newspaper", "newversion", "nocat", "note", "number", "OCLC", "OL", "origdate",
  "origmonth", "origyear", "pageref", "page_end",
  "page_start", "passage", "people", "periodical", "platform", "PMID", "quote",
  "quotee", "report", "revision", "role", "roles", "scene", "season",
  "site", "sort", "speaker", "start_date", "start_year", "subst", "t", "text", "time",
  "titleurl", "tr", "trans", "trans-album", "trans-entry", "trans-episode", "trans-journal",
  "trans-work", "transcription", "translation", "transliteration", "ts",
  "url-access", "url-status", "version", "vol", "work",
  "writer", "writers", "2ndauthor", "2ndauthorlink", "2ndfirst", "2ndlast"
]

def make_all_param_set(params, highest_ind):
  return set(param + ("" if ind == 1 else str(ind)) for param in params for ind in range(1, highest_ind + 1))

recognized_named_params = (
  make_all_param_set(recognized_named_params_1_to_n_list, 30) |
  make_all_param_set(recognized_named_params_1_to_2_list, 2) |
  set(recognized_named_params_list)
)

recognized_named_params_list_longest_to_shortest = sorted(list(recognized_named_params), key=lambda x:-len(x))
recognized_named_params_re = "(%s)" % "|".join(recognized_named_params_list_longest_to_shortest)

count_recognized_named_params = defaultdict(int)


unrecognized_after_url_named_params_list = [
  "archive-date", "archive_date", "archiv-datum", "access", "access-date", "accessed", "archiveorg", "archive-url",
  "asin", "author1", "digitized", "edition_plain", "fulltext", "i2", "isbn10", "meeting", "new version", "newsfeed", "oldurl",
  "originalpassage", "p", "paragraph", "part", "pos", "producer", "publish-date", "rfc", "retrieved", "stanza", "via",
  "website",
  # misspellings:
  "Chapter", "colunm", "Id", "IISBN", "isn", "Jnewsgroup", "oage", "Page", "pge", "Section", "tirle", "ur", "year_publsihed",
]
unrecognized_after_url_named_params = set(unrecognized_after_url_named_params_list)

count_numbered_params = defaultdict(int)
count_unhandled_params = defaultdict(int)

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

    def escape_newline(val):
      return val.replace("\n", r"\n")

    def move_params(params, frob_from=None, no_notes=False):
      this_notes = []
      tparams = []
      for param in t.params:
        tparams.append((str(param.name), str(param.value), param.showkey))
      for fr, to in params:
        if t.has(fr):
          oldval = getparam(t, fr)
          if not oldval.strip():
            rmparam(t, fr)
            pagemsg("%s: Removing blank param %s" % (tn, fr))
            this_notes.append("remove blank %s= from {{%s}}" % (fr, tn))
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
            pagemsg("%s: %s=%s -> %s=%s" % (tn, fr, escape_newline(oldval), to, escape_newline(newval)))
            this_notes.append("move %s=%s to %s=%s in {{%s}}"
              % (fr, escape_newline(oldval), to, escape_newline(newval), tn))
          else:
            rmparam(t, to) # in case of blank param
            # See comment above.
            if re.search("^[0-9]+$", fr) or re.search("^[0-9]+$", to):
              t.add(to, newval, before=fr, preserve_spacing=False)
              rmparam(t, fr)
            else:
              t.get(fr).name = to
            pagemsg("%s: %s -> %s" % (tn, fr, to))
            this_notes.append("rename %s= -> %s= in {{%s}}" % (fr, to, tn))
      if not no_notes:
        notes.extend(this_notes)

    if tn in quote_templates:
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if re.search("^[0-9]+$", pn):
          pnnum = int(pn)
          if pnnum <= quote_templates_by_highest_numbered_param[tn]:
            count_numbered_params[pn] += 1
            if pn != "1":
              pvs = pv.strip()
              m = re.search("^%s" % recognized_named_params_re, pvs)
              if m:
                beginparam = m.group(1)
                if len(beginparam) >= 4:
                  if re.search("^%s([A-Za-z0-9]| [^ A-Z0-9])" % beginparam, pvs):
                    pagemsg("WARNING: Probable missing equal sign in %s=%s: %s" % (pn, escape_newline(pv), escape_newline(str(t))))
              # Too many false positives, not enough real hits
              #m = re.search("%s$" % recognized_named_params_re, pvs)
              #if m:
              #  endparam = m.group(1)
              #  if len(endparam) >= 6:
              #    if re.search("([A-Za-z0-9]|[^ a-z] )%s$" % endparam, pvs):
              #      pagemsg("WARNING: Probable missing equal sign in %s=%s: %s" % (pn, escape_newline(pv), escape_newline(str(t))))
          else:
            pagemsg("WARNING: Saw unhandled param %s=%s: %s" % (pn, escape_newline(pv), escape_newline(str(t))))
            count_unhandled_params["%s:%s" % (pn, tn)] += 1
        elif pn in recognized_named_params:
          count_recognized_named_params[pn] += 1
        else:
          pagemsg("WARNING: Saw unhandled param %s=%s: %s" % (pn, escape_newline(pv), escape_newline(str(t))))
          count_unhandled_params[pn] += 1

    if args.do_old_renames:
      if tn in ["quote-magazine", "quote-news"]:
        blib.set_template_name(t, "quote-journal")
        notes.append("%s -> quote-journal" % tn)
        changed = True
      if tn in ["quote-Don Quixote"]:
        blib.set_template_name(t, "RQ:Don Quixote")
        notes.append("quote-Don Quixote -> RQ:Don Quixote")
        changed = True
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
        ], no_notes=True)
        blib.set_template_name(t, "quote-book")
        changed = origt != str(t)
        if changed:
          notes.append("quote-poem -> quote-book with fixed params")

    if args.rename_bad_params:
      if tn in quote_templates:
        params_to_move = [
          ("access-date", "accessdate"),
          ("acessdate", "accessdate"),
          ("accessed", "accessdate"),
          ("archive-date", "archivedate"),
          ("archive_date", "archivedate"),
          ("archive-url", "archiveurl"),
          ("auhtor", "author"),
          ("auther", "author"),
          ("Author", "author"),
          ("author1", "author"),
          ("author-link", "authorlink"),
          ("authorlink1", "authorlink"),
          ("authorklink", "authorlink"),
          ("autorlink", "authorlink"),
          ("autor", "author"),
          ("first1", "first"),
          ("last1", "last"),
          ("chaper", "chapter"),
          ("chapter-trans", "trans-chapter"),
          ("coauthor", "coauthors"),
          ("co-author", "coauthors"),
          ("co-authors", "coauthors"),
          ("Date", "date"),
          ("editon", "edition"),
          ("Edition", "edition"),
          ("editor1", "editor"),
          ("edtior", "editor"),
          ("edtiors", "editors"),
          ("IBSN", "ISBN"),
          ("ibsn", "isbn"),
          ("ISBN2", "isbn2"),
          ("OCLC2", "oclc2"),
          ("Issue", "issue"),
          ("issuse", "issue"),
          #("link", "url"), # do manually
          ("Location", "location"),
          ("Location2", "location2"),
          ("locaion", "location"),
          ("locaton", "location"),
          ("l0ocaton", "location"),
          ("Month", "month"),
          ("new version", "newversion"),
          ("orig-year", "origyear"),
          ("orig_year", "origyear"),
          ("oage", "page"),
          ("p", "page"),
          ("Page", "page"),
          ("pag", "page"),
          ("pagae", "page"),
          ("pge", "page"),
          ("pagurl", "pageurl"),
          ("page_url", "pageurl"),
          ("place", "location"),
          ("Publisher", "publisher"),
          ("pu7blisher", "publisher"),
          ("Publisher2", "publisher2"),
          ("SBN", "ISBN"),
          ("Section", "section"),
          ("Title", "title"),
          ("tile", "title"),
          ("ttle", "title"),
          ("title-trans", "trans-title"),
          ("translater", "translator"),
          ("URL", "url"),
          ("Volume", "volume"),
          ("Year", "year"),
          ("year_publisher", "year_published"),
        ]
        move_params(params_to_move)
        params_to_remove = [
          "indent2"
        ]
        params_to_remove_if_blank = [
          "archiveorg"
        ]
        params_not_yet_handled = [
          "via",
          "rfc",
          "track",
          "pagetitle",
          "part",
          "editor-first", # combine into editor=
          "editor-last",
          "editor1-first", # combine into editor=
          "editor1-last",
          "editor2-first", # combine into editor2=
          "editor2-last",
          "editor-first2", # combine into editor2=
          "editor-last2",
          "q",
          "volumes", # leave as is
          "issues", # leave as is
          "numbers", # leave as is
        ]

    if args.rename_translator:
      if tn in quote_templates:
        params_to_move = [("trans", "tlr")]
        #for trans_param in ["title", "chapter", "journal", "work", "album", "author", "entry", "episode",
        #                    "lyricist", "section", "series", "section", "newspaper"]:
        #  params_to_move.append(("trans-%s" % trans_param, "%s-t" % trans_param))
        #  params_to_move.append(("trans-%s2" % trans_param, "%s2-t" % trans_param))
        #  params_to_move.append(("trans-%s3" % trans_param, "%s3-t" % trans_param))
        move_params(params_to_move)

    if args.rename_numbered_params:
      must_continue = False
      if tn in quote_templates:
        last_url_like = None
        last_url_like_value = None
        for param in t.params:
          pn = pname(param)
          pv = str(param.value)
          if pn in unrecognized_after_url_named_params:
            pagemsg("WARNING: Saw bad (unrecognized or misspelled) param %s=%s: %s" % (
              pn, escape_newline(pv), escape_newline(str(t))))
          if ((re.search("^[0-9]+$", pn) or pn not in recognized_named_params)
              and pn not in unrecognized_after_url_named_params
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
        ], no_notes=True)
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
        ], no_notes=True)
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
        ], no_notes=True)
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
        ], no_notes=True)
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
        ], no_notes=True)
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
        ], no_notes=True)
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
        ], no_notes=True)
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
        ], no_notes=True)
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
        ], no_notes=True)
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
        ], no_notes=True)
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
        ], no_notes=True)
        changed = origt != str(t)
        if changed:
          notes.append("rename numbered params in {{quote-web}} to named params and remove blank ones")

    if changed:
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("rename {{quote-*}} params",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--rename-translator", action="store_true", help="Rename translators")
parser.add_argument("--rename-numbered-params", action="store_true", help="Rename numbered params")
parser.add_argument("--rename-bad-params", action="store_true", help="Rename bad (misspelled, etc.) params")
parser.add_argument("--do-old-renames", action="store_true", help="Do old (non-quote-template) renames")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

old_default_refs=["Template:quote-poem", "Template:quote-magazine", "Template:quote-news", "Template:quote-Don Quixote"]
blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:%s" % template for template in quote_templates])

def output_count(countdict):
  for pn, count in sorted(countdict.items(), key=lambda x: (-x[1], x[0])):
    msg("%-30s = %s" % (pn, count))

msg("Numbered params:")
msg("------------------------------------")
output_count(count_numbered_params)
msg("")
msg("Recognized named params:")
msg("------------------------------------")
output_count(count_recognized_named_params)
msg("")
msg("Unhandled params (by count):")
msg("------------------------------------")
output_count(count_unhandled_params)
msg("")
msg("Unhandled params(by name):")
msg("------------------------------------")
for pn, count in sorted(count_unhandled_params.items()):
  msg("%-30s = %s" % (pn, count))

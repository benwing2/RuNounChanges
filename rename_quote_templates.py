#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site, tname, pname
from collections import defaultdict

TEMP_BOLDFACE = "\uFFF0"
TEMP_LT = "\uFFF1"
TEMP_GT = "\uFFF2"
TEMP_LBRAC = "\uFFF3"
TEMP_RBRAC = "\uFFF4"
TEMP_AMP = "\uFFF5"
TEMP_SEMICOLON = "\uFFF6"

html_entity_to_replacement = [
  ("&lt;", "&lt;", TEMP_LT),
  ("&gt;", "&gt;", TEMP_GT),
  ("&#91;", "&#0*91;", TEMP_LBRAC),
  ("&#93;", "&#0*93;", TEMP_RBRAC),
]

quote_templates_by_highest_numbered_param = {
  "quote-av": 1,
  "quote-book": 8,
  "quote-hansard": 1,
  "quote-journal": 9,
  "quote-mailing list": 1,
  "quote-newsgroup": 1,
  "quote-song": 1,
  "quote-text": 1,
  "quote-us-patent": 1,
  "quote-video game": 1,
  "quote-web": 1,
  "quote-wikipedia": 1,
}

quote_templates_by_page_param = {
  "quote-book": "6",
  "quote-journal": "7",
}

quote_templates = set(quote_templates_by_highest_numbered_param.keys())

recognized_named_params_1_to_n_list = [
  "author", "last", "first", "authorlink", "trans-author", "trans-last", "trans-first", "trans-authorlink"
]

recognized_named_params_1_to_2_list = [
  "chapter", "chapterurl", "chapter_number", "chapter_plain", "chapter_series", "chapter_seriesvolume", "trans-chapter",
  "chapter_tlr", "notitle",
  "tlr", "translator", "translators", "editor", "editors", "mainauthor", "compiler", "compilers",
  "title", "trans-title", "series", "seriesvolume", "archiveurl", "url", "urls", "edition", "edition_plain",
  "volume", "volumes", "volume_plain", "volumeurl",
  "issue", "issues", "issue_plain", "issueurl",
  "number", "numbers", "number_plain", "numberurl",
  "lang", "worklang", "termlang", "origlang", "origworklang", "origtext",
  "genre", "format", "others", "quoted_in", "location", "publisher", "original", "by", "type",
  "date_published", "year_published", "month_published", "date", "year", "month",
  "start_date", "start_year", "start_month",
  "bibcode", "DOI", "doi", "ISBN", "isbn", "ISSN", "issn", "JSTOR", "jstor", "LCCN", "lccn", "OCLC", "oclc",
  "OL", "ol", "PMID", "pmid", "PMCID", "pmcid", "SSRN", "ssrn", "id", "archivedate", "accessdate", "nodate",
  "section", "sectionurl", "section_number", "section_plain", "section_series", "section_seriesvolume", "trans-section",
  "note", "note_plain",
  "line", "lines", "line_plain", "lineurl",
  "page", "pages", "page_plain", "pageurl", "column", "columns", "column_plain", "columnurl", "other",
  "platform",
]

recognized_named_single_params_everywhere_list = [
  "brackets", "coauthors",
  "footer",
  "lit",
  "newversion", "nocat", "norm", "sc", "normsc", "origdate", "origmonth", "origyear", "passage",
  "quotee", "sort", "subst", "t", "text",
  "tr", "transcription", "translation", "transliteration", "ts", "tag",
  "2ndauthor", "2ndauthorlink", "2ndfirst", "2ndlast", "nocolon"
]

recognized_named_single_params_by_template = {
  "quote-av": ["writer", "writers", "director", "directors",
               "episode", "trans-episode", "episode_series", "episode_seriesvolume", "episode_plain", "episode_number",
               "format", "medium", "season", "seasons", "season_plain",
                "network", "role", "roles", "speaker", "actor", "time", "at"],
  "quote-book": ["entry", "entryurl", "trans-entry", "entry_series", "entry_seriesvolume", "entry_plain",
                 "entry_number"],
  "quote-hansard": ["speaker", "debate", "report", "house"],
  "quote-journal": ["article", "titleurl", "articleurl", "article_tlr", "trans-article", "article_series",
                    "article_seriesvolume", "article_number", "title_plain", "article_plain",
                    "journal", "magazine", "newspaper", "work", "trans-journal", "trans-magazine", "trans-newspaper",
                    "trans-work", "newsagency"],
  "quote-mailing list": ["email", "list", "googleid", "group", "newsgroup",
    "titleurl", "title_series", "title_seriesvolume", "title_plain"],
  "quote-newsgroup": ["email", "googleid", "group", "newsgroup"],
  "quote-song": ["authorlabel", "lyricist", "lyrics-translator", "composer", "titleurl", "title_series",
                 "title_seriesvolume", "album", "work", "trans-album", "trans-work",
                 "artist", "track", "time", "at"],
  "quote-us-patent": ["inventor", "patent_type", "patent"],
  "quote-video game": ["developer", "version", "system", "scene", "level"],
  "quote-web": ["titleurl", "webpage_series", "webpage_seriesvolume", "title_number", "title_plain",
                "site", "work", "trans-site", "trans-work"],
  "quote-wikipedia": ["article", "revision", "trans-article", "article_series", "article_seriesvolume"],
}

recognized_named_single_per_template_params = defaultdict(list)
recognized_named_single_per_template_params_set = set()
for template, params in recognized_named_single_params_by_template.items():
  for param in params:
    recognized_named_single_per_template_params[param].append(template)
    recognized_named_single_per_template_params_set.add(param)
recognized_named_single_per_template_params_list = list(recognized_named_single_per_template_params_set)

formerly_recognized_named_params_list = [
  # removed from [[Module:quote]]
  "city", "trans", "laysummary", "laysource", "laydate", "doilabel", "authors", "indent", "i1",
  # removed from {{trans-*}}
  "blog", "periodical", "quote", "people", "vol",
  # wrongly included
  "book", "pageref", "accessdaymonth", "accessmonthday", "accessmonth", "accessyear", "autodate",
  "url-access", "url-status",
]

def make_all_param(params, highest_ind):
  return [param + ("" if ind == 1 else str(ind)) for param in params for ind in range(1, highest_ind + 1)]

recognized_named_params_everywhere_list = (
  make_all_param(recognized_named_params_1_to_n_list, 30) +
  make_all_param(recognized_named_params_1_to_2_list, 2) +
  recognized_named_single_params_everywhere_list
)
recognized_named_params_list = (
  recognized_named_params_everywhere_list +
  recognized_named_single_per_template_params_list
)
recognized_named_params_everywhere = set(recognized_named_params_everywhere_list)
recognized_named_params = set(recognized_named_params_list)

recognized_named_params_list_longest_to_shortest = sorted(recognized_named_params_list, key=lambda x:-len(x))
recognized_named_params_re = "(%s)" % "|".join(recognized_named_params_list_longest_to_shortest)
recognized_named_params_list_4_or_more = [x for x in recognized_named_params_list if len(x) >= 4]
recognized_named_params_list_1_to_3 = [x for x in recognized_named_params_list if len(x) < 4]
recognized_named_params_re_4_or_more = "(%s)" % "|".join(recognized_named_params_list_4_or_more)
recognized_named_params_re_1_to_3 = "(%s)" % "|".join(recognized_named_params_list_1_to_3)

count_recognized_named_params = defaultdict(int)
count_recognized_named_params_by_template = defaultdict(int)
count_numbered_params = defaultdict(int)
count_numbered_params_by_template = defaultdict(int)

count_templates = defaultdict(int)

unrecognized_after_url_named_params_list = [
  "archive-date", "archive_date", "archiv-datum", "access", "access-date", "accessed", "archiveorg", "archive-url",
  "asin", "author1", "digitized", "edition_plain", "fulltext", "i2", "isbn10", "meeting", "new version", "newsfeed", "oldurl",
  "originalpassage", "p", "paragraph", "part", "pos", "producer", "publish-date", "rfc", "retrieved", "stanza", "via",
  "website",
  # misspellings:
  "Chapter", "colunm", "Id", "IISBN", "isn", "Jnewsgroup", "oage", "Page", "pge", "Section", "tirle", "ur", "year_publsihed",
]
unrecognized_after_url_named_params = set(unrecognized_after_url_named_params_list)

count_unhandled_params = defaultdict(int)
count_unhandled_params_by_template = defaultdict(int)

params_with_inline_modifiers_1_to_n_list = ["author"]
params_with_inline_modifiers_1_to_2_list = [
  "chapter", "chapter_plain", "chapter_series", "chapter_seriesvolume", "chapter_tlr", 
  "section", "section_plain", "section_series", "section_seriesvolume",
  "tlr", "translator", "translators", "editor", "editors", "mainauthor", "compiler", "compilers",
  "director", "directors", "lyricist", "lyrics-translator", "composer", "role", "roles", "speaker", "actor", "artist",
  "tlr", "translator", "translators", "editor", "editors", "mainauthor", "compiler", "compilers",
  "title", "series", "seriesvolume", "edition", "edition_plain",
  "volume", "volumes", "volume_plain",
  "issue", "issues", "issue_plain",
  "number", "numbers", "number_plain",
  "line", "lines", "line_plain",
  "page", "pages", "page_plain",
  "column", "columns", "column_plain",
  "others", "quoted_in", "location", "publisher", "source", "original", "by", "platform", "note", "note_plain",
  "other",
]

params_with_inline_modifiers_single_everywhere_list = [
  "coauthors", "quotee", "2ndauthor",
]

params_with_inline_modifiers_by_template = {
  "quote-av": [
    "writer", "writers", "episode", "episode_series", "episode_seriesvolume", "episode_plain",
    "season", "seasons", "season_plain", "network",
  ],
  "quote-book": ["entry", "entry_series", "entry_seriesvolume", "entry_plain", "entry_number", "3", "4", "6"],
  "quote-hansard": ["speaker", "debate", "report", "house"],
  "quote-journal": ["article", "article_tlr", "article_series", "article_seriesvolume",
                    "title_plain", "article_plain",
                    "journal", "magazine", "newspaper", "work", "newsagency", "3", "4", "5", "7"],
  "quote-mailing list": [
    # not email, group, list, id because they are prefixed by text (FIXME)
    "title_series", "title_seriesvolume", "title_plain"
  ],
  "quote-newsgroup": [
    # not email, group, newsgroup, id because they are prefixed by text (FIXME)
  ],
  "quote-song": [
    "title_series", "title_seriesvolume", "album", "work" 
  ],
  "quote-us-patent": ["inventor"],
  "quote-video game": [
    # not version, scene, level because they are prefixed by text (FIXME)
    "developer", "system"],
  "quote-web": ["title_series", "title_seriesvolume", "title_plain", "site", "work"],
  "quote-wikipedia": ["article", "article_series", "article_seriesvolume"],
}

inline_modifiers_per_template_params = defaultdict(list)
inline_modifiers_per_template_params_set = set()
for template, params in params_with_inline_modifiers_by_template.items():
  for param in params:
    inline_modifiers_per_template_params[param].append(template)
    inline_modifiers_per_template_params_set.add(param)
inline_modifiers_per_template_params_list = list(inline_modifiers_per_template_params_set)

params_with_inline_modifiers_everywhere_list = (
  make_all_param(params_with_inline_modifiers_1_to_n_list, 30) +
  make_all_param(params_with_inline_modifiers_1_to_2_list, 2) +
  params_with_inline_modifiers_single_everywhere_list
)
params_with_inline_modifiers_list = (
  params_with_inline_modifiers_everywhere_list +
  inline_modifiers_per_template_params_list
)
params_with_inline_modifiers_everywhere = set(params_with_inline_modifiers_everywhere_list)
params_with_inline_modifiers = set(params_with_inline_modifiers_list)

count_lang_stripped_params = defaultdict(int)
count_lang_stripped_params_by_template = defaultdict(int)
count_unstrippable_params = defaultdict(int)
count_unstrippable_params_by_template = defaultdict(int)

def process_text_on_page(index, pagetitle, text):
  global args

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, blib.escape_newline(txt)))

  if ":" in pagetitle and not re.search(
      "^(Citations|Appendix|Reconstruction|Transwiki|Talk|Wiktionary|[A-Za-z]+ talk):", pagetitle):
    pagemsg("WARNING: Colon in page title and not a recognized namespace to include, skipping page")
    return None, None

  notes = []

  templates_to_rename_numbered_params = (
    set(args.templates_to_rename_numbered_params.split(","))
    if args.templates_to_rename_numbered_params else
    None
  )
  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    this_template_notes = []
    tn = tname(t)
    origt = str(t)
    def getp(param):
      return getparam(t, param)

    def from_to(txt):
      pagemsg("%s: <from> %s <to> %s <end>" % (txt, origt, origt))

    def move_params(params, frob_from=None, no_notes=False):
      this_notes = []
      tparams = []
      for param in t.params:
        tparams.append((str(param.name), str(param.value), param.showkey))
      for fr, to in params:
        if t.has(fr):
          oldval = getp(fr)
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

          if type(to) is not list:
            all_to_check = [to]
          else:
            all_to_check = to
            to = to[0]
          for to_check in all_to_check:
            existing_val = getp(to_check).strip()
            if existing_val:
              # put back old params
              del t.params[:]
              for (pn, pv, showkey) in tparams:
                t.add(pn, pv, showkey=showkey, preserve_spacing=False)
              from_to("WARNING: Would replace %s=%s -> %s= but %s=%s is already present"
                  % (fr, oldval.strip(), to_check, to_check, existing_val))
              return
          if oldval != newval:
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
            pagemsg("%s: %s=%s -> %s=%s" % (tn, fr, oldval, to, newval))
            this_notes.append("move %s=%s to %s=%s in {{%s}}"
              % (fr, oldval, to, newval, tn))
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
        this_template_notes.extend(this_notes)

    if tn in quote_templates:
      if args.check_unhandled_params:
        count_templates[tn] += 1
        for param in t.params:
          pn = pname(param)
          pv = str(param.value)
          if re.search("^[0-9]+$", pn):
            pnnum = int(pn)
            if pnnum <= quote_templates_by_highest_numbered_param[tn]:
              count_numbered_params[pn] += 1
              count_numbered_params_by_template["%s:%s" % (pn, tn)] += 1
              if pn != "1":
                pvs = pv.strip()
                m = re.search("^%s" % recognized_named_params_re, pvs)
                if m:
                  beginparam = m.group(1)
                  if len(beginparam) >= 4:
                    if re.search("^%s([A-Za-z0-9]| [^ A-Z0-9])" % beginparam, pvs):
                      from_to("WARNING: Probable missing equal sign in %s=%s" % (pn, pv))
                # Too many false positives, not enough real hits
                #m = re.search("%s$" % recognized_named_params_re, pvs)
                #if m:
                #  endparam = m.group(1)
                #  if len(endparam) >= 6:
                #    if re.search("([A-Za-z0-9]|[^ a-z] )%s$" % endparam, pvs):
                #      pagemsg("WARNING: Probable missing equal sign in %s=%s: %s" % (pn, pv, str(t)))
            else:
              from_to("WARNING: Saw unhandled param %s=%s" % (pn, pv))
              count_unhandled_params["%s:%s" % (pn, tn)] += 1
          elif pn in recognized_named_params_everywhere or (
            pn in recognized_named_single_per_template_params and tn in recognized_named_single_per_template_params[pn]
          ):
            count_recognized_named_params[pn] += 1
            count_recognized_named_params_by_template["%s:%s" % (pn, tn)] += 1
          else:
            from_to("WARNING: Saw unhandled param %s=%s" % (pn, pv))
            count_unhandled_params[pn] += 1
            count_unhandled_params_by_template["%s:%s" % (pn, tn)] += 1
          # Ignore nested templates e.g. {{w|Simone Caby|lang=fr}} and {{gbooks|q=draws|id=HV4jKhjzMVYC|pg=27}}
          check_pv = re.sub(r"\{\{([^{}]|\{\{[^{}]*\}\})*\}\}", "", pv)
          # Ignore HTML comments
          check_pv = re.sub("<!--.*?-->", "", check_pv, 0, re.S)
          # Ignore HTML like <span class="explain" title="The correct word should be 'kerana'">
          check_pv = re.sub("<(span|div|ref|abbr|source) .*?>", "", check_pv)
          # Don't consider URL's when looking for misplaced equal signs; for short params like id=, ts=, t=, make sure
          # there's not a preceding lowercase letter, or we will trigger on
          # "passage=You are being '''rage farmed'''. Your angry quote tweet = the goal." (due to t=) and
          # "title=Lights = manufacturers moving to non-replaceable batteries" (due to ts=)
          if "://" not in check_pv and (
            re.search("(^|[^a-z])%s *=" % recognized_named_params_re_1_to_3, check_pv) or
            re.search("%s *=" % recognized_named_params_re_4_or_more, check_pv)
          ):
            from_to("WARNING: Possible misplaced equal sign in %s=%s" % (pn, pv))

        if tn == "quote-journal" and re.search("^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)", getp("3")):
          from_to("WARNING: Possible error in numbered {{quote-journal}} params")

      if args.check_compound_pages:
        page = getp("page") or tn in quote_templates_by_page_param and getp(quote_templates_by_page_param[tn]) or ""
        page = page.strip()
        if page:
          page = blib.remove_links(page)
          if re.search("[0-9]+-[0-9]+", page):
            from_to("Saw possible compound page '%s'" % page)

      if args.check_author_splitting:
        splitmsgs = []
        this_notes = []

        def normalize_and_split_on_balanced_delims(author, authparam):
          processed_author = author
          for entity, entity_re, replacement in html_entity_to_replacement:
            processed_author = re.sub(entity_re, replacement, processed_author)
          # HTML entities per https://en.wikipedia.org/wiki/List_of_XML_and_HTML_character_entity_references must be
          # either decimal numeric (&#8209;), hexadecimal numeric (&#x200E;) or named (&Aring;, &frac34;, etc.). In
          # all three cases, we replace the ampersand and semicolon with special characters so they won't get
          # interpreted as delimiters.
          processed_author = re.sub("&(#[0-9]+);", TEMP_AMP + r"\1" + TEMP_SEMICOLON, processed_author)
          processed_author = re.sub("&(#x[0-9a-fA-F]+);", TEMP_AMP + r"\1" + TEMP_SEMICOLON, processed_author)
          processed_author = re.sub("&([0-9a-zA-Z_]+);", TEMP_AMP + r"\1" + TEMP_SEMICOLON, processed_author)
          # Eliminate L2R, R2L marks
          processed_author = processed_author.replace("\u200E", "").replace("\u200F", "")
          try:
            return blib.parse_multi_delimiter_balanced_segment_run(processed_author,
              [(r"[\[%s]" % TEMP_LBRAC, r"[\]%s]" % TEMP_RBRAC), (r"\(", r"\)"), (r"\{", r"\}"),
               (r"[<%s]" % TEMP_LT, r"[>%s]" % TEMP_GT)])
          except blib.ParseException as e:
            pagemsg("WARNING: Splitting %s=%s: Exception when parsing: %s" % (authparam, author, e))
            return False

        def undo_html_entity_replacement(txt):
          txt = txt.replace(TEMP_AMP, "&")
          txt = txt.replace(TEMP_SEMICOLON, ";")
          for entity, entity_re, replacement in html_entity_to_replacement:
            txt = txt.replace(replacement, entity)
          return txt

        # Try to move a translator or editor from author=, mainauthor= or coauthors= to tlr= or editor=.
        moved_tlr_msg = False
        moved_tlr_notes_msg = False
        moved_author_param = None
        moved_tlr_dest_param = None
        for dest_param in ["tlr", "editor", "compiler", "director"]:
          if dest_param == "tlr":
            basic_strip_re = r"transl?(\.|ator)"
            strip_re = r"(, *%s| *\(%s\))$" % (basic_strip_re, basic_strip_re)
            params_to_check = ["tlr", "translator", "translators"]
            desc = "translators"
          elif dest_param == "editor":
            basic_strip_re = r"ed(\.|itor)"
            strip_re = r"(, *%s| *\(%s\))$" % (basic_strip_re, basic_strip_re)
            params_to_check = ["editor", "editors"]
            desc = "editors"
          elif dest_param == "compiler":
            basic_strip_re = "compiler"
            strip_re = r"(, *%s| *\(%s\))$" % (basic_strip_re, basic_strip_re)
            params_to_check = ["compiler", "compilers"]
            desc = "compilers"
          elif dest_param == "director":
            basic_strip_re = "director"
            strip_re = r"(, *%s| *\(%s\))$" % (basic_strip_re, basic_strip_re)
            params_to_check = ["director", "directors"]
            desc = "directors"
          else:
            assert False, "Unrecognized dest param '%s'" % dest_param
          must_break = False
          for author_param in ["author", "author2", "author3", "author4", "author5", "author6", "author7", "author8",
                               "author9", "author10", "mainauthor", "coauthors"]:
            author = getp(author_param).strip()
            m = re.search(r"^(.*?)" + strip_re, author)
            if m:
              for tlrparam in params_to_check:
                current_tlr = getp(tlrparam).strip()
                if current_tlr:
                  pagemsg("WARNING: Moving %s in %s=%s, already saw %s=%s, can't move"
                    % (desc, author_param, author, tlrparam, current_tlr))
                  break
              else: # no break
                tlr = m.group(1)
                tlr_runs = normalize_and_split_on_balanced_delims(tlr, author_param)
                saw_semicolon = False
                saw_comma = False
                split_msg = "semicolon" # default when no delimiter
                for i, run in enumerate(tlr_runs):
                  if i % 2 == 0:
                    if re.search(r";\s+", run):
                      saw_semicolon = True
                    if re.search(r",\s+", run):
                      saw_comma = True
                if saw_comma and not saw_semicolon:
                  pagemsg("WARNING: Moving %s in %s=%s, saw comma and no semicolon, not sure how to partition authors from %s"
                    % (desc, author_param, author, desc))
                elif not saw_semicolon:
                  if author_param.startswith("author") and getp("authorlink" + author_param[6:]):
                    authorlink = getp("authorlink" + author_param[6:])
                    if "{{" in tlr or "[[" in tlr:
                      pagemsg("WARNING: Would move %s in %s=%s, but saw authorlink%s=%s and brackets or braces in %s"
                              % (desc, author_param, author, author_param[6:], authorlink, desc))
                      must_break = True
                      break
                    elif tlr == authorlink:
                      tlr = "{{w|%s}}" % tlr
                    else:
                      tlr = "{{w|%s|%s}}" % (authorlink, tlr)
                  new_tlrs = tlr
                  new_authors = None
                  moved_author_param = author_param
                  moved_tlr_dest_param = dest_param
                  moved_tlr_msg = "Moving %s=%s to %s=%s" % (author_param, author, dest_param, tlr)
                  moved_tlr_notes_msg = "move %s=%s to %s=%s in %s" % (author_param, author, dest_param, tlr, tn)
                elif author_param.startswith("author") and getp("authorlink" + author_param[6:]):
                  pagemsg("WARNING: Would split %s off of %s=%s, but saw authorlink%s=%s"
                          % (desc, author_param, author, author_param[6:], getp("authorlink")))
                else:
                  # Extract translator(s) after last semicolon
                  split_runs = blib.split_alternating_runs(tlr_runs, r"\s*;\s+", preserve_splitchar=True)
                  new_tlrs = undo_html_entity_replacement("".join(split_runs[-1]))
                  new_authors = undo_html_entity_replacement("".join("".join(split_run) for split_run in split_runs[:-2]))
                  moved_author_param = author_param
                  moved_tlr_dest_param = dest_param
                  moved_tlr_msg = "Splitting %s=%s into %s=%s and %s=%s" % (
                    author_param, author, author_param, new_authors, dest_param, new_tlrs
                  )
                  moved_tlr_notes_msg = "split %s=%s into %s=%s and %s=%s in {{%s}}" % (
                    author_param, author, author_param, new_authors, dest_param, new_tlrs, tn
                  )
              must_break = True
              break
          if must_break:
            break

        def do_author_param(author, authparam, rearrange_only=False):
          origauthor = author

          suffix_re = r"(I+|IV|V|VI+|(Jr|Sr|Esq|Jun|Sen)\.?|(M|J|D|Ph|PH|Ll|LL)[. ]*D[. ]*|[BM][. ]*[AS][. ]*)"
          deny_list_words = [
            "United", "States", "American", "Britain", "British", "Australia", "Australian", "Zealand",
            "National", "International", "Limited", "Ltd", "Company", "Inc", "Society", "Association", "Assn",
            "Center", "School", "Laboratory", "Office", "Ministry", "Proceedings", "Contributor"
          ]
          # Normalize 'et al' and variants at the end of the author. Do this before anything else becasue otherwise
          # we will get thrown off by the variant '& al' (converting '&' -> 'and') and by brackets (which will be
          # invisible to our algorithm, due to the call to blib.parse_multi_delimiter_balanced_segment_run()).
          # Handle pretentious people who write 'et alii', 'et alia', 'et alios'.
          et_al_author = re.sub(r"['\[]*(?:&|\bet\.*) al(?:i(?:a|i|os))?['.\]]*$", "et al.", author)
          if et_al_author != author:
            pagemsg("Splitting %s=%s: Normalized 'et al' variant to '%s'" % (authparam, author, et_al_author))
            author = et_al_author

          serial_comma_author = re.sub(r"\{\{,\}\}", ",", author)
          if serial_comma_author != author:
            pagemsg("Splitting %s=%s: Normalized serial comma to '%s'" % (authparam, author, serial_comma_author))
            author = serial_comma_author

          missing_space_comma_author = re.sub(",([A-Z])", r", \1", author)
          if missing_space_comma_author != author:
            pagemsg("Splitting %s=%s: Normalized missing space after comma to '%s'"
              % (authparam, author, missing_space_comma_author))
            author = missing_space_comma_author

          ampersand_comma_author = re.sub(r" &,", " &", author)
          if ampersand_comma_author != author:
            pagemsg("Splitting %s=%s: Normalized ampersand-comma to '%s'" % (authparam, author, ampersand_comma_author))
            author = ampersand_comma_author

          missing_space_ampersand_author = re.sub(" &([A-Z])", r" & \1", author)
          if missing_space_ampersand_author != author:
            pagemsg("Splitting %s=%s: Normalized missing space after ampersand to '%s'"
              % (authparam, author, missing_space_ampersand_author))
            author = missing_space_ampersand_author

          author_runs = normalize_and_split_on_balanced_delims(author, authparam)
          if author_runs is False:
            return False

          saw_semicolon = False
          saw_comma = False
          split_msg = "semicolon" # default when no delimiter
          for i, run in enumerate(author_runs):
            if i % 2 == 0:
              if re.search(r";\s+", run):
                saw_semicolon = True
              if re.search(r",\s+", run):
                saw_comma = True

          if saw_semicolon:
            split_msg = "semicolon"
          elif saw_comma:
            split_msg = "comma"

          # Replace occurrences of "and" or "&" with a semicolon or comma to simplify the code below (using a
          # semicolon if one was already seen, else a comma if one was already seen, else a semicolon).
          for i, run in enumerate(author_runs):
            if i % 2 == 0:
              # Handle occurrences of ", and" or "; and".
              run = re.sub(r"([,;])\s+([Aa]nd|&|%s)\s+" % TEMP_AMP, r"\1 ", run)
              def replace_and(m):
                nonlocal saw_semicolon, split_msg
                if saw_semicolon:
                  return "; "
                elif saw_comma:
                  return ", "
                else:
                  saw_semicolon = True
                  split_msg = "'and'"
                  return "; "
              run = re.sub(r"\s+([Aa]nd|&|%s)\s+" % TEMP_AMP, replace_and, run)
              author_runs[i] = run

          msgpref = "Splitting (on %s), %s=%s" % (split_msg, authparam, origauthor)

          if saw_semicolon:
            split_re = r"\s*;\s+"
            delimiter = ";"
          elif saw_comma:
            split_re = r"\s*,\s+"
            delimiter = ","
          else:
            split_re = r"\s*;\s+"
            delimiter = ";"

          # Try to rearrange LAST, FIRST into FIRST LAST in a single author
          if delimiter == "," and len(author_runs) == 1:
            m = re.search("^((?:[A-Z][^ ,]*)(?: [A-Z][^ ,]*){0,2}), ([A-Z][^ ]*)$", author_runs[0])
            if not m:
              m = re.search("^([A-Z][^ ]*), ((?:[A-Z][^ ,]*)(?: [A-Z][^ ,]*){0,2})$", author_runs[0])
            if m:
              if re.search(", *" + suffix_re + "$", author_runs[0]):
                pagemsg("%s: Saw suffix in name, won't try to rearrange" % msgpref)
              else:
                for deny_list_word in deny_list_words:
                  if re.search(r"\b%s\b" % deny_list_word, author_runs[0]):
                    pagemsg("%s: Saw deny-listed word '%s', won't try to rearrange" % (msgpref, deny_list_word))
                    break
                else: # no break
                  rearranged_author = undo_html_entity_replacement(m.group(2) + " " + m.group(1))
                  pagemsg("%s: Rearranged '%s' to '%s' (VERIFY)" % (msgpref, author_runs[0], rearranged_author))
                  notes_msg = "rearrange LAST, FIRST in %s= in {{%s}} into FIRST LAST" % (authparam, tn)
                  return ("%s: Would rearrange into %s (VERIFY)" % (msgpref, rearranged_author), notes_msg,
                          rearranged_author)

          if rearrange_only:
            pagemsg("%s: `rearrange_only` set, not splitting" % msgpref)
            return False

          # Handle "et al" and variants.
          if "et al" in author_runs[-1]:
            et_al_re = r"et al\." # since we normalized all variants above
            if not re.search(et_al_re + "$", author_runs[-1]):
              # 'et al' followed by something
              return "WARNING: %s: Saw 'et al.' followed by junk, won't split: %s" % (msgpref, author_runs[-1])
            m = re.search("^(.*?)(" + et_al_re + ")$", author_runs[-1])
            assert m
            orig_last_run = author_runs[-1]
            pre_et_al, et_al = m.groups()
            if re.search(split_re + "$", pre_et_al):
              # already saw delimiter preceding 'et al'
              author_runs[-1] = pre_et_al + "et al."
            else:
              author_runs[-1] = pre_et_al.rstrip() + delimiter + " et al."
            if not saw_semicolon and not saw_comma:
              saw_semicolon = True
            if orig_last_run != author_runs[-1]:
              pagemsg("%s: Canonicalized '%s' to '%s'" % (msgpref, orig_last_run, author_runs[-1]))

          if not saw_semicolon and not saw_comma:
            return False

          split_runs = blib.split_alternating_runs(author_runs, split_re, preserve_splitchar=True)
          authors = []
          for i, split_run in enumerate(split_runs):
            if i % 2 == 0:
              run = "".join(split_run).strip()
              if re.search("^%s$" % suffix_re, run):
                if i == 0:
                  return "%s: Saw suffix '%s' without main form, won't split" % (msgpref, run)
                else:
                  authors[-1] += "".join(split_runs[i - 1]) + "".join(split_runs[i])
                  continue
              if not run:
                return "%s: Saw empty run, won't split" % msgpref
              if run != "et al.":
                # "et al" variants handled specially above and canonicalized to "et al."
                if run[0].islower():
                  return "%s: Saw run '%s' beginning with lowercase, won't split" % (msgpref, run)
                if not run[0].isupper() and not re.search(r"^[{\[]", run):
                  return "%s: Saw run '%s' not beginning with uppercase, link or template, won't split" % (msgpref, run)
                if (not re.search(r"\s", run) and not re.search(r"^\{\{w\|.*\}\}$", run)
                    and not re.search(r"^\[\[w:.*\]\]$", run) and not re.search(r"^\{\{lang\|.*\}\}$", run)):
                  # Normally, a run without a space indicates a LAST, FIRST situation or an organization; but allow
                  # runs like {{w|Morrissey}}, {{w|Beyoncé}}, {{w|Jagger–Richards}}, {{w|busbee}}; also allow
                  # [[w:Yas|Yas]], [[w:O.S.T.R.|O.S.T.R.]], [[w:Virgil|Virgill]] and {{lang|jje|양창용}},
                  # {{lang|zh|黄俊英}}
                  return "%s: Saw run '%s' without space, won't split" % (msgpref, run)
                for j, runpart in enumerate(split_run):
                  if j % 2 == 0 and ":" in runpart: # not in templates, links or the like
                    return "%s: Saw run '%s' with colon in runpart '%s' (index %s), won't split" % (
                        msgpref, run, runpart, j)
                space_split_runs = blib.split_alternating_runs(split_run, r"\s+")
                recombined_space_split_runs = []
                for split_runpart in space_split_runs:
                  recombined_space_split_runs.append("".join(split_runpart))
                for j, word in enumerate(recombined_space_split_runs):
                  if (word[0].islower() and not re.search("^d['’]", word) and not word.startswith("al-") and not
                      re.search("^([dl][aeo]s?|v[oa]n|vom|te[rn]?|de[lnr]|di|du|à|y)$", word)):
                    return ("%s: Saw run '%s' with non-allow-listed lowercase word '%s' (index %s) in it, won't split"
                      % (msgpref, run, word, j))
                for deny_list_word in deny_list_words:
                  if re.search(r"\b%s\b" % deny_list_word, run):
                    return "%s: Saw run '%s' with deny-listed word '%s', won't split" % (msgpref, run, deny_list_word)
              authors.append(run)
          split_authors = " // ".join(undo_html_entity_replacement(auth) for auth in authors)
          semicolon_joined_authors = "; ".join(undo_html_entity_replacement(auth) for auth in authors)

          if authparam == "author":
            author2 = getp("author2").strip()
            last2 = getp("last2").strip()
            if len(authors) > 1 and (author2 or last2):
              if author2:
                msgauth2 = "author2=%s" % author2
              else:
                msgauth2 = "last2=%s" % last2
              return "WARNING: %s: Would normally split into %s, but saw %s" % (msgpref, split_authors, msgauth2)

          if origauthor == semicolon_joined_authors:
            return "%s: Would normally split into %s, but rejoined value is same as current" % (msgpref, split_authors)

          num_entities = len(authors)
          notes_msg = "split (on %s) %s= into %s entit%s in {{%s}} and join with semicolons" % (
            split_msg, authparam, num_entities, "ies" if num_entities > 1 else "y", tn
          )
          return "%s: Would split into %s" % (msgpref, split_authors), notes_msg, semicolon_joined_authors

        splits = []
        higher_author_params = ["author%s" % i for i in range(2, 31)]

        for authparam in ["author", "coauthors", "mainauthor", "tlr", "translator", "translators", "editor", "editors",
                          "quotee", "chapter_tlr", "by", "2ndauthor", "mainauthor2", "tlr2", "translator2",
                          "translators2", "quotee2", "chapter_tlr2", "by2"] + (
                            ["3"] if tn in ["quote-book", "quote-journal"] else []
                          ) + (
                            ["writer", "writers"] if tn == "quote-av" else []
                          ) + (
                            ["speaker"] if tn == "quote-hansard" else []
                          ) + (
                            ["inventor"] if tn == "quote-us-patent" else []
                          ) + (
                            ["developer"] if tn == "quote-video game" else []
                          ) + higher_author_params:
          if authparam == moved_author_param and moved_tlr_msg:
            author = new_authors
          elif authparam == moved_tlr_dest_param and moved_tlr_msg:
            author = new_tlrs
          else:
            author = getp(authparam).strip()
          if not author:
            continue
          authret = do_author_param(author, authparam, rearrange_only=authparam in higher_author_params)
          if authret is not False:
            if type(authret) is str:
              splits.append((authparam, False, authret, False))
            else:
              splitmsg, notes_msg, new_paramval = authret
              splits.append((authparam, new_paramval, splitmsg, notes_msg))
        newt = list(blib.parse_text(str(t)).filter_templates())[0]
        if moved_tlr_msg:
          splitmsgs.append(moved_tlr_msg)
          this_notes.append(moved_tlr_notes_msg)
          if new_authors:
            following_author = blib.find_following_param(newt, moved_author_param)
            newt.add(moved_tlr_dest_param, new_tlrs, before=following_author)
            newt.add(moved_author_param, new_authors)
          else:
            newt.add(moved_tlr_dest_param, new_tlrs, before=moved_author_param)
            rmparam(newt, moved_author_param)
        if splits:
          for authparam, new_paramval, splitmsg, notes_msg in splits:
            if new_paramval is not False:
              newt.add(authparam, new_paramval)
            splitmsgs.append(splitmsg)
            if notes_msg is not False:
              this_notes.append(notes_msg)
            else:
              this_notes.append("manually fixed author-splitting issue in {{%s}}" % tn)
        if splitmsgs:
          pagemsg("%s: <from> %s <to> %s <end> <comment> %s <endcom>" % (
            " || ".join(splitmsgs), origt, str(newt), "; ".join(blib.group_notes(this_notes))))
        this_template_notes.extend(this_notes)

    if args.do_old_renames:
      if tn in ["quote-magazine", "quote-news"]:
        blib.set_template_name(t, "quote-journal")
        this_template_notes.append("%s -> quote-journal" % tn)
      if tn in ["quote-Don Quixote"]:
        blib.set_template_name(t, "RQ:Don Quixote")
        this_template_notes.append("quote-Don Quixote -> RQ:Don Quixote")
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
        if origt != str(t):
          this_template_notes.append("quote-poem -> quote-book with fixed params")

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
        ]

    if args.rename_params_to_eliminate:
      if tn in quote_templates:
        #params_to_move = [
        #  ("city", "location"),
        #  ("city2", "location2"),
        #  ("vol", "volume"),
        #  ("quote", "text"),
        #  ("periodical", "journal"),
        #  ("people", "actor"),
        #  ("blog", "site"),
        #  ("trans", "tlr")
        #]
        params_to_move = [
          ("authors", "author"),
        ]
        move_params(params_to_move)

    if args.remove_lang_wrapping:
      if tn in quote_templates:
        for param in t.params:
          pn = pname(param)
          pv = str(param.value)
          if pn in params_with_inline_modifiers_everywhere or (
            pn in inline_modifiers_per_template_params and tn in inline_modifiers_per_template_params[pn]
          ):
            langcode = None
            m = re.search(r"^\[\[(?:w|wikipedia):([a-z][a-z-]+):([^\[\]|{}<>;]*)\]\]$", pv)
            if not m:
              m = re.search(r"^\[\[(?:w|wikipedia):([a-z][a-z-]+):([^\[\]|{}<>;]*)\|\2\]\]$", pv)
            if m:
              langcode, dest = m.groups()
              newval = "w:%s:%s" % (langcode, dest)
              t.add(pn, newval)
              pagemsg("Convert raw foreign Wikipedia link %s=%s to %s: %s" % (pn, pv, newval, origt))
              this_template_notes.append("convert raw foreign Wikipedia link in %s= in {{%s}} to w:%s:..."
                % (pn, tn, langcode))
              continue

            m = re.search(r"^\[\[(?:w|wikipedia):([^\[\]|{}<>;]*)\]\]$", pv)
            if not m:
              m = re.search(r"^\[\[(?:w|wikipedia):([^\[\]|{}<>;]*)\|\1\]\]$", pv)
            if m:
              dest = m.group(1)
              newval = "w:%s" % dest
              t.add(pn, newval)
              pagemsg("Convert raw Wikipedia link %s=%s to %s: %s" % (pn, pv, newval, origt))
              this_template_notes.append("convert raw Wikipedia link in %s= in {{%s}} to w:..."
                % (pn, tn))
              continue

            m = re.search(r"^\{\{w\|([^\[\]|{}<>;]*)\}\}$", pv)
            if m:
              dest = m.group(1)
              newval = "w:%s" % dest
              t.add(pn, newval)
              pagemsg("Convert templatized Wikipedia link %s=%s to %s: %s" % (pn, pv, newval, origt))
              this_template_notes.append("convert templatized Wikipedia link in %s= in {{%s}} to w:..."
                % (pn, tn))
              continue

            langcode = None
            m = re.search(r"^\{\{w\|lang=([a-z][a-z-]+)\|([^\[\]|{}<>;]*)\}\}$", pv)
            if m:
              langcode, dest = m.groups()
            else:
              m = re.search(r"^\{\{w\|([^\[\]|{}<>;]*)\|lang=([a-z][a-z-]+)\}\}$", pv)
              if m:
                dest, langcode = m.groups()
            if langcode:
              newval = "w:%s:%s" % (langcode, dest)
              t.add(pn, newval)
              pagemsg("Convert templatized foreign Wikipedia link %s=%s to %s: %s" % (pn, pv, newval, origt))
              this_template_notes.append("convert templatized foreign Wikipedia link in %s= in {{%s}} to w:%s:..."
                % (pn, tn, langcode))
              continue

            m = re.search(r"^\{\{lw\|([a-z][a-z-]+)\|([^\[\]|{}<>;]*)\}\}$", pv)
            if m:
              langcode, dest = m.groups()
              newval = "lw:%s:%s" % (langcode, dest)
              t.add(pn, newval)
              pagemsg("Convert {{lw|...}} foreign Wikipedia link %s=%s to %s: %s" % (pn, pv, newval, origt))
              this_template_notes.append("convert {{lw|...}} foreign Wikipedia link in %s= in {{%s}} to lw:%s:..."
                % (pn, tn, langcode))
              continue

            if re.search(r"\{\{lang\|[^|]*\|[^{}|=]*\}\}", pv):
              m = re.search(r"^\{\{lang\|([^|]*)\|([^{}|=]*)\}\}$", pv.strip())
              if m:
                newval = "%s:%s" % (m.group(1), m.group(2))
                t.add(pn, newval)
                pagemsg("Strip lang wrapping %s=%s to %s: %s" % (pn, pv, newval, origt))
                this_template_notes.append("convert {{lang}} wrapping in %s= in {{%s}} to %s:..." % (pn, tn, m.group(1)))
                count_lang_stripped_params[pn] += 1
                count_lang_stripped_params_by_template["%s:%s" % (pn, tn)] += 1
              else:
                gloss = None
                tr = None
                if not m:
                  m = re.search(r"^\{\{lang\|([^|]*)\|([^{}|=]*)\}\}\s+\[([^\[\]]*)\]$", pv.strip())
                  if m and m.group(3).startswith("http"):
                    m = None
                  if m:
                    lang, foreign, gloss = m.groups()
                if not m:
                  m = re.search(r"^\{\{lang\|([^|]*)\|([^{}|=]*)\}\}\s+\(([^()]*)\)$", pv.strip())
                  if m:
                    lang, foreign, gloss = m.groups()
                if not m:
                  m = re.search(r"^\{\{lang\|([^|]*)\|([^{}|=]*)\}\}\s+&#0?91;(.*)&#0?93;$", pv.strip())
                  if m:
                    lang, foreign, gloss = m.groups()
                if not m:
                  m = re.search(r"^\{\{lang\|([^|]*)\|([^{}|=]*)\}\}\s+[-–—=]\s+(.*)$", pv.strip())
                  if m:
                    lang, foreign, gloss = m.groups()
                if not m:
                  m = re.search(r"^([^{}]+?)\s+\(\{\{lang\|([^|]*)\|([^{}|=]*)\}\}\)$", pv.strip())
                  if m:
                    gloss, lang, foreign = m.groups()
                if not m:
                  m = re.search(r"^''([^{}]+?)''\s+\[?\{\{lang\|(ko)\|([^{}|=]*)\}\}\]?$", pv.strip())
                  if m:
                    tr, lang, foreign = m.groups()
                if not m:
                  m = re.search(r"^([^{}]+?)\s+\[\{\{lang\|([^|]*)\|([^{}|=]*)\}\}\]$", pv.strip())
                  if m:
                    gloss, lang, foreign = m.groups()
                if gloss or tr:
                  if gloss:
                    m = re.search("^''(.*)''$", gloss)
                    if m:
                      gloss = m.group(1)
                  if tr:
                    m = re.search("^''(.*)''$", tr)
                    if m:
                      tr = m.group(1)
                  if gloss:
                    cleaned_gloss = re.sub("\{\{[^{}]*\}\}", "", gloss)
                    if (lang in ["ar", "ur", "fa", "pa"] and (re.search("([ʾʿāīūṣṭẓḍḥǧġṯḵḏśĀĪŪṢṬẒḌḤǦĠŠṮḴḎŚʔʕ]|t̤|n̲|T̤|N̲)", cleaned_gloss) or
                                          re.search("\bal-", cleaned_gloss)) or
                        lang == "fa" and (re.search("[âÂčČ]", cleaned_gloss) or re.search("-e\b", cleaned_gloss))):
                      pagemsg("Assuming gloss '%s' is transliteration in %s=%s: %s" % (gloss, pn, pv, origt))
                      tr = gloss
                      gloss = None
                  if tr:
                    newval = "%s:%s<tr:%s>" % (lang, foreign, tr)
                    t.add(pn, newval)
                    pagemsg("Strip lang wrapping with transliteration %s=%s to %s: %s" % (pn, pv, newval, origt))
                    this_template_notes.append("convert {{lang}} wrapping in %s= in {{%s}} to %s:...<tr:...>" % (pn, tn, lang))
                  else:
                    newval = "%s:%s<t:%s>" % (lang, foreign, gloss)
                    t.add(pn, newval)
                    pagemsg("Strip lang wrapping with translation %s=%s to %s: %s" % (pn, pv, newval, origt))
                    this_template_notes.append("convert {{lang}} wrapping in %s= in {{%s}} to %s:...<t:...>" % (pn, tn, lang))
                  count_lang_stripped_params[pn] += 1
                  count_lang_stripped_params_by_template["%s:%s" % (pn, tn)] += 1
                else:
                  pagemsg("WARNING: Unable to strip lang wrapping in %s=%s: %s" % (pn, pv, origt))
                  count_unstrippable_params[pn] += 1
                  count_unstrippable_params_by_template["%s:%s" % (pn, tn)] += 1

    if args.fix_year_boldfacing:
      if tn in quote_templates:
        for param in t.params:
          pn = pname(param)
          pv = str(param.value).strip()
          if pn in ["year", "year2"]:
            if "'''" not in pv:
              continue
            m = re.search("^'''([^']*)'''$", pv)
            if m:
              pagemsg("Removing extraneous boldface in %s=%s: %s" % (pn, pv, origt))
              t.add(pn, m.group(1))
              this_template_notes.append("remove extraneous boldface in %s=%s in {{%s}}" % (pn, pv.strip(), tn))
              continue
            if pv.startswith("'''"):
              pagemsg("%s=%s already begins with boldface, assuming already fixed: %s" % (pn, pv, origt))
              continue
            modified_pv = pv.replace("'''", TEMP_BOLDFACE)
            num_boldface = len(list(x for x in modified_pv if x == TEMP_BOLDFACE))
            if num_boldface % 2 != 0:
              pagemsg("WARNING: Odd numbers of boldface in %s=%s, not fixing: %s" % (pn, pv, origt))
              continue
            newpv = "'''" + pv + "'''"
            newpv = re.sub("'''(&#8203;|\u200B)'''$", "", newpv)
            pagemsg("Replacing %s=%s with %s: %s" % (pn, pv, newpv, origt))
            t.add(pn, newpv)
            this_template_notes.append("correct boldface in %s=%s -> %s in {{%s}}" % (pn, pv, newpv, tn))

    if args.check_bad_year:
      if tn in quote_templates:
        for param in t.params:
          pn = pname(param)
          pv = str(param.value).strip()
          if pv and (
            pn in ["year", "start_year", "origyear", "year published"] or
            pn == "2" and tn in ["quote-book", "quote-journal"]
          ):
            cleaned_pv = re.sub("<sup>(.*?)</sup>", r"\1", pv)
            if (not re.search("[0-9][0-9][0-9]", cleaned_pv) and not re.search("[0-9]+(st|nd|rd|th)", cleaned_pv)
                and not re.search(r"[0-9] (BC|BCE|AD|CE|\{\{(BC|BCE|AD|CE|B\.C\.|B\.C\.E\.|A\.D\.|C\.E\.)\}\})", cleaned_pv)):
              from_to("WARNING: Probable bad value in %s=%s" % (pn, pv))

    if args.templates_to_rename_numbered_params and tn in args.templates_to_rename_numbered_params:
      must_continue = False
      if tn in quote_templates:
        last_url_like = None
        last_url_like_value = None
        for param in t.params:
          pn = pname(param)
          pv = str(param.value)
          if ((re.search("^[0-9]+$", pn) or pn not in recognized_named_params)
              and pn not in unrecognized_after_url_named_params
              and pv.strip() and last_url_like and not (pn in ["6", "7"] and re.search("^[0-9]+$", pv))):
            pagemsg("WARNING: Possible unescaped vertical bar, saw %s=%s after %s=%s: %s" % (
              pn, pv, last_url_like, last_url_like_value, str(t)))
            #must_continue = True
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
        if origt != str(t):
          this_template_notes.append("rename numbered params in {{quote-av}} to named params and remove blank ones")
      if tn == "quote-book":
        move_params([
          ("8", ["t", "translation"]),
          ("7", ["text", "passage"]),
          ("6", ["page", "pages", "page_plain"]),
          ("5", ["url", "urls"]),
          ("4", "title"),
          ("3", ["author", "first", "last"]),
          ("2", ["year", "date"]),
        ], no_notes=True)
        if origt != str(t):
          this_template_notes.append("rename numbered params in {{quote-book}} to named params and remove blank ones")
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
        if origt != str(t):
          this_template_notes.append("rename numbered params in {{quote-hansard}} to named params and remove blank ones")
      if tn == "quote-journal":
        move_params([
          ("9", ["t", "translation"]),
          ("8", ["text", "passage"]),
          ("7", ["page", "pages", "page_plain"]),
          ("6", ["url", "urls"]),
          ("5", ["journal", "work", "magazine", "newspaper"]),
          ("4", "title"),
          ("3", ["author", "first", "last"]),
          ("2", ["year", "date"]),
        ], no_notes=True)
        if origt != str(t):
          this_template_notes.append("rename numbered params in {{quote-journal}} to named params and remove blank ones")
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
        if origt != str(t):
          this_template_notes.append("rename numbered params in {{quote-mailing list}} to named params and remove blank ones")
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
        if origt != str(t):
          this_template_notes.append("rename numbered params in {{quote-newsgroup}} to named params and remove blank ones")
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
        if origt != str(t):
          this_template_notes.append("rename numbered params in {{quote-song}} to named params and remove blank ones")
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
        if origt != str(t):
          this_template_notes.append("rename numbered params in {{quote-text}} to named params and remove blank ones")
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
        if origt != str(t):
          this_template_notes.append("rename numbered params in {{quote-us-patent}} to named params and remove blank ones")
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
        if origt != str(t):
          this_template_notes.append("rename numbered params in {{quote-video game}} to named params and remove blank ones")
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
        if origt != str(t):
          this_template_notes.append("rename numbered params in {{quote-web}} to named params and remove blank ones")

    if tn in quote_templates:
      if args.from_to:
        from_to("Saw {{%s}}" % tn)

    if origt != str(t):
      comment = "; ".join(blib.group_notes(this_template_notes))
      pagemsg("Replaced <from> %s <to> %s <end> <comment> %s <endcom>" % (origt, str(t), comment))

    notes.extend(this_template_notes)

  return str(parsed), notes

parser = blib.create_argparser("rename {{quote-*}} params",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--check-unhandled-params", action="store_true", help="Check for unhandled params")
parser.add_argument("--check-compound-pages", action="store_true", help="Check for possible compound pages like page=12-81")
parser.add_argument("--check-author-splitting", action="store_true", help="Try to split cases where multiple authors given in author= and similar params")
parser.add_argument("--remove-lang-wrapping", action="store_true", help="Remove {{lang|...}} wrapping in params")
parser.add_argument("--fix-year-boldfacing", action="store_true", help="Fix boldfacing in year= parameters")
parser.add_argument("--check-bad-year", action="store_true", help="Check for bad values in year= and similar params")
parser.add_argument("--from-to", action="store_true", help="Output all quote templates in from-to format")
parser.add_argument("--rename-params-to-eliminate", action="store_true", help="Rename params that will be eliminated")
parser.add_argument("--templates-to-rename-numbered-params", help="Comma-separated list of templates for which to rename numbered params")
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
def output_count_by_name(countdict):
  for pn, count in sorted(countdict.items()):
    msg("%-30s = %s" % (pn, count))

if args.check_unhandled_params:
  msg("Templates:")
  msg("------------------------------------")
  output_count(count_templates)
  msg("")
  msg("Numbered params:")
  msg("------------------------------------")
  output_count(count_numbered_params)
  msg("")
  msg("Numbered params by template (by count):")
  msg("---------------------------------------")
  output_count(count_numbered_params_by_template)
  msg("")
  msg("Numbered params by template (by name):")
  msg("--------------------------------------")
  output_count_by_name(count_numbered_params_by_template)
  msg("")
  msg("Recognized named params:")
  msg("------------------------------------")
  output_count(count_recognized_named_params)
  msg("")
  msg("Recognized named params by template (by count):")
  msg("-----------------------------------------------")
  output_count(count_recognized_named_params_by_template)
  msg("")
  msg("Recognized named params by template (by name):")
  msg("-----------------------------------------------")
  output_count_by_name(count_recognized_named_params_by_template)
  msg("")
  msg("Unhandled params (by count):")
  msg("------------------------------------")
  output_count(count_unhandled_params)
  msg("")
  msg("Unhandled params(by name):")
  msg("------------------------------------")
  output_count_by_name(count_unhandled_params)
  msg("")
  msg("Unhandled params by template (by name):")
  msg("---------------------------------------")
  output_count_by_name(count_unhandled_params_by_template)

if args.remove_lang_wrapping:
  msg("Params processed by --remove-lang-wrapping:")
  msg("-------------------------------------------")
  output_count(count_lang_stripped_params)
  msg("")
  msg("Params processed by --remove-lang-wrapping (by template):")
  msg("---------------------------------------------------------")
  output_count(count_lang_stripped_params_by_template)
  msg("")
  msg("Params unprocessable by --remove-lang-wrapping:")
  msg("-----------------------------------------------")
  output_count(count_unstrippable_params)
  msg("")
  msg("Params unprocessable by --remove-lang-wrapping (by template):")
  msg("-------------------------------------------------------------")
  output_count(count_unstrippable_params_by_template)

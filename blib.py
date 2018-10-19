#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Author: Originally CodeCat for MewBot; rewritten by Benwing

#    blib.py is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

import pywikibot, mwparserfromhell, re, string, sys, codecs, urllib2, datetime, json, argparse, time
from arabiclib import reorder_shadda
from collections import Counter

site = pywikibot.Site()

def remove_links(text):
  # eliminate [[FOO| in [[FOO|BAR]], and then remaining [[ and ]]
  text = re.sub(r"\[\[[^\[\]|]*\|", "", text)
  text = re.sub(r"\[\[|\]\]", "", text)
  return text

def remove_right_side_links(text):
  # eliminate |BAR]] in [[FOO|BAR]], and then remaining [[ and ]]
  text = re.sub(r"\|[^\[\]|]*\]\]", "", text)
  text = re.sub(r"\[\[|\]\]", "", text)
  return text

def msg(text):
  #pywikibot.output(text.encode('utf-8'), toStdout = True)
  print text.encode('utf-8')

def msgn(text):
  #pywikibot.output(text.encode('utf-8'), toStdout = True)
  print text.encode('utf-8'),

def errmsg(text):
  #pywikibot.output(text.encode('utf-8'))
  print >> sys.stderr, text.encode('utf-8')

def errmsgn(text):
  print >> sys.stderr, text.encode('utf-8'),

def parse_text(text):
  return mwparserfromhell.parser.Parser().parse(text, skip_style_tags=True)

def parse(page):
  return parse_text(page.text)

def getparam(template, param):
  if template.has(param):
    return unicode(template.get(param).value)
  else:
    return ""

def addparam(template, param, value, showkey=None, before=None):
  if re.match("^[0-9]+", param):
    template.add(param, value, preserve_spacing=False, showkey=showkey,
        before=before)
  else:
    template.add(param, value, showkey=showkey, before=before)

def rmparam(template, param):
  if template.has(param):
    template.remove(param)

def getrmparam(template, param):
  val = getparam(template, param)
  rmparam(template, param)
  return val

def tname(template):
  return unicode(template.name).strip()

def pname(param):
  return unicode(param.name).strip()

def set_template_name(template, name, origname=None):
  if not origname:
    origname = template.name
  if origname.endswith("\n"):
    template.name = name + "\n"
  else:
    template.name = name

def do_assert(cond, msg=None):
  if msg:
    assert cond, msg
  else:
    assert cond
  return True

# Retrieve a chain of parameters from template T, where the first parameter
# is named FIRST and the remainder are named PREF2, PREF3, etc.
# If FIRSTDEFAULT is given, use if FIRST is missing or empty.
def fetch_param_chain(t, first, pref, firstdefault=""):
  ret = []
  val = getparam(t, first) or firstdefault
  i = 2
  while val:
    ret.append(val)
    val = getparam(t, pref + str(i))
    i += 1
  return ret

def append_param_to_chain(t, val, firstparam, parampref):
  paramno = 0
  while True:
    paramno += 1
    next_param = firstparam if paramno == 1 else "%s%s" % (
        parampref, paramno)
    if not getparam(t, next_param):
      t.add(next_param, val)
      return next_param

def remove_param_chain(t, firstparam, parampref):
  paramno = 0
  changed = False
  while True:
    paramno += 1
    next_param = firstparam if paramno == 1 else "%s%s" % (
        parampref, paramno)
    if getparam(t, next_param):
      rmparam(t, next_param)
      changed = True
    else:
      return changed

def set_param_chain(t, values, firstparam, parampref):
  paramno = 0
  for val in values:
    paramno += 1
    next_param = firstparam if paramno == 1 else "%s%s" % (
        parampref, paramno)
    t.add(next_param, val)
  while True:
    paramno += 1
    next_param = firstparam if paramno == 1 else "%s%s" % (
        parampref, paramno)
    if getparam(t, next_param):
      rmparam(t, next_param)
    else:
      break

def sort_params(t):
  numbered_params = []
  named_params = []
  for param in t.params:
    if re.search(r"^[0-9]+$", unicode(param.name)):
      numbered_params.append((param.name, param.value))
    else:
      named_params.append((param.name, param.value))
  numbered_params.sort(key=lambda nameval:int(unicode(nameval[0])))
  del t.params[:]
  for name, value in numbered_params:
    t.add(name, value)
  for name, value in named_params:
    t.add(name, value)

def display(page):
  errmsg(u'# [[{0}]]'.format(page.title()))

def dump(page):
  old = page.get(get_redirect=True)
  msg(u'Contents of [[{0}]]:\n{1}\n----------'.format(page.title(), old))

def expand_text(tempcall, pagetitle, pagemsg, verbose):
  if verbose:
    pagemsg("Expanding text: %s" % tempcall)
  result = try_repeatedly(lambda: site.expand_text(tempcall, title=pagetitle), pagemsg, "expand text: %s" % tempcall)
  if verbose:
    pagemsg("Raw result is %s" % result)
  if result.startswith('<strong class="error">'):
    result = re.sub("<.*?>", "", result)
    if not verbose:
      pagemsg("Expanding text: %s" % tempcall)
    pagemsg("WARNING: Got error: %s" % result)
    return False
  return result

def do_edit(page, index, func=None, null=False, save=False, verbose=False):
  title = unicode(page.title())
  def pagemsg(text):
    msg("Page %s %s: %s" % (index, title, text))
  while True:
    try:
      if func:
        if verbose:
          pagemsg("Begin processing")
        new, comment = func(page, index, parse(page))

        if type(comment) is list:
          comment = "; ".join(group_notes(comment))

        if new:
          new = unicode(new)

          # Canonicalize shaddas when comparing pages so we don't do saves
          # that only involve different shadda orders.
          if reorder_shadda(page.text) != reorder_shadda(new):
            assert comment
            if verbose:
              pagemsg('Replacing <%s> with <%s>' % (page.text, new))
            page.text = new
            if save:
              pagemsg("Saving with comment = %s" % comment)
              page.save(comment = comment)
            else:
              pagemsg("Would save with comment = %s" % comment)
          elif null:
            pagemsg('Purged page cache')
            page.purge(forcelinkupdate = True)
          else:
            pagemsg('Skipped, no changes')
        elif null:
          pagemsg('Purged page cache')
          page.purge(forcelinkupdate = True)
        else:
          pagemsg('Skipped: %s' % comment)
      else:
        pagemsg('Purged page cache')
        page.purge(forcelinkupdate = True)
    except (pywikibot.LockedPage, pywikibot.NoUsername):
      errmsg(u'Page %s %s: Skipped, page is protected' % (index, title))
    except urllib2.HTTPError as e:
      if e.code != 503:
        raise
    except:
      errmsg(u'Page %s %s: Error' % (index, title))
      raise

    break

def do_process_text(pagetitle, pagetext, index, func=None, verbose=False):
  def pagemsg(text):
    msg("Page %s %s: %s" % (index, pagetitle, text))
  while True:
    try:
      if func:
        if verbose:
          pagemsg("Begin processing")
        new, comment = func(pagetitle, index, parse_text(pagetext))

        if new:
          new = unicode(new)

          # Canonicalize shaddas when comparing pages so we don't do saves
          # that only involve different shadda orders.
          if reorder_shadda(pagetext) != reorder_shadda(new):
            if verbose:
              pagemsg('Replacing <%s> with <%s>' % (pagetext, new))
            #if save:
            #  pagemsg("Saving with comment = %s" % comment)
            #  page.save(comment = comment)
            #else:
            pagemsg("Would save with comment = %s" % comment)
          else:
            pagemsg('Skipped, no changes')
        else:
          pagemsg('Skipped: %s' % comment)
    except:
      errmsg(u'Page %s %s: Error' % (index, pagetitle))
      raise

    break

ignore_prefixes = ["User:", "Talk:",
    "Wiktionary:Beer parlour", "Wiktionary:Translation requests",
    "Wiktionary:Grease pit", "Wiktionary:Etymology scriptorium",
    "Wiktionary:Information desk"]

def iter_pages(pageiter, startsort = None, endsort = None, key = None):
  i = 0
  t = None
  steps = 50

  for current in pageiter:
    i += 1

    if startsort != None and isinstance(startsort, int) and i < startsort:
      continue

    if key:
      keyval = key(current)
      pagetitle = keyval
    elif isinstance(current, basestring):
      keyval = current
      pagetitle = keyval
    else:
      keyval = current.title(withNamespace=False)
      pagetitle = unicode(current.title())
    if endsort != None:
      if isinstance(endsort, int):
        if i > endsort:
          break
      else:
        if keyval >= endsort:
          break

    if not t and isinstance(endsort, int):
      t = datetime.datetime.now()

    # Ignore user pages, talk pages and certain Wiktionary pages
    is_ignore_prefix = False
    for ip in ignore_prefixes:
      if pagetitle.startswith(ip):
        is_ignore_prefix = True
    if " talk:" in pagetitle:
      is_ignore_prefix = True
    if not is_ignore_prefix:
      yield current, i

    if i % steps == 0:
      tdisp = ""

      if isinstance(endsort, int):
        told = t
        t = datetime.datetime.now()
        pagesleft = (endsort - i) / steps
        tfuture = t + (t - told) * pagesleft
        tdisp = ", est. " + tfuture.strftime("%X")

      errmsg(str(i) + "/" + str(endsort) + tdisp)


def references(page, startsort = None, endsort = None, namespaces = None, includelinks = False):
  if isinstance(page, basestring):
    page = pywikibot.Page(site, page)
  pageiter = page.getReferences(onlyTemplateInclusion = not includelinks,
      namespaces = namespaces)
  for i, current in iter_items(pageiter, startsort, endsort):
    yield i, current

def cat_articles(page, startsort = None, endsort = None):
  if type(page) is str:
    page = page.decode("utf-8")
  if isinstance(page, basestring):
    page = pywikibot.Category(site, "Category:" + page)
  pageiter = page.articles(startsort = startsort if not isinstance(startsort, int) else None)
  for i, current in iter_items(pageiter, startsort, endsort):
    yield i, current

def cat_subcats(page, startsort = None, endsort = None):
  if type(page) is str:
    page = page.decode("utf-8")
  if isinstance(page, basestring):
    page = pywikibot.Category(site, "Category:" + page)
  pageiter = page.subcategories() #no startsort; startsort = startsort if not isinstance(startsort, int) else None)
  for i, current in iter_items(pageiter, startsort, endsort):
    yield i, current

def prefix(prefix, startsort = None, endsort = None, namespace = None):
  pageiter = site.prefixindex(prefix, namespace)
  for i, current in iter_items(pageiter, startsort, endsort):
    yield i, current

def stream(st, startsort = None, endsort = None):
  i = 0
  
  for name in st:
    i += 1
    
    if startsort != None and i < startsort:
      continue
    if endsort != None and i > endsort:
      break
    
    if type(name) is str:
      name = str.decode(name, "utf-8")
    
    name = re.sub(ur"^[#*] *\[\[(.+)]]$", ur"\1", name, flags=re.UNICODE)
    
    yield i, pywikibot.Page(site, name)

def get_page_name(page):
  if isinstance(page, basestring):
    return page
  # FIXME: withNamespace=False was used previously by cat_articles, in a
  # line like this:
  #    elif current.title(withNamespace=False) >= endsort:
  # Should we add this flag or support an option to add it?
  #return unicode(page.title(withNamespace=False))
  return unicode(page.title())

def iter_items(items, startsort = None, endsort = None, get_name = get_page_name):
  i = 0
  t = None
  steps = 50
  skipsteps = 1000

  for current in items:
    i += 1

    if startsort != None:
      should_skip = False
      if isinstance(startsort, int):
        if i < startsort:
          should_skip = True
      elif get_page_name(current) < startsort:
        should_skip = True
      if should_skip:
        if i % skipsteps == 0:
          pywikibot.output("skipping %s" % str(i))
        continue

    if endsort != None:
      if isinstance(endsort, int):
        if i > endsort:
          break
      elif get_page_name(current) > endsort:
        break

    if isinstance(endsort, int) and not t:
      t = datetime.datetime.now()

    yield i, current

    if i % steps == 0:
      tdisp = ""

      if isinstance(endsort, int):
        told = t
        t = datetime.datetime.now()
        pagesleft = (endsort - i) / steps
        tfuture = t + (t - told) * pagesleft
        tdisp = ", est. " + tfuture.strftime("%X")

      pywikibot.output(str(i) + "/" + str(endsort) + tdisp)

def group_notes(notes):
  # Group identical notes together and append the number of such identical
  # notes if > 1
  # 1. Count items in notes[] and return a key-value list in descending order
  notescount = Counter(notes).most_common()
  # 2. Recreate notes
  def fmt_key_val(key, val):
    if val == 1:
      return "%s" % key
    else:
      return "%s (%s)" % (key, val)
  notes = [fmt_key_val(x, y) for x, y in notescount]
  return notes

starttime = time.time()

def create_argparser(desc):
  msg("Beginning at %s" % time.ctime(starttime))
  parser = argparse.ArgumentParser(description=desc)
  parser.add_argument('start', help="Starting page index", nargs="?")
  parser.add_argument('end', help="Ending page index", nargs="?")
  parser.add_argument('-s', '--save', action="store_true", help="Save results")
  parser.add_argument('-v', '--verbose', action="store_true", help="More verbose output")
  return parser

def init_argparser(desc):
  return create_argparser(desc)

def parse_args(args = sys.argv[1:]):
  startsort = None
  endsort = None

  if len(args) >= 1:
    startsort = args[0]
  if len(args) >= 2:
    endsort = args[1]
  return parse_start_end(startsort, endsort)

def parse_start_end(startsort, endsort):
  if startsort != None:
    try:
      startsort = int(startsort)
    except ValueError:
      startsort = str.decode(startsort, "utf-8")
  if endsort != None:
    try:
      endsort = int(endsort)
    except ValueError:
      endsort = str.decode(endsort, "utf-8")

  return (startsort, endsort)

def elapsed_time():
  endtime = time.time()
  elapsed = endtime - starttime
  hours = int(elapsed // 3600)
  hoursecs = elapsed % 3600
  mins = int(hoursecs / 60)
  secs = hoursecs % 60
  if hours:
    msg("Elapsed time: %s hours %s mins %0.2f secs" % (hours, mins, secs))
  else:
    msg("Elapsed time: %s mins %0.2f secs" % (mins, secs))
  msg("Ending at %s" % time.ctime(endtime))

languages = None
languages_byCode = None
languages_byCanonicalName = None

families = None
families_byCode = None
families_byCanonicalName = None

scripts = None
scripts_byCode = None
scripts_byCanonicalName = None

etym_languages = None
etym_languages_byCode = None
etym_languages_byCanonicalName = None

wm_languages = None
wm_languages_byCode = None
wm_languages_byCanonicalName = None


def getData():
  getLanguageData()
  getFamilyData()
  getScriptData()
  getEtymLanguageData()

def getLanguageData():
  global languages, languages_byCode, languages_byCanonicalName
  
  languages = json.loads(site.expand_text("{{#invoke:User:MewBot|getLanguageData}}"))
  languages_byCode = {}
  languages_byCanonicalName = {}
  
  for lang in languages:
    languages_byCode[lang["code"]] = lang
    languages_byCanonicalName[lang["canonicalName"]] = lang


def getFamilyData():
  global families, families_byCode, families_byCanonicalName
  
  families = json.loads(site.expand_text("{{#invoke:User:MewBot|getFamilyData}}"))
  families_byCode = {}
  families_byCanonicalName = {}
  
  for fam in families:
    families_byCode[fam["code"]] = fam
    families_byCanonicalName[fam["canonicalName"]] = fam


def getScriptData():
  global scripts, scripts_byCode, scripts_byCanonicalName
  
  scripts = json.loads(site.expand_text("{{#invoke:User:MewBot|getScriptData}}"))
  scripts_byCode = {}
  scripts_byCanonicalName = {}
  
  for sc in scripts:
    scripts_byCode[sc["code"]] = sc
    scripts_byCanonicalName[sc["canonicalName"]] = sc


def getEtymLanguageData():
  global etym_languages, etym_languages_byCode, etym_languages_byCanonicalName
  
  etym_languages = json.loads(site.expand_text("{{#invoke:User:MewBot|getEtymLanguageData}}"))
  etym_languages_byCode = {}
  etym_languages_byCanonicalName = {}
  
  for etyl in etym_languages:
    etym_languages_byCode[etyl["code"]] = etyl
    etym_languages_byCanonicalName[etyl["canonicalName"]] = etyl

def try_repeatedly(fun, pagemsg, operation="save", max_tries=10, sleep_time=5):
  num_tries = 0
  while True:
    try:
      return fun()
    except KeyboardInterrupt as e:
      raise
    except pywikibot.exceptions.InvalidTitle as e:
      raise
    except Exception as e:
      #except (pywikibot.exceptions.Error, StandardError) as e:
      pagemsg("WARNING: Error when trying to %s: %s" % (operation, unicode(e)))
      errmsg("WARNING: Error when trying to %s: %s" % (operation, unicode(e)))
      num_tries += 1
      if num_tries >= max_tries:
        pagemsg("WARNING: Can't %s!!!!!!!" % operation)
        errmsg("WARNING: Can't %s!!!!!!!" % operation)
        raise
      errmsg("Sleeping for %s seconds" % sleep_time)
      time.sleep(sleep_time)
      if sleep_time >= 40:
        sleep_time += 40
      else:
        sleep_time *= 2

# Process link-like templates containing foreign text in specified language(s),
# on pages from STARTFROM to (but not including) UPTO, either page names or
# 0-based integers. Save changes if SAVE is true. VERBOSE is passed to
# blib.do_edit and will (e.g.) show exact changes. PROCESS_PARAM is the
# function called, which is called with six arguments: The page, its index
# (an integer), the template on the page, the language code of the template,
# the param in the template containing the foreign text and the param
# containing the Latin transliteration, or None if there is no such parameter.
# NOTE: The param may be an array ["page title", PARAM] for a case where the
# param value should be fetched from the page title and saved to PARAM. The
# function should return a list of changelog strings if changes were made,
# and something else otherwise (e.g. False). Changelog strings for all
# templates will be joined together using JOIN_ACTIONS; if not supplied,
# they will be separated by a semi-colon.
#
# LANG should be a short language code (e.g. 'ru', 'ar', 'grc') or list of
# such codes; only templates referencing the specified language(s) will be
# processed. LONGLANG is a canonical language name (e.g. "Russian", "Arabic",
# "Ancient Greek"), and is used only when CATTYPE is 'vocab' or 'borrowed'
# (see following). CATTYPE is either 'vocab' (do lemmas and non-lemma pages
# for the language in LONGLANG), 'borrowed' (do pages for terms borrowed from
# LONGLANG), 'translation' (do pages containing references to any of the 5
# standard translation templates), 'pagetext' (do the pages in PAGES_TO_DO,
# a list of (TITLE, TEXT) entries); for doing off-line runs; nothing saved),
# 'pages' (do the pages in PAGES_TO_DO, a list of page titles), or an
# arbitrary category name. It can also be a comma-separated list of any of
# the above.
#
# If SPLIT_TEMPLATES, then if the transliteration contains multiple entries
# separated the regex in SPLIT_TEMPLATES with optional spaces on either end,
# the template is split into multiple copies, each with one of the entries,
# and the templates are comma-separated.
#
# If QUIET, don't output the list of processed templates at the end.
def process_links(save, verbose, lang, longlang, cattype, startFrom, upTo,
    process_param, join_actions=None, split_templates="[,]",
    pages_to_do=[], quiet=False):
  templates_changed = {}
  templates_seen = {}

  if isinstance(lang, basestring):
    lang = [lang]

  # Process the link-like templates on the page with the given title and text,
  # calling PROCESSFN for each pair of foreign/Latin. Return a list of
  # changelog actions.
  def do_process_one_page_links(pagetitle, index, text, processfn):
    def pagemsg(text):
      msg("Page %s %s: %s" % (index, pagetitle, text))

    actions = []
    for template in text.filter_templates():
      def getp(param):
        return getparam(template, param)
      tempname = unicode(template.name)
      def doparam(param, tlang, trparam="tr", noadd=False):
        if not getp(param):
          return False
        if not noadd:
          templates_seen[tempname] = templates_seen.get(tempname, 0) + 1
        result = processfn(pagetitle, index, template, tlang, param, trparam)
        if result and isinstance(result, list):
          actions.extend(result)
          if not noadd:
            templates_changed[tempname] = templates_changed.get(tempname, 0) + 1
          return True
        return False

      did_template = False
      if "grc" in lang:
        # Special-casing for Ancient Greek
        did_template = True
        def dogrcparam(trparam):
          if getp("head"):
            doparam("head", "grc", trparam)
          else:
            doparam(["page title", "head"], "grc", trparam)
        if tempname in ["grc-noun-con"]:
          dogrcparam("5")
        elif tempname in ["grc-proper noun", "grc-noun"]:
          dogrcparam("4")
        elif tempname in ["grc-adj-1&2", "grc-adj-1&3", "grc-part-1&3"]:
          dogrcparam("3")
        elif tempname in ["grc-adj-2nd", "grc-adj-3rd", "grc-adj-2&3"]:
          dogrcparam("2")
        elif tempname in ["grc-num"]:
          dogrcparam("1")
        elif tempname in ["grc-verb"]:
          dogrcparam("tr")
        else:
          did_template = False
      if "ru" in lang:
        # Special-casing for Russian
        if tempname in ["ru-participle of", "ru-abbrev of", "ru-etym abbrev of",
            "ru-acronym of", "ru-etym acronym of", "ru-initialism of",
            "ru-etym initialism of", "ru-clipping of", "ru-etym clipping of",
            "ru-pre-reform"]:
          if getp("2"):
            doparam("2", "ru")
          else:
            doparam("1", "ru")
          did_template = True
        elif tempname == "ru-xlit":
          doparam("1", "ru", None)
          did_template = True
        elif tempname == "ru-ux":
          doparam("1", "ru")
          did_template = True

      # Skip {{attention|ar|FOO}} or {{etyl|ar|FOO}} or {{audio|FOO|lang=ar}}
      # or {{lb|ar|FOO}} or {{context|FOO|lang=ar}} or {{Babel-2|ar|FOO}}
      # or various others, where FOO is not Arabic, and {{w|FOO|lang=ar}}
      # or {{wikipedia|FOO|lang=ar}} or {{pedia|FOO|lang=ar}} etc., where
      # FOO is Arabic but diacritics aren't stripped so shouldn't be added.
      if (tempname in [
        "attention",
        "audio", "audio-IPA",
        "catlangcode", "C", "catlangname",
        "commonscat",
        "etyl", "etym",
        "gloss",
        "label", "lb", "lbl", "context", "cx",
        "non-gloss definition", "non-gloss", "non gloss", "n-g",
        "qualifier", "qual", "i", "italbrac",
        "rfe", "rfinfl",
        "sense", "italbrac-colon",
        "senseid",
        "given name",
        "+preo", "IPA", "phrasebook", "PIE root", "surname", "Q", "was fwotd",
        # skip Wikipedia templates
        "wikipedia", "w", "pedialite", "pedia"]
        # More Wiki-etc. templates
        or tempname.startswith("projectlink")
        or tempname.startswith("PL:")
        # Babel templates indicating language proficiency
        or "Babel" in tempname):
        pass
      elif did_template:
        pass
      # Look for {{head|ar|...|head=<ARABIC>}}
      elif tempname == "head":
        tlang = getp("1")
        if tlang in lang:
          if getp("head"):
            doparam("head", tlang)
          else:
            doparam(["page title", "head"], tlang)
      # Look for {{t|ar|<PAGENAME>|alt=<ARABICTEXT>}}
      elif tempname in ["t", "t+", "t-", "t+check", "t-check"]:
        tlang = getp("1")
        if tlang in lang:
          if getp("alt"):
            doparam("alt", tlang)
          else:
            doparam("2", tlang)
      # Look for {{suffix|ar|<PAGENAME>|alt1=<ARABICTEXT>|<PAGENAME>|alt2=...}}
      # or  {{suffix|ar|<ARABICTEXT>|<ARABICTEXT>|...}}
      elif (tempname in ["suffix", "suffix2", "prefix", "confix", "affix",
          "circumfix", "infix", "compound"]):
        tlang = getp("lang")
        if tlang in lang:
          templates_seen[tempname] = templates_seen.get(tempname, 0) + 1
          anychanged = False
          # Don't just do cases up through where there's a numbered param
          # because there may be holes.
          for i in xrange(1, 11):
            if getp("alt" + str(i)):
              changed = doparam("alt" + str(i), tlang, "tr" + str(i), noadd=True)
            else:
              changed = doparam(str(i), tlang, "tr" + str(i), noadd=True)
            anychanged = anychanged or changed
          if anychanged:
            templates_changed[tempname] = templates_changed.get(tempname, 0) + 1
      elif tempname == "form of":
        tlang = getp("lang")
        if tlang in lang:
          if getp("3"):
            doparam("3", tlang)
          else:
            doparam("2", tlang)
      # Templates where we don't check for alternative text because
      # the following parameter is used for the translation.
      elif tempname in ["ux", "lang"]:
        tlang = getp("1")
        if tlang in lang:
          doparam("2", tlang)
      elif tempname == "usex":
        tlang = getp("lang")
        if tlang in lang:
          doparam("1", tlang)
      elif tempname == "cardinalbox":
        tlang = getp("1")
        if tlang in lang:
          pagemsg("WARNING: Encountered cardinalbox, check params carefully: %s"
              % unicode(template))
          # FUCKME: This is a complicated template, might be doing it wrong
          doparam("5", tlang, None)
          doparam("6", tlang, None)
          for p in ["card", "ord", "adv", "mult", "dis", "coll", "frac",
              "optx", "opt2x"]:
            if getp(p + "alt"):
              doparam(p + "alt", tlang, p + "tr")
            else:
              doparam(p, tlang, p + "tr")
          if getp("alt"):
            doparam("alt", tlang)
          else:
            doparam("wplink", tlang, None)
      elif tempname in ["der2", "der3", "der4", "der5", "rel2", "rel3", "rel4",
          "rel5", "hyp2", "hyp3", "hyp4", "hyp5"]:
        tlang = getp("lang")
        if tlang in lang:
          i = 1
          while getp(str(i)):
            doparam(str(i), tlang, None)
            i += 1
      elif tempname == "elements":
        tlang = getp("lang")
        if tlang in lang:
          doparam("2", tlang, None)
          doparam("4", tlang, None)
          doparam("next2", tlang, None)
          doparam("prev2", tlang, None)
      elif tempname in ["bor", "borrowing"] and getp("lang"):
        tlang = getp("1")
        if tlang in lang:
          if getp("alt"):
            doparam("alt", tlang)
          elif getp("3"):
            doparam("3", tlang)
          else:
            doparam("2", tlang)
      elif tempname in ["der", "derived", "inh", "inherited", "bor", "borrowing"]:
        tlang = getp("2")
        if tlang in lang:
          if getp("alt"):
            doparam("alt", tlang)
          elif getp("4"):
            doparam("4", tlang)
          else:
            doparam("3", tlang)
      # Look for any other template with lang as first argument
      elif (#tempname in ["l", "link", "m", "mention"] and
          # If "1" matches, don't do templates with a lang= as well,
          # e.g. we don't want to do {{hyphenation|ru|men|lang=sh}} in
          # Russian because it's actually lang sh.
          getp("1") in lang and not getp("lang")):
        tlang = getp("1")
        # Look for:
        #   {{m|ar|<PAGENAME>|<ARABICTEXT>}}
        #   {{m|ar|<PAGENAME>|alt=<ARABICTEXT>}}
        #   {{m|ar|<ARABICTEXT>}}
        if getp("alt"):
          doparam("alt", tlang)
        elif getp("3"):
          doparam("3", tlang)
        elif tempname != "transliteration":
          doparam("2", tlang)
      # Look for any other template with "lang=ar" in it. But beware of
      # {{borrowing|en|<ENGLISHTEXT>|lang=ar}}.
      elif (#tempname in ["term", "plural of", "definite of", "feminine of", "diminutive of"] and
          getp("lang") in lang):
        tlang = getp("lang")
        # Look for:
        #   {{term|lang=ar|<PAGENAME>|<ARABICTEXT>}}
        #   {{term|lang=ar|<PAGENAME>|alt=<ARABICTEXT>}}
        #   {{term|lang=ar|<ARABICTEXT>}}
        if getp("alt"):
          doparam("alt", tlang)
        elif getp("2"):
          doparam("2", tlang)
        else:
          doparam("1", tlang)
    return actions

  # Process the link-like templates on the given page with the given text.
  # Returns the changed text along with a changelog message.
  def process_one_page_links(pagetitle, index, text):
    actions = []
    newtext = [unicode(text)]

    def pagemsg(text):
      msg("Page %s %s: %s" % (index, pagetitle, text))

    # First split up any templates with commas in the Latin
    if split_templates:
      def process_param_for_splitting(pagetitle, index, template, tlang, param, paramtr):
        if isinstance(param, list):
          fromparam, toparam = param
        else:
          fromparam = param
        if fromparam == "page title":
          foreign = pagetitle
        else:
          foreign = getparam(template, fromparam)
        latin = getparam(template, paramtr)
        if (re.search(split_templates, latin) and not
            re.search(split_templates, foreign)):
          trs = re.split("\\s*" + split_templates + "\\s*", latin)
          oldtemp = unicode(template)
          newtemps = []
          for tr in trs:
            addparam(template, paramtr, tr)
            newtemps.append(unicode(template))
          newtemp = ", ".join(newtemps)
          old_newtext = newtext[0]
          pagemsg("Splitting template %s into %s" % (oldtemp, newtemp))
          new_newtext = old_newtext.replace(oldtemp, newtemp)
          if old_newtext == new_newtext:
            pagemsg("WARNING: Unable to locate old template when splitting trs on commas: %s"
                % oldtemp)
          elif len(new_newtext) - len(old_newtext) != len(newtemp) - len(oldtemp):
            pagemsg("WARNING: Length mismatch when splitting template on tr commas, may have matched multiple templates: old=%s, new=%s" % (
              oldtemp, newtemp))
          newtext[0] = new_newtext
          return ["split %s=%s" % (paramtr, latin)]
        return []

      actions += do_process_one_page_links(pagetitle, index, text,
          process_param_for_splitting)
      text = parse_text(newtext[0])

    actions += do_process_one_page_links(pagetitle, index, text, process_param)
    if not join_actions:
      changelog = '; '.join(actions)
    else:
      changelog = join_actions(actions)
    #if len(terms_processed) > 0:
    pagemsg("Change log = %s" % changelog)
    return text, changelog

  def process_one_page_links_wrapper(page, index, text):
    return process_one_page_links(unicode(page.title()), index, text)

  if "," in cattype:
    cattypes = cattype.split(",")
  else:
    cattypes = [cattype]
  for cattype in cattypes:
    if cattype in ["translation", "links"]:
      if cattype == "translation":
        templates = ["t", "t+", "t-", "t+check", "t-check"]
      else:
        templates = ["l", "m", "term", "link", "mention"]
      for template in templates:
        msg("Processing template %s" % template)
        errmsg("Processing template %s" % template)
        for index, page in references("Template:%s" % template, startFrom, upTo):
          do_edit(page, index, process_one_page_links_wrapper, save=save,
              verbose=verbose)
    elif cattype == "pages":
      for pagename, index in iter_pages(pages_to_do, startFrom, upTo):
        page = pywikibot.Page(site, pagename)
        do_edit(page, index, process_one_page_links_wrapper, save=save,
            verbose=verbose)
    elif cattype == "pagetext":
      for current, index in iter_pages(pages_to_do, startFrom, upTo,
          key=lambda x:x[0]):
        pagetitle, pagetext = current
        do_process_text(pagetitle, pagetext, index, process_one_page_links,
            verbose=verbose)
    else:
      if cattype == "vocab":
        cats = ["%s lemmas" % longlang, "%s non-lemma forms" % longlang]
      elif cattype == "borrowed":
        cats = [subcat for subcat, index in
            cat_subcats("Terms derived from %s" % longlang)]
      else:
        cats = [cattype]
        #raise ValueError("Category type '%s' should be 'vocab', 'borrowed', 'translation', 'links', 'pages' or 'pagetext'")
      for cat in cats:
        msg("Processing category %s" % unicode(cat))
        errmsg("Processing category %s" % unicode(cat))
        for index, page in cat_articles(cat, startFrom, upTo):
          do_edit(page, index, process_one_page_links_wrapper, save=save,
              verbose=verbose)
  if not quiet:
    msg("Templates seen:")
    for template, count in sorted(templates_seen.items(), key=lambda x:-x[1]):
      msg("  %s = %s" % (template, count))
    msg("Templates processed:")
    for template, count in sorted(templates_changed.items(), key=lambda x:-x[1]):
      msg("  %s = %s" % (template, count))

def find_lang_section(pagename, lang, pagemsg):
  page = pywikibot.Page(site, pagename)
  if not try_repeatedly(lambda: page.exists(), pagemsg,
      "check page existence"):
    pagemsg("Page %s doesn't exist" % pagename)
    return False

  pagetext = unicode(page.text)

  # Split into sections
  splitsections = re.split("(^==[^=\n]+==\n)", pagetext, 0, re.M)
  # Extract off pagehead and recombine section headers with following text
  pagehead = splitsections[0]
  sections = []
  for i in xrange(1, len(splitsections)):
    if (i % 2) == 1:
      sections.append("")
    sections[-1] += splitsections[i]

  # Go through each section in turn, looking for existing language section
  for i in xrange(len(sections)):
    m = re.match("^==([^=\n]+)==$", sections[i], re.M)
    if not m:
      pagemsg("Can't find language name in text: [[%s]]" % (sections[i]))
    elif m.group(1) == lang:
      return sections[i]

  return None

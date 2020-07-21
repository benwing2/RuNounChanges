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
from collections import defaultdict
import xml.sax
import difflib
import traceback

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

def errandmsg(text):
  msg(text)
  errmsg(text)

def errmsgn(text):
  msgn(text)
  errmsgn(text)

def rsub_repeatedly(fr, to, text):
  while True:
    newtext = re.sub(fr, to, text)
    if newtext == text:
      return text
    text = newtext

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

def bool_param_is_true(param):
  return param and param not in ["0", "no", "n", "false"]

def tname(template):
  return unicode(template.name).strip()

def pname(param):
  return unicode(param.name).strip()

def set_template_name(template, name, origname=None):
  if not origname:
    origname = unicode(template.name)
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
# is named FIRST, and the remainder are named PREF2, PREF3, etc. FIRST can be
# a list of parameters to try in turn. If FIRSTDEFAULT is given, use if FIRST
# is missing or empty. This also checks for PREF if not the same as FIRST or
# (if FIRST is a list) any element of FIRST, and PREF1, because the
# parameter-handling code checks for both. Finally, it allows gaps in the
# numbered parameters, because the parameter-handling code allows them.
def fetch_param_chain(t, first, pref, firstdefault=""):
  ret = []
  if type(first) is not list:
    first = [first]
  val = None
  for f in first:
    val = getparam(t, f)
    if val:
      ret.append(val)
      break
  else:
    # no break
    if firstdefault:
      ret.append(firstdefault)
  if pref != first and (type(first) is not list or pref not in first):
    val = getparam(t, pref)
    if val:
      ret.append(val)
  for i in xrange(1, 30):
    val = getparam(t, pref + str(i))
    if val:
      ret.append(val)
  return ret

def append_param_to_chain(t, val, firstparam, parampref, before=None):
  paramno = 0
  while True:
    paramno += 1
    next_param = firstparam if paramno == 1 else "%s%s" % (
        parampref, paramno)
    if not getparam(t, next_param):
      t.add(next_param, val, before=before)
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

def set_param_chain(t, values, firstparam, parampref, before=None):
  paramno = 0
  for val in values:
    paramno += 1
    next_param = firstparam if paramno == 1 else "%s%s" % (
        parampref, paramno)
    t.add(next_param, val, before=before)
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
  result = try_repeatedly(lambda: site.expand_text(tempcall, title=pagetitle), pagemsg, "expand text: %s" % tempcall, bad_value_ret='<strong class="error">Invalid title</strong>')
  if verbose:
    pagemsg("Raw result is %s" % result)
  if result.startswith('<strong class="error">'):
    result = re.sub("<.*?>", "", result)
    if not verbose:
      pagemsg("Expanding text: %s" % tempcall)
    pagemsg("WARNING: Got error: %s" % result)
    return False
  return result

# For use inside of expand_text in EditParams below.
def blib_expand_text(tempcall, pagetitle, pagemsg, verbose):
  return expand_text(tempcall, pagetitle, pagemsg, verbose)

class EditParams(object):
  def __init__(self, index, page, save=False, verbose=False, diff=False):
    self.index = index
    self.page = page
    self.title = unicode(page.title())
    self.save = save
    self.verbose = verbose
    self.diff = diff

  def pagemsg(self, txt):
    msg("Page %s %s: %s" % (self.index, self.title, txt))

  def errandpagemsg(self, txt):
    errandmsg("Page %s %s: %s" % (self, index, self, title, txt))

  def expand_text(self, tempcall):
    return blib_expand_text(tempcall, self.title, self.pagemsg, self.verbose)

def new_do_edit(index, page, func=None, null=False, save=False, verbose=False, diff=False):
  p = EditParams(index, page, save=save, verbose=verbose, diff=diff)
  while True:
    try:
      if func:
        if verbose:
          p.pagemsg("Begin processing")
        retval = func(page, index, parse(page))
        if retval is None:
          new = None
          comment = None
        else:
          new, comment = retval

        if type(comment) is list:
          comment = "; ".join(group_notes(comment))

        if new:
          new = unicode(new)

          # Canonicalize shaddas when comparing pages so we don't do saves
          # that only involve different shadda orders.
          if reorder_shadda(page.text) != reorder_shadda(new):
            if diff:
              p.pagemsg('Diff:')
              oldlines = page.text.splitlines(True)
              newlines = new.splitlines(True)
              diff = difflib.unified_diff(oldlines, newlines)
              dangling_newline = False
              for line in diff:
                dangling_newline = not line.endswith('\n')
                sys.stdout.write(line.encode('utf-8'))
                if dangling_newline:
                  sys.stdout.write("\n")
              if dangling_newline:
                sys.stdout.write("\\ No newline at end of file\n")
              #pywikibot.showDiff(page.text, new, context=3)
            elif verbose:
              p.pagemsg('Replacing <%s> with <%s>' % (page.text, new))
            assert comment

            page.text = new
            if save:
              p.pagemsg("Saving with comment = %s" % comment)
              page.save(comment = comment)
            else:
              p.pagemsg("Would save with comment = %s" % comment)
          elif null:
            p.pagemsg('Purged page cache')
            page.purge(forcelinkupdate = True)
          else:
            p.pagemsg('Skipped, no changes')
        elif null:
          p.pagemsg('Purged page cache')
          page.purge(forcelinkupdate = True)
        else:
          p.pagemsg('Skipped: %s' % comment)
      else:
        p.pagemsg('Purged page cache')
        page.purge(forcelinkupdate = True)
    except (pywikibot.LockedPage, pywikibot.NoUsername):
      p.errandpagemsg('WARNING: Skipped, page is protected')
    except pywikibot.exceptions.PageSaveRelatedError as e:
      p.errandpagemsg('WARNING: Skipped, unable to save (abuse filter?): %s' % e)
    except urllib2.HTTPError as e:
      if e.code != 503:
        raise
    except:
      p.errandpagemsg('WARNING: Error')
      raise

    break

def do_edit(page, index, func=None, null=False, save=False, verbose=False, diff=False):
  title = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, title, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, title, txt))
  while True:
    try:
      if func:
        if verbose:
          pagemsg("Begin processing")
        retval = func(page, index, parse(page))
        if retval is None:
          new = None
          comment = None
        else:
          new, comment = retval

        if type(comment) is list:
          comment = "; ".join(group_notes(comment))

        if new:
          new = unicode(new)

          # Canonicalize shaddas when comparing pages so we don't do saves
          # that only involve different shadda orders.
          if reorder_shadda(page.text) != reorder_shadda(new):
            if diff:
              pagemsg('Diff:')
              oldlines = page.text.splitlines(True)
              newlines = new.splitlines(True)
              diff = difflib.unified_diff(oldlines, newlines)
              dangling_newline = False
              for line in diff:
                dangling_newline = not line.endswith('\n')
                sys.stdout.write(line.encode('utf-8'))
                if dangling_newline:
                  sys.stdout.write("\n")
              if dangling_newline:
                sys.stdout.write("\\ No newline at end of file\n")
              #pywikibot.showDiff(page.text, new, context=3)
            elif verbose:
              pagemsg('Replacing <%s> with <%s>' % (page.text, new))
            assert comment

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
      errandpagemsg('WARNING: Skipped, page is protected')
    except pywikibot.exceptions.PageSaveRelatedError as e:
      # This needs to have Unicode format string or it will choke on
      # exceptions with Unicode characters in the message.
      errandpagemsg(u'WARNING: Skipped, unable to save (abuse filter?): %s' % e)
    except urllib2.HTTPError as e:
      if e.code != 503:
        raise
    except:
      errandpagemsg(u'WARNING: Error')
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

# we special-case anything with " talk:" in the title
talk_prefixes = ["Talk:", "Thread:",
  "Wiktionary:Beer parlour", "Wiktionary:Translation requests",
  "Wiktionary:Grease pit", "Wiktionary:Etymology scriptorium",
  "Wiktionary:Information desk", "Wiktionary:Tea room",
  "Wiktionary:Requests", "Wiktionary:Requested",
  "Wiktionary:Wikimedia Tech News", "Wiktionary:Feedback",
  "Wiktionary:Word of the day", "Wiktionary:Foreign Word of the Day",
  "Wiktionary:Sandbox", "Wiktionary:Votes", "Wiktionary:Wanted entries"
]

non_talk_ignore_regexps = ["^Module:", "^MediaWiki:", r"\.js$", r"\.css$"]

def is_talk_page(pagetitle):
  for tp in talk_prefixes:
    if pagetitle.startswith(tp):
      return True
  if " talk:" in pagetitle:
    return True
  return False

def page_should_be_ignored(pagetitle, allow_user_pages=False):
  # Ignore discussion pages and certain other pages, e.g. user pages
  if is_talk_page(pagetitle):
    return True
  for ignore_re in non_talk_ignore_regexps:
    if re.search(ignore_re, pagetitle):
      return True
  if not allow_user_pages and pagetitle.startswith('User:'):
    return True
  return False

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
    if not page_should_be_ignored(pagetitle):
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


def references(page, startsort = None, endsort = None, namespaces = None,
    only_template_inclusion = False, filter_redirects = False, include_page = False):
  if isinstance(page, basestring):
    page = pywikibot.Page(site, page)
  pageiter = page.getReferences(only_template_inclusion = only_template_inclusion,
      namespaces = namespaces, filter_redirects = filter_redirects)
  if include_page:
    pages = list(pageiter) + [page]
  else:
    pages = pageiter
  for i, current in iter_items(pages, startsort, endsort):
    yield i, current

def get_contributions(user, startsort=None, endsort=None, max=None, ns=None):
  """Get contributions for a given user."""
  itemiter = site.usercontribs(user=user, namespaces=ns, total=max)
  for i, current in iter_items(itemiter, startsort, endsort, get_name=lambda item: item['title']):
    yield i, current

def raw_cat_articles(page, startsort, recurse):
  if type(page) is list:
    for cat in page:
      if isinstance(cat, basestring):
        msg("Processing category %s" % unicode(cat))
        errmsg("Processing category %s" % unicode(cat))
      for article in raw_cat_articles(cat, startsort, recurse):
        yield article
  else:
    if type(page) is str:
      page = page.decode("utf-8")
    if isinstance(page, basestring):
      page = pywikibot.Category(site, "Category:" + page)
    for article in page.articles(startsort=startsort if not isinstance(startsort, int) else None, recurse=recurse):
      yield article

def cat_articles(page, startsort=None, endsort=None, recurse=False):
  for i, current in iter_items(raw_cat_articles(page, startsort, recurse), startsort, endsort):
    yield i, current

def cat_subcats(page, startsort=None, endsort=None, recurse=False):
  if type(page) is str:
    page = page.decode("utf-8")
  if isinstance(page, basestring):
    page = pywikibot.Category(site, "Category:" + page)
  pageiter = page.subcategories(recurse=recurse) #no startsort; startsort = startsort if not isinstance(startsort, int) else None)
  for i, current in iter_items(pageiter, startsort, endsort):
    yield i, current

def prefix(prefix, startsort = None, endsort = None, namespace = None):
  pageiter = site.prefixindex(prefix, namespace)
  for i, current in iter_items(pageiter, startsort, endsort):
    yield i, current

def query_special_pages(specialpage, startsort = None, endsort = None):
  for i, current in iter_items(site.querypage(specialpage), startsort, endsort):
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

class ProcessItems(object):
  def __init__(self, startsort=None, endsort=None, get_name=get_page_name,
      skip_ignorable_pages=False):
    self.startsort = startsort
    self.endsort = endsort
    self.get_name = get_name
    self.skip_ignorable_pages = skip_ignorable_pages
    self.i = 0
    self.t = None
    self.steps = 50
    self.skipsteps = 1000
    self.no_time_output = True

  def should_process(self, item):
    self.i += 1

    if self.startsort != None:
      should_skip = False
      if isinstance(self.startsort, int):
        if self.i < self.startsort:
          should_skip = True
      elif self.get_name(item) < self.startsort:
        should_skip = True
      if should_skip:
        if self.i % self.skipsteps == 0:
          pywikibot.output("skipping %s" % str(self.i))
        return False

    if self.endsort != None:
      if isinstance(self.endsort, int):
        if self.i > self.endsort:
          return None
      elif self.get_name(item) > self.endsort:
        return None

    if isinstance(self.endsort, int) and not self.t:
      self.t = datetime.datetime.now()

    if self.skip_ignorable_pages and page_should_be_ignored(get_name(item)):
      pywikibot.output("Page %s %s: page has a prefix or suffix indicating it should not be touched, skipping" % (
        self.i, get_name(item)))
      retval = False
    else:
      retval = self.i

    if self.i % self.steps == 0:
      tdisp = ""

      if isinstance(self.endsort, int):
        told = self.t
        self.t = datetime.datetime.now()
        pagesleft = (self.endsort - self.i) / self.steps
        tfuture = self.t + (self.t - told) * pagesleft
        tdisp = ", est. " + tfuture.strftime("%X")

      pywikibot.output(str(self.i) + "/" + str(self.endsort) + tdisp)

    return retval

def iter_items(items, startsort=None, endsort=None, get_name=get_page_name,
    skip_ignorable_pages=False):
  i = 0
  t = None
  steps = 50
  skipsteps = 1000
  tstart = datetime.datetime.now()

  for current in items:
    i += 1

    if startsort != None:
      should_skip = False
      if isinstance(startsort, int):
        if i < startsort:
          should_skip = True
      elif get_name(current) < startsort:
        should_skip = True
      if should_skip:
        if i % skipsteps == 0:
          pywikibot.output("skipping %s" % str(i))
        continue

    if endsort != None:
      if isinstance(endsort, int):
        if i > endsort:
          break
      elif get_name(current) > endsort:
        break

    if isinstance(endsort, int) and not t:
      t = datetime.datetime.now()

    if skip_ignorable_pages and page_should_be_ignored(get_name(current)):
      pywikibot.output("Page %s %s: page has a prefix or suffix indicating it should not be touched, skipping" % (
        i, get_name(current)))
    else:
      yield i, current

    if i % steps == 0:
      tdisp = ""

      actual_startsort = startsort or 1
      if isinstance(endsort, int) and isinstance(actual_startsort, int):
        t = datetime.datetime.now()
        # Logically:
        #
        # time_so_far = t - tstart
        # pages_so_far = i - startsort + 1
        # time_per_page = time_so_far / pages_so_far
        # remaining_pages = endsort - i
        # remaining_time = time_per_page * remaining_pages
        #
        # We do the same but multiply before dividing, for increased precision and
        # due to the inability to multiply or divide timedeltas by floats.
        remaining_pages = endsort - i
        pages_so_far = i - startsort + 1
        remaining_time = (t - tstart) * remaining_pages / pages_so_far
        seconds_left = remaining_time.seconds
        hours_left_in_day = seconds_left // 3600
        hours_left = remaining_time.days * 24 + hours_left_in_day
        seconds_left_in_hour = seconds_left - 3600 * hours_left_in_day
        minutes_left_in_hour = seconds_left_in_hour // 60
        seconds_left_in_minute = seconds_left_in_hour - 60 * minutes_left_in_hour
        seconds_left_str = (
          "1 second" if seconds_left_in_minute == 1 else
          "%s seconds" % seconds_left_in_minute
        )
        minutes_left_str = (
          "" if minutes_left_in_hour == 0 else
          "1 minute" if minutes_left_in_hour == 1 else
          "%s minutes" % minutes_left_in_hour
        )
        hours_left_str = (
          "" if hours_left == 0 else
          "1 hour" if hours_left == 1 else
          "%s hours" % hours_left
        )
        time_left_str = ", ".join(
          x for x in [hours_left_str, minutes_left_str, seconds_left_str] if x
        )
        tdisp = ", est. %s left" % time_left_str

      pywikibot.output(str(i) + "/" + str(endsort) + tdisp)

def group_notes(notes):
  if isinstance(notes, basestring):
    return [notes]
  notes_count = {}
  uniq_notes = []
  # Preserve ordering of notes but combine duplicate notes with previous notes,
  # maintaining a count.
  for note in notes:
    if note in notes_count:
      notes_count[note] += 1
    else:
      notes_count[note] = 1
      uniq_notes.append(note)
  def fmt_note(note):
    count = notes_count[note]
    if count == 1:
      return "%s" % note
    else:
      return "%s (%s)" % (note, count)
  notes = [fmt_note(note) for note in uniq_notes]
  return notes

starttime = time.time()

def create_argparser(desc, include_pagefile=False, include_stdin=False,
    no_beginning_line=False):
  if not no_beginning_line:
    msg("Beginning at %s" % time.ctime(starttime))
  parser = argparse.ArgumentParser(description=desc)
  parser.add_argument('start', help="Starting page index", nargs="?")
  parser.add_argument('end', help="Ending page index", nargs="?")
  parser.add_argument('-s', '--save', action="store_true", help="Save results")
  parser.add_argument('-v', '--verbose', action="store_true", help="More verbose output")
  parser.add_argument('-d', '--diff', action="store_true", help="Show diff of changes")
  if include_pagefile:
    parser.add_argument("--pagefile", help="File listing pages to process.")
    parser.add_argument("--pages", help="List of pages to process, comma-separated.")
    parser.add_argument("--cats", help="List of categories to process, comma-separated.")
    parser.add_argument("--do-subcats", action="store_true",
      help="When processing categories, do subcategories instead of pages belong to the category.")
    parser.add_argument("--recursive", action="store_true",
      help="In conjunction with --cats, recursively process pages in subcategories.")
    parser.add_argument("--refs", help="List of references to process, comma-separated.")
    parser.add_argument("--specials", help="Special pages to do, comma-separated.")
    parser.add_argument("--ref-namespaces", help="List of namespace(s) to restrict --refs to.")
    parser.add_argument("--filter-pages", help="Regex to use to filter page names.")
    parser.add_argument("--filter-pages-not", help="Regex to use to filter page names; only includes pages not matching this regex.")
  if include_stdin:
    parser.add_argument("--stdin", help="Read dump from stdin.", action="store_true")
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

# Process a run of pages, with the set of pages coming from either
# --pagefile, --cats, --refs, or (if --stdin is given) from a Wiktionary
# dump read from stdin. PROCESS is called to process the page, and has
# different calling conventions depending on the EDIT and STDIN flags:
#
# If stdin=True, PROCESS should be defined like this:
#
# def process_text_on_page(index, pagetitle, text):
#   ...
#
# If stdin=False and edit=True, PROCESS should be defined like this:
#
# def process_page(page, index, parsed):
#   ...
#
# If stdin=False and edit=False, PROCESS should be defined like this:
#
# def process_page(page, index):
#   ...
#
# FIXME: The PARSED argument is unnecessary and shouldn't be passed in.
#
# The return value of PROCESS is immaterial if edit=False; otherwise it
# should be NEWTEXT, NOTES where NEWTEXT is the new text of the page,
# and NOTES is either a string (the comment to use when saving the page)
# or a list of strings (which are grouped together using blib.group_notes()
# to form the comment to use when saving the page). To make no change,
# return None, None.
#
# Note that if stdin=True and edit=True, there's (currently) no way to save
# a page if the page's source is a dump on stdin; in that circumstance, the
# return value is ignored.
#
# The pages iterated over will be:
#
# 1. Those from the dump on stdin if stdin=True and --stdin is given.
# 2. Else, the pages in --pages, --pagefile, --cats and/or --refs if any of
#    those arguments are given.
# 3. Else, pages in the category/categories in default_cats[] and/or pages
#    referring to the page(s) specified in default_refs[], if either argument
#    is given.
# 4. Else, an error is thrown.
#
# If only_lang is given, it should be a canonical name of a language (e.g.
# "Latin"), and pages not containing this language will be skipped. (This is
# especially useful in conjunction with dumps on stdin, where it can greatly
# speed up processing by avoiding the need to parse every page.)
#
# If filter_pages is given, it should be an unanchored regex used to filter
# page titles.
def do_pagefile_cats_refs(args, start, end, process, default_cats=[],
    default_refs=[], edit=False, stdin=False, only_lang=None,
    filter_pages=None, ref_namespaces=None):
  args_ref_namespaces = args.ref_namespaces and args.ref_namespaces.decode("utf-8")
  args_filter_pages = args.filter_pages and args.filter_pages.decode("utf-8")
  args_filter_pages_not = args.filter_pages_not and args.filter_pages_not.decode("utf-8")
  def process_page(page, i):
    if filter_pages or args_filter_pages:
      pagetitle = unicode(page.title())
      if filter_pages and not filter_pages(pagetitle):
        return
      if args_filter_pages and not re.search(args_filter_pages, pagetitle):
        return
      if args_filter_pages_not and re.search(args_filter_pages_not, pagetitle):
        return
    def do_process_page(page, index, parsed=None):
      if stdin:
        pagetitle = unicode(page.title())
        def pagemsg(txt):
          msg("Page %s %s: %s" % (index, pagetitle, txt))
        text = safe_page_text(page, pagemsg)
        if only_lang and "==%s==" % only_lang not in text:
          return None, None
        return process(index, pagetitle, text)
      else:
        if only_lang:
          pagetitle = unicode(page.title())
          def pagemsg(txt):
            msg("Page %s %s: %s" % (index, pagetitle, txt))
          text = safe_page_text(page, pagemsg)
          if "==%s==" % only_lang not in text:
            return None, None
        if edit:
          return process(page, index, parsed)
        else:
          return process(page, index)
    if edit:
      do_edit(page, i, do_process_page, save=args.save, verbose=args.verbose,
          diff=args.diff)
    else:
      do_process_page(page, i)

  if stdin and args.stdin:
    def do_process_text_on_page(index, pagetitle, text):
      if only_lang and "==%s==" % only_lang not in text:
        return None, None
      return process(index, pagetitle, text)
    parse_dump(sys.stdin, do_process_text_on_page, start, end)

  elif args.pages or args.pagefile or args.cats or args.refs or args.specials:
    if args.pages:
      pages = [x.decode("utf-8") for x in re.split(r",(?! )", args.pages)]
      for i, page in iter_items(pages, start, end):
        process_page(pywikibot.Page(site, page), i)
    if args.pagefile:
      pages = [x.rstrip('\n') for x in codecs.open(args.pagefile, "r", "utf-8")]
      for i, page in iter_items(pages, start, end):
        process_page(pywikibot.Page(site, page), i)
    if args.cats:
      for cat in [x.decode("utf-8") for x in re.split(r",(?! )", args.cats)]:
        if args.do_subcats:
          for i, subcat in cat_subcats(cat, start, end, recurse=args.recursive):
            process_page(subcat, i)
        else:
          for i, page in cat_articles(cat, start, end, recurse=args.recursive):
            process_page(page, i)
    if args.refs:
      for ref in [x.decode("utf-8") for x in re.split(r",(?! )", args.refs)]:
        # We don't use ref_namespaces here because the user might not want it.
        for i, page in references(ref, start, end, namespaces=args_ref_namespaces):
          process_page(page, i)
    if args.specials:
      for special in re.split(",(?! )", args.specials):
        for i, page in query_special_pages(special, start, end):
          process_page(page, i)

  else:
    if not args.cats and not args.refs:
      if not default_cats and not default_refs:
        raise ValueError("One of --pages, --pagefile, --cats or --refs should be specified")
    for cat in default_cats:
      for i, page in cat_articles(cat, start, end):
        process_page(page, i)
    for ref in default_refs:
      for i, page in references(ref, start, end, namespaces=ref_namespaces):
        process_page(page, i)

  elapsed_time()

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

  jsondata = site.expand_text(u"{{#invoke:User:MewBot|getLanguageData}}")
  languages = json.loads(jsondata)
  languages_byCode = {}
  languages_byCanonicalName = {}

  for lang in languages:
    languages_byCode[lang["code"]] = lang
    languages_byCanonicalName[lang["canonicalName"]] = lang


def getFamilyData():
  global families, families_byCode, families_byCanonicalName

  families = json.loads(site.expand_text(u"{{#invoke:User:MewBot|getFamilyData}}"))
  families_byCode = {}
  families_byCanonicalName = {}

  for fam in families:
    families_byCode[fam["code"]] = fam
    families_byCanonicalName[fam["canonicalName"]] = fam


def getScriptData():
  global scripts, scripts_byCode, scripts_byCanonicalName

  scripts = json.loads(site.expand_text(u"{{#invoke:User:MewBot|getScriptData}}"))
  scripts_byCode = {}
  scripts_byCanonicalName = {}

  for sc in scripts:
    scripts_byCode[sc["code"]] = sc
    scripts_byCanonicalName[sc["canonicalName"]] = sc


def getEtymLanguageData():
  global etym_languages, etym_languages_byCode, etym_languages_byCanonicalName

  etym_languages = json.loads(site.expand_text(u"{{#invoke:User:MewBot|getEtymLanguageData}}"))
  etym_languages_byCode = {}
  etym_languages_byCanonicalName = {}

  for etyl in etym_languages:
    etym_languages_byCode[etyl["code"]] = etyl
    etym_languages_byCanonicalName[etyl["canonicalName"]] = etyl

def try_repeatedly(fun, pagemsg, operation="save", bad_value_ret=None, max_tries=10, sleep_time=5):
  num_tries = 0
  while True:
    try:
      return fun()
    except KeyboardInterrupt as e:
      raise
    except pywikibot.exceptions.InvalidTitle as e:
      pagemsg("WARNING: Invalid title, skipping")
      traceback.print_exc(file=sys.stdout)
      return bad_value_ret
    except Exception as e:
      if "invalidtitle" in unicode(e):
        pagemsg("WARNING: Invalid title, skipping")
        traceback.print_exc(file=sys.stdout)
        return bad_value_ret
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

def safe_page_text(page, pagemsg):
  return try_repeatedly(lambda: page.text, pagemsg, "fetch page text", bad_value_ret="")

def safe_page_exists(page, pagemsg):
  return try_repeatedly(lambda: page.exists(), pagemsg, "determine if page exists", bad_value_ret=False)

# Process link-like templates containing foreign text in specified language(s),
# on pages from STARTFROM to (but not including) UPTO, either page names or
# 0-based integers. Save changes if SAVE is true. VERBOSE is passed to
# blib.do_edit and will (e.g.) show exact changes. PROCESS_PARAM is the
# function called, which is called with seven arguments: The page, its index
# (an integer), the page text, the template on the page, the language code of
# the template, the param in the template containing the foreign text and the
# param containing the Latin transliteration, or None if there is no such
# parameter. NOTE: The param may be an array ["page title", PARAM] for a case
# where the param value should be fetched from the page title and saved to
# PARAM. The function should return a list of changelog strings if changes
# were made, and something else otherwise (e.g. False). Changelog strings for
# all templates will be joined together using JOIN_ACTIONS; if not supplied,
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
  def do_process_one_page_links(pagetitle, index, pagetext, processfn):
    def pagemsg(text):
      msg("Page %s %s: %s" % (index, pagetitle, text))

    actions = []
    for template in pagetext.filter_templates():
      def getp(param):
        return getparam(template, param)
      tempname = unicode(template.name).strip()
      saw_template = [False]
      changed_template = [False]
      def doparam(param, tlang, trparam="tr", noadd=False):
        if type(param) is not list and not getp(param):
          return False
        saw_template[0] = True
        result = processfn(pagetitle, index, pagetext, template, tlang, param, trparam)
        if result and isinstance(result, list):
          actions.extend(result)
          changed_template[0] = True
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
      if "bg" in lang:
        # Special-casing for Bulgarian
        if tempname in ["bg-noun"]:
          if getp("head"):
            doparam("head", "bg")
          elif getp("sg"):
            doparam("sg", "bg")
          else:
            doparam(["page title", "head"], "bg")
          did_template = True
        elif tempname in ["bg-adj", "bg-proper noun"]:
          if getp("head"):
            doparam("head", "bg")
          else:
            doparam(["page title", "head"], "bg")
          did_template = True
        elif tempname in ["bg-verb"]:
          if getp("head"):
            doparam("head", "bg")
          else:
            doparam(["page title", "head"], "bg")
          doparam("pf", "bg", "pftr")
          doparam("pf2", "bg", "pf2tr")
          doparam("pf3", "bg", "pf3tr")
          doparam("impf", "bg", "impftr")
          doparam("impf2", "bg", "impf2tr")
          doparam("impf3", "bg", "impf3tr")
          did_template = True
        elif tempname in ["bg-phrase"]:
          if getp("head"):
            doparam("head", "bg")
          elif getp("1"):
            doparam("1", "bg")
          else:
            doparam(["page title", "1"], "bg")
          did_template = True
        elif tempname in ["bg-verb-form", "bg-noun-form", "bg-adj-form"]:
          if getp("head"):
            doparam("head", "bg", "2")
          else:
            doparam(["page title", "head"], "bg", "2")
          did_template = True

      # Skip {{attention|LANG|FOO}} or {{etyl|LANG|FOO}} or {{audio|FOO|lang=LANG}}
      # or {{lb|LANG|FOO}} or {{context|FOO|lang=LANG}} or {{Babel-2|LANG|FOO}}
      # or various others, where FOO is not LANG, and {{w|FOO|lang=LANG}}
      # or {{wikipedia|FOO|lang=LANG}} or {{pedia|FOO|lang=LANG}} etc., where
      # FOO is LANG but diacritics aren't stripped so shouldn't be added.
      if (tempname in [
        "attention", "attn",
        "audio", "audio-IPA",
        "catlangcode", "C", "catlangname", "cln",
        "commonscat",
        "etyl", "etym",
        "gloss",
        "hyphenation", "hyph",
        "label", "lb", "lbl", "context", "cx",
        "term-label", "tlb",
        "non-gloss definition", "non-gloss", "non gloss", "n-g",
        "place",
        "qualifier", "qual", "i", "italbrac",
        "rfe", "rfinfl", "rfc", "rfc-pron-n",
        "sense", "italbrac-colon",
        "senseid",
        "given name",
        "+preo", "phrasebook", "PIE root", "surname",
        "IPA", "IPAchar", "ru-IPA",
        "topics", "c",
        "was fwotd",
        # skip Wikipedia templates
        "pedialite", "pedia"]
        # More Wiki-etc. templates
        or tempname.startswith("projectlink")
        or tempname.startswith("PL:")
        # Babel templates indicating language proficiency
        or "Babel" in tempname):
        pass
      elif did_template:
        pass
      # Look for {{head|LANG|...|head=<FOREIGNTEXT>}}
      elif tempname == "head":
        tlang = getp("1")
        if tlang in lang:
          if getp("head"):
            doparam("head", tlang)
          else:
            doparam(["page title", "head"], tlang)
          for i in range(2, 11): # there may be holes
            doparam("head%s" % i, tlang, "tr%s" % i)
          for i in range(1, 11):
            if getp("f%salt" % i):
              doparam("f%salt" % i, tlang, "f%str" % i)
            else:
              doparam(str(i * 2 + 2), tlang, "f%str" % i)
      # Look for {{t|LANG|<PAGENAME>|alt=<FOREIGNTEXT>}}
      elif tempname in ["t", "t+", "t-", "t+check", "t-check"]:
        tlang = getp("1")
        if tlang in lang:
          if getp("alt"):
            doparam("alt", tlang)
          else:
            doparam("2", tlang)
      # Look for {{suffix|LANG|<PAGENAME>|alt1=<FOREIGNTEXT>|<PAGENAME>|alt2=...}}
      # or  {{suffix|LANG|<FOREIGNTEXT>|<FOREIGNTEXT>|...}}
      elif (tempname in ["suffix", "suf", "prefix", "pre", "affix", "af",
          "confix", "con", "circumfix", "infix", "compound", "com",
          "prefixusex", "prefex", "suffixusex", "sufex", "affixusex", "afex",
          "synonyms", "syn", "antonyms", "ant", "hypernyms", "hyper",
          "hyponyms", "hypo", "meronyms", "holonyms", "troponyms",
          "coordinate terms", "perfectives", "pf", "imperfectives", "impf",
          "homophones", "hmp"]):
        if tempname in ["suffix", "suf", "infix"]:
          params = [1]
        elif tempname in ["prefix", "pre", "circumfix"]:
          params = [2]
        elif tempname in ["confix", "con"]:
          if getp("3"):
            params = [2]
          else:
            params = []
        else:
          params = range(1, 11)
        tlang = getp("lang")
        offset = 0
        if not tlang:
          tlang = getp("1")
          offset = 1
        if tlang in lang:
          templates_seen[tempname] = templates_seen.get(tempname, 0) + 1
          # Don't just do cases up through where there's a numbered param
          # because there may be holes.
          for i in params:
            if getp("lang" + str(i)):
              continue
            if getp("alt" + str(i)):
              doparam("alt" + str(i), tlang, "tr" + str(i))
            else:
              doparam(str(i + offset), tlang, "tr" + str(i))
      elif tempname == "form of":
        tlang = getp("lang")
        if tlang in lang:
          if getp("3"):
            doparam("3", tlang)
          else:
            doparam("2", tlang)
      # Templates where we don't check for alternative text because
      # the following parameter is used for the translation.
      elif tempname in ["ux", "usex", "uxi", "quote"]:
        tlang = getp("1")
        if tlang in lang:
          doparam("2", tlang)
      elif tempname == "Q":
        tlang = getp("1")
        if tlang in lang:
          doparam("quote", tlang)
      elif tempname == "lang":
        tlang = getp("1")
        if tlang in lang:
          doparam("2", tlang, None)
      elif tempname in ["w", "wikipedia", "wp"]:
        tlang = getp("lang")
        if tlang in lang and getp("2"):
          # Can't replace param 1 (page linked to), but it's OK to frob the
          # display text
          doparam("2", tlang, None)
      elif tempname in ["w2"]:
        tlang = getp("1")
        if tlang in lang and getp("3"):
          # Can't replace param 2 (page linked to), but it's OK to frob the
          # display text
          doparam("3", tlang, "tr")
      elif tempname in ["cardinalbox", "ordinalbox"]:
        tlang = getp("1")
        if tlang in lang:
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
      elif tempname in ["quote-book", "quote-hansard", "quote-journal",
          "quote-newsgroup", "quote-song", "quote-us-patent", "quote-video",
          "quote-web", "quote-wikipedia"]:
        tlang = getp("lang") or getp("language")
        if tlang in lang:
          if getp("passage") or getp("text"):
            doparam("passage" if getp("passage") else "text", tlang,
              "transliteration" if getp("transliteration") else "tr")
      elif tempname == "alter":
        tlang = getp("1")
        if tlang in lang:
          i = 1
          while True:
            if getp("alt" + str(i)):
              doparam("alt" + str(i), tlang, "tr" + str(i))
            elif getp(str(i + 1)):
              doparam(str(i + 1), tlang, "tr" + str(i))
            else:
              break
            i += 1
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
      elif tempname in ["der", "derived", "inh", "inherited", "bor", "borrowing",
          "calque", "cal", "calq", "clq", "loan translation"]:
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
        #   {{m|LANG|<PAGENAME>|<FOREIGNTEXT>}}
        #   {{m|LANG|<PAGENAME>|alt=<FOREIGNTEXT>}}
        #   {{m|LANG|<FOREIGNTEXT>}}
        if getp("alt"):
          doparam("alt", tlang)
        elif getp("3"):
          doparam("3", tlang)
        elif tempname != "transliteration":
          doparam("2", tlang)
      # Look for any other template with "lang=LANG" in it. But beware of
      # {{borrowing|en|<ENGLISHTEXT>|lang=LANG}}.
      elif (#tempname in ["term", "plural of", "definite of", "feminine of", "diminutive of"] and
          getp("lang") in lang):
        tlang = getp("lang")
        # Look for:
        #   {{term|lang=LANG|<PAGENAME>|<FOREIGNTEXT>}}
        #   {{term|lang=LANG|<PAGENAME>|alt=<FOREIGNTEXT>}}
        #   {{term|lang=LANG|<FOREIGNTEXT>}}
        if getp("alt"):
          doparam("alt", tlang)
        elif getp("2"):
          doparam("2", tlang)
        else:
          doparam("1", tlang)
      if saw_template[0]:
        templates_seen[tempname] = templates_seen.get(tempname, 0) + 1
      if changed_template[0]:
        templates_changed[tempname] = templates_changed.get(tempname, 0) + 1
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
      def process_param_for_splitting(pagetitle, index, pagetext, template, tlang, param, paramtr):
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
      for index, pagename in iter_items(pages_to_do, startFrom, upTo):
        page = pywikibot.Page(site, pagename)
        do_edit(page, index, process_one_page_links_wrapper, save=save,
            verbose=verbose)
    elif cattype == "pagetext":
      for index, current in iter_items(pages_to_do, startFrom, upTo,
          get_name=lambda x:x[0]):
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
      for index, page in cat_articles(cats, startFrom, upTo):
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
  if safe_page_exists(page, pagemsg):
    pagemsg("Page %s doesn't exist" % pagename)
    return False

  pagetext = unicode(page.text)

  return find_lang_section_from_text(pagetext, lang, pagemsg)

def find_modifiable_lang_section(text, lang, pagemsg):
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  has_non_lang = False

  lang_j = -1
  for j in xrange(2, len(sections), 2):
    if sections[j-1] != "==" + lang + "==\n":
      has_non_lang = True
    else:
      if lang_j >= 0:
        pagemsg("WARNING: Found two %s sections, skipping" % lang)
        return None
      lang_j = j
  if lang_j < 0:
    pagemsg("Can't find %s section, skipping" % lang)
    return None
  j = lang_j

  # Extract off trailing separator
  mm = re.match(r"^(.*?\n)(\n*--+\n*)$", sections[j], re.S)
  if mm:
    secbody, sectail = mm.group(1), mm.group(2)
  else:
    secbody = sections[j]
    sectail = ""

  # Split off categories at end
  mm = re.match(r"^(.*?\n)(\n*((?:\[\[Category:[^\[\]\n]+\]\]|\{\{(?:c|C|cat|cln|topic|topics|categorize|catlangname|catlangcode)\|[^{}\n]*\}\})\n*)*)$",
      secbody, re.S)
  if mm:
    secbody, secbodytail = mm.group(1), mm.group(2)
    sectail = secbodytail + sectail

  return sections, j, secbody, sectail, has_non_lang

def split_text_into_sections(pagetext, lang):
  # Split into sections
  splitsections = re.split("(^==[^=\n]+==\n)", pagetext, 0, re.M)
  # Extract off pagehead and recombine section headers with following text
  pagehead = splitsections[0]
  sections = []
  for i in xrange(1, len(splitsections)):
    if (i % 2) == 1:
      sections.append("")
    sections[-1] += splitsections[i]
  return pagehead, sections

def find_lang_section_from_text(pagetext, lang, pagemsg):
  pagehead, sections = split_text_into_sections(pagetext, lang)

  # Go through each section in turn, looking for existing language section
  for i in xrange(len(sections)):
    m = re.match("^==([^=\n]+)==$", sections[i], re.M)
    if not m:
      pagemsg("Can't find language name in text: [[%s]]" % (sections[i]))
    elif m.group(1) == lang:
      return sections[i]

  return None

def replace_in_text(text, curr, repl, pagemsg, count=-1, no_found_repl_check=False,
    abort_if_warning=False):
  found_curr = curr in text
  if not found_curr:
    pagemsg("WARNING: Unable to locate current text: %s" % curr)
    return text, False
  if not no_found_repl_check:
    found_repl = repl in text
    if found_repl:
      pagemsg("WARNING: Already found replacement text: %s" % repl)
      return text, False
  newtext = text.replace(curr, repl, count)
  newtext_text_diff = len(newtext) - len(text)
  repl_curr_diff = len(repl) - len(curr)
  if repl_curr_diff == 0:
    if newtext_text_diff != 0:
      pagemsg("WARNING: Something wrong, no change in text length during replacement but expected change: Expected length change=%s, actual=%s, curr=%s, repl=%s"
          % (repl_curr_diff, newtext_text_diff, curr, repl))
      if abort_if_warning:
        return text, False
  else:
    ratio = float(newtext_text_diff) / repl_curr_diff
    if ratio == int(ratio):
      if int(ratio) > 1:
        pagemsg("WARNING: Replaced %s occurrences of curr=%s with repl=%s"
            % (int(ratio), curr, repl))
        if abort_if_warning:
          return text, False
    else:
      pagemsg("WARNING: Something wrong, length mismatch during replacement: Expected length change=%s, actual=%s, ratio=%.2f, curr=%s, repl=%s"
          % (repl_curr_diff, newtext_text_diff, ratio, curr, repl))
      if abort_if_warning:
        return text, False
  text = newtext
  return text, True

def split_generate_args(tempresult):
  args = {}
  for arg in re.split(r"\|", tempresult):
    name, value = arg.split("=")
    value = value.replace("<!>", "|").replace("<->", "=")
    # With manually specified declensions, we get back "-" for unspecified
    # forms, which need to be omitted; otherwise they're automatically omitted.
    if value != "-":
      args[name] = value
  return args

def compare_new_and_old_template_forms(origt, newt, generate_old_forms, generate_new_forms, pagemsg, errandpagemsg):
  old_result = generate_old_forms()
  if old_result is None:
    errandpagemsg("WARNING: Error generating old forms, can't compare")
    return False
  old_forms = split_generate_args(old_result)
  new_result = generate_new_forms()
  if new_result is None:
    errandpagemsg("WARNING: Error generating new forms, can't compare")
    return False
  new_forms = split_generate_args(new_result)
  for form in set(old_forms.keys() + new_forms.keys()):
    if form not in new_forms:
      pagemsg("WARNING: for original %s and new %s, form %s=%s in old forms but missing in new forms" % (
        origt, newt, form, old_forms[form]))
      return False
    if form not in old_forms:
      pagemsg("WARNING: for original %s and new %s, form %s=%s in new forms but missing in old forms" % (
        origt, newt, form, new_forms[form]))
      return False
    if new_forms[form] != old_forms[form]:
      pagemsg("WARNING: for original %s and new %s, form %s=%s in old forms but =%s in new forms" % (
        origt, newt, form, old_forms[form], new_forms[form]))
      return False
  pagemsg("%s and %s have same forms" % (origt, newt))
  return True

def find_defns(text, langcode):
  lines = text.split("\n")
  defns = []
  for line in lines:
    if not line.startswith('#'):
      continue
    if line.startswith('#:') or line.startswith('#*'):
      line = re.sub('^#[*:]+ *', '', line)
      line = re.sub(r'\{\{uxi?\|%s\|((?:[^{}]|\{\{.*?\}\})+)\}\}' % langcode, r'ux:\1', line)
    else:
      line = re.sub('^# *', '', line)
    def convert_to_parens(m):
      labels = m.group(1).split('|')
      return ''.join('(%s)' % label for label in labels)
    line = re.sub(r'\{\{lb\|%s\|(.*?)\}\} *' % langcode, convert_to_parens, line)
    line = line.replace(';', r'\;')
    defns.append(line)
  return defns

class WikiDumpHandler(xml.sax.ContentHandler):
  def __init__(self, pagecallback):
    self.pagecallback = pagecallback
    self.title = None
    self.text = None
    self.cur = None

  def startElement(self, name, attrs):
    if name == "title":
      self.cur = "title"
      self.title = ""
    elif name == "text":
      self.cur = "text"
      self.text = []

  def endElement(self, name):
    if name == "text":
      self.pagecallback(self.title, "".join(self.text))
    self.cur = None

  def characters(self, content):
    if self.cur == "title":
      self.title += content
    elif self.cur == "text":
      self.text.append(content)

class DumpExitException(Exception):
  pass

def parse_dump(fp, pagecallback, startsort=None, endsort=None,
    skip_ignorable_pages=False):
  item_handler = ProcessItems(startsort=startsort, endsort=endsort,
      skip_ignorable_pages=skip_ignorable_pages)

  def mycallback(title, text):
    retval = item_handler.should_process(title)
    if retval == None:
      raise DumpExitException
    if retval != False:
      pagecallback(retval, title, text)

  handler = WikiDumpHandler(mycallback)
  try:
    xml.sax.parse(fp, handler)
  except DumpExitException as e:
    return

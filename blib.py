#!/usr/bin/env python
#coding: utf-8

import pywikibot, mwparserfromhell, re, string, sys, codecs, urllib2, datetime, json

site = pywikibot.Site()

def msg(text):
  print text.encode('utf-8')

def parse(text):
  return mwparserfromhell.parser.Parser().parse(text, skip_style_tags=True))

def getparam(t, param):
  if t.has(param):
    return unicode(t.get(param))
  else:
    return ""

def rmparam(t, param):
  if t.has(param):
    t.remove(param)

def display(page):
  pywikibot.output(u'# [[{0}]]'.format(page.title()))

def dump(page):
  old = page.get(get_redirect=True)
  pywikibot.output(u'Contents of [[{0}]]:\n{1}\n----------'.format(page.title(), old), toStdout = True)

def do_edit(page, func=None, null=False, save=False):
  while True:
    try:
      if func:
        new, comment = func(page, parse(page.text))
        
        if new:
          new = unicode(new)
          
          if page.text != new:
            page.text = new
            if save:
              msg("%s: Saving with comment = %s" % (unicode(page.title), comment))
              page.save(comment = comment)
            else:
              msg("%s: Would save with comment = %s" % (unicode(page.title), comment))
          elif null:
            pywikibot.output(u'Purged page cache for [[{0}]]'.format(page.title()), toStdout = True)
            page.purge(forcelinkupdate = True)
          else:
            pywikibot.output(u'Skipped [[{0}]]: no changes'.format(page.title()), toStdout = True)
        elif null:
          pywikibot.output(u'Purged page cache for [[{0}]]'.format(page.title()), toStdout = True)
          page.purge(forcelinkupdate = True)
        else:
          pywikibot.output(u'Skipped [[{0}]]: {1}'.format(page.title(), comment), toStdout = True)
      else:
        pywikibot.output(u'Purged page cache for [[{0}]]'.format(page.title()), toStdout = True)
        page.purge(forcelinkupdate = True)
    except (pywikibot.LockedPage, pywikibot.NoUsername):
      pywikibot.output(u'Skipped [[{0}]], page is protected'.format(page.title()))
    except urllib2.HTTPError as e:
      if e.code != 503:
        raise
    except:
      pywikibot.output(u'Error on [[{0}]]'.format(page.title()))
      raise
    
    break

def references(page, startsort = None, endsort = None, namespaces = None, includelinks = False):
  if isinstance(page, basestring):
    page = pywikibot.Page(site, page)
  
  i = 0
  t = None
  steps = 50
  
  for current in page.getReferences(onlyTemplateInclusion = not includelinks, namespaces = namespaces):
    i += 1
    
    if endsort != None and i > endsort:
      break
    
    if startsort != None and i <= startsort:
      continue
    
    if endsort != None and not t:
      t = datetime.datetime.now()
    
    yield current
    
    if i % steps == 0:
      tdisp = ""
      
      if endsort != None:
        told = t
        t = datetime.datetime.now()
        pagesleft = (endsort - i) / steps
        tfuture = t + (t - told) * pagesleft
        tdisp = ", est. " + tfuture.strftime("%X")
      
      pywikibot.output(str(i) + "/" + str(endsort) + tdisp)


def cat_articles(page, startsort = None, endsort = None):
  if isinstance(page, basestring):
    page = pywikibot.Category(site, "Category:" + page)
  
  i = 0
  
  for current in page.articles(startsort = startsort if not isinstance(startsort, int) else None):
    i += 1
    
    if startsort != None and isinstance(startsort, int) and i <= startsort:
      continue
    
    if endsort != None:
      if isinstance(endsort, int):
        if i > endsort:
          break
      elif current.title(withNamespace=False) >= endsort:
        break
    
    yield current


def cat_subcats(page, startsort = None, endsort = None):
  if isinstance(page, basestring):
    page = pywikibot.Category(site, "Category:" + page)
  
  i = 0
  
  for current in page.subcategories(startsort = startsort if not isinstance(startsort, int) else None):
    i += 1
    
    if startsort != None and isinstance(startsort, int) and i <= startsort:
      continue
    
    if endsort != None:
      if isinstance(endsort, int):
        if i > endsort:
          break
      elif current.title() >= endsort:
        break
    
    yield current


def prefix(prefix, startsort = None, endsort = None, namespace = None):
  i = 0
  
  for current in site.prefixindex(prefix, namespace):
    i += 1
    
    if startsort != None and i <= startsort:
      continue
    
    if endsort != None and i > endsort:
      break
    
    yield current

def stream(st, startsort = None, endsort = None):
  i = 0
  
  for name in st:
    i += 1
    
    if startsort != None and i <= startsort:
      continue
    if endsort != None and i > endsort:
      break
    
    if type(name) == str:
      name = str.decode(name, "utf-8")
    
    name = re.sub(ur"^[#*] *\[\[(.+)]]$", ur"\1", name, flags=re.UNICODE)
    
    yield pywikibot.Page(site, name)


def get_args():
  startsort = None
  endsort = None
  
  if len(sys.argv) >= 2:
    try:
      startsort = int(sys.argv[1])
    except ValueError:
      startsort = str.decode(sys.argv[1], "utf-8")
  
  if len(sys.argv) >= 3:
    try:
      endsort = int(sys.argv[2])
    except ValueError:
      endsort = str.decode(sys.argv[2], "utf-8")
  
  return (startsort, endsort)

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

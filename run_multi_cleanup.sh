#!/bin/sh

langcode=
langname=
do_see_also=
no_synonyms=
no_partial_page=
while [ -n "$1" ]; do
  case "$1" in
    --langcode ) langcode="$2"; shift 2 ;;
    --langname ) langname="$2"; shift 2 ;;
    --do-see-also ) do_see_also="--do-see-also"; shift ;;
    --no-synonyms ) no_synonyms=1; shift ;;
    --no-partial-page ) no_partial_page=1; shift ;;
    -- ) shift; break ;;
    * ) echo "Unrecognized argument '$1'"; exit 1 ;;
  esac
done

if [ -z "$langcode" ]; then
  echo "--langcode required"
  exit 1
fi
if [ -z "$langname" ]; then
  echo "--langname required"
  exit 1
fi

FIX_LINKS="python3 fix_links.py --find-regex --langs $langcode --single-lang '$langname' $do_see_also"
TEMPLATIZE_CATEGORIES="python3 templatize_categories.py --find-regex --langname '$langname' --langcode $langcode"
MOVE_SYNONYMS="python3 move_synonyms.py --find-regex --langcode $langcode --langname '$langname'"
if [ -n "$no_partial_page" ]; then
  DETEMPLATIZE_EN_LINKS="python3 detemplatize_en_links.py --find-regex --langname '$langname'"
  CONVERT_ALT_FORMS="python3 convert_alt_forms.py --find-regex --langname '$langname'"
  MOVE_WIKIPEDIA="python3 move_wikipedia.py --find-regex --langname '$langname'"
else
  DETEMPLATIZE_EN_LINKS="python3 detemplatize_en_links.py --find-regex --partial-page"
  CONVERT_ALT_FORMS="python3 convert_alt_forms.py --find-regex --partial-page"
  MOVE_WIKIPEDIA="python3 move_wikipedia.py --find-regex --partial-page"
  MOVE_SYNONYMS="$MOVE_SYNONYMS --partial-page"
fi

if [ -n "$no_synonyms" ]; then
  CMD="$FIX_LINKS | $DETEMPLATIZE_EN_LINKS | $TEMPLATIZE_CATEGORIES | $CONVERT_ALT_FORMS | $MOVE_WIKIPEDIA"
else
  CMD="$FIX_LINKS | $DETEMPLATIZE_EN_LINKS | $TEMPLATIZE_CATEGORIES | $MOVE_SYNONYMS | $CONVERT_ALT_FORMS | $MOVE_WIKIPEDIA"
fi

echo "Running: $CMD" >&2
eval $CMD

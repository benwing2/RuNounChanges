--[=[
	This module contains functions to generate documentation for {{quote-*}} templates. The module contains the actual
	implementation, meant to be called from other Lua code. See [[Module:quote doc/templates]] for the function meant
	to be called directly from templates.

	Author: Benwing2
]=]

local export = {}

local m_table = require("Module:table")

local rfind = mw.ustring.find
local rsplit = mw.text.split
local rsubn = mw.ustring.gsub
local u = mw.ustring.char

local TEMP_DOUBLE_LBRACE = u(0xFFF0)
local TEMP_DOUBLE_RBRACE = u(0xFFF1)


-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end


local function preprocess(desc)
	if desc:find("{") then
		desc = mw.getCurrentFrame():preprocess(desc)
	end
	return desc
end

local function generate_param_intro_text(ty)
	return [=[
The following sections describe the possible parameters. There are many parameters, so they are divided into groups.
All parameters are optional except those marked '''(required)''' (which cause an error to be thrown if omitted) and
those marked '''(semi-required)''' (which result in a maintenance message if omitted). Parameters that are
'''boldfaced''' are specific to {{tl|]=] .. ty .. [=[}} and aren't shared with other {{tl|quote-*}} templates, or have
a significantly different interpretation.

All but the first group control the citation line (the initial line before the actual text of the quotation). The first
group controls the quotation lines (the lines displaying the text of the quote and optionally the translation,
transliteration, normalization, etc.).

Some parameters, such as titles, authors, publishers, etc. can contain foreign text. These parameters can have
associated ''annotations'', consisting of a language code prefix such as {ar:} for Arabic, {zh:}
for Chinese or {ru:} for Russian, and/or ''inline modifiers'' following the text. An example containing both
is <code>ru:Баллада о королевском бутерброде<t:Ballad of the King's Bread></code>, which displays as
"{{lang|ru|Баллада о королевском бутерброде}} [''Ballada o korolevskom buterbrode, Ballad of the King's Bread'']".
The language code helps ensure that the appropriate font is used when displaying the text (although script detection
happens even in the absence of such codes), and causes automatic transliteration to occur when possible, and the inline
modifiers specify translations, manual transliterations and the like.

The following special codes are recognized in place of language codes:
* {w:``link``}: Link to the English Wikipedia, e.g. {w:William Shakespeare}. This displays as {``link``}. This is
  equivalent to writing e.g. {{tl|w|William Shakespeare}}, which can also be used.
* {w:``lang``:``link``}: Link to another-language Wikipedia, e.g. {w:fr:Jeanne d'Arc}. This displays as {``link``}.
  This is equivalent to writing e.g. {{tl|w|2=lang=fr|3=Jeanne d'Arc}}, which can also be used.
* {lw:``lang``:``link``}: Link to another-language Wikipedia and format {``link``} according to the language code
  specified using {``lang``}, e.g. {lw:zh:毛泽东} (the Chinese written form of {{w|Mao Zedong}}). This requires that
  {``lang``} is a language code with the same meaning in both Wikipedia and Wiktionary (which applies to most Wikipedia
  language codes, but not to e.g. {hr} for the Croatian Wikipedia and {sr} for the Serbian Wikipedia, and not to
  certain more obscure languages). This is equivalent to writing e.g. {zh:&#123;&#123;w|lang=zh|毛泽东}}}. This will do
  language-specific script detection and formatting and tag the displayed form with the appropriate per-language CSS
  class. If automatic transliteration is enabled for the specified language, that transliteration will be displayed
  unless another transliteration is supplied using {<tr:...>} or transliteration display is disabled using {<tr:->}.
  Note that using e.g. {lw:ru:Лев Толстой} (the Russian written form of {{w|Leo Tolstoy}}) is somewhat similar to
  writing {{tl|lw|ru|Лев Толстой}} (hence the similarity of the prefix to the template name), but the latter will
  display transliterations the way that {{tl|l}} displays them (in parens rather than brackets), and using {{tl|lw}}
  prevents the use of any inline modifiers, as it formats into HTML.
* {lw:``lang``:&#91;&#91;``link``|``display``&#93;&#93;}: Link using {``link``} to another-language Wikipedia but
  display as {``display``}, formatting the display according to the language code specified using {``lang``}. This
  works like {lw:...} above but lets you specify the link and display differently, e.g.
  {lw:ru:&#91;&#91;Маркс, Карл|Карл Ге́нрих Маркс&#93;&#93;}, where the display form is the Russian written form of
  {{w|Karl Marx|Karl Heinrich Marx}} and the link form is how the name appears canonically in the Russian Wikipedia
  entry (with last name first).
* {w:&#91;&#91;``link``|``display``&#93;&#93;} and {w:``lang``:&#91;&#91;``link``|``display``&#93;&#93;}: Link to the
  English or another-language Wikipedia, specifying the link independently of the display form. These are less useful
  than the {lw:...} equivalent because you can also specify the Wikipedia link directly using e.g.
  {{code||[[w:William Shakespeare|W(illiam) Shakespeare]]}} or {{code||[[w:fr:Jeanne d'Arc|Joan of Arc]]}} with the
  same number of keystrokes.
* {s:``link``}: Link to the English Wikisource page for ``link``, e.g. {s:The Rainbow Trail} (a novel by
  {{w|Zane Grey}}).
* {s:``lang``:``link``}: Link to another-language Wikisource. This is conceptually similar to {w:``lang``:``link``}
  for Wikipedia.
* {ls:``lang``:``link``}: Link to another-language Wikisource and format {``link``} according to the language code
  specified using {``lang``}. This is conceptually similar to {lw:``lang``:``link``} for Wikipedia.
* {ls:``lang``:&#91;&#91;``link``|``display``&#93;&#93;}: Link using {``link``} to another-language Wikisource but
  display as {``display``}, formatting the display according to the language code specified using {``lang``}, e.g.
  {ls:ko:&#91;&#91;조선_독립의_서#一._槪論|조선 독립의 서&#93;&#93;} (a document about an independent Korea during the
  Japanese occupation). This is conceptually similar to {lw:``lang``:&#91;&#91;``link``|``display``&#93;&#93;} for
  Wikipedia.
* {s:&#91;&#91;``link``|``display``&#93;&#93;} and {s:``lang``:&#91;&#91;``link``|``display``&#93;&#93;}: Link to the
  English or another-language Wikisource, specifying the link independently of the display form. These are less useful
  than the {ls:...} equivalent because you can also specify the Wikisource link directly using e.g.
  {{code||[[s:The Tempest (Shakespeare)|The Tempest]]}} or
  {{code||[[s:fr:Fables de La Fontaine (édition originale)|Fables de La Fontaine]]}} using the same number of
  keystrokes.

In addition, certain parameters can contain multiple semicolon-separated ''entities'' (authors, publishers, etc.). This
applies in general to all parameters containing people (authors, translators, editors, etc.), as well as certain other
parameters, as marked below. In such parameters, each entity can have annotations in the form of a language code and/or
inline modifiers, as above. An example is <code>zh:張福運<t:Chang Fu-yun>; zh:張景文<t:Chang Ching-wen></code>,
specifying two Chinese-language names, each with a rendering into Latin script. In general, such parameters are ''not''
displayed with semicolons separating the entities, but more commonly with commas and/or the word ''and''; this depends
on the particular parameter and its position in the citation. The semicolons are simply used in the input to separate
the entities; commas aren't used because names can contain embedded commas, such as "{Sammy Davis, Jr.}" or
"{Alfred, Lord Tennyson}". Note that semicolons occurring inside of parentheses or square brackets are not
treated as delimiters; hence, a parameter value such as {George Orwell [pseudonym; Eric Blair]} specifies one
entity, not two. Similarly, HTML entities like {&amp;oacute;} with trailing semicolons are recognized as such
and not treated as delimiters.

For parameters that specify people (e.g. {{para|author}}, {{para|tlr}}/{{para|translator}}, {{para|editor}}), write
{et al.}after a semicolon as if it were a normal person. The underlying code will handle this specially,
displaying it in italics and omitting the delimiter that would normally be displayed beforehand.

As a special exception to separating entities with semicolons, if you put a comma as the first character of a
multi-entity parameter, it will ignore the comma and split the remainder on commas instead of on semicolons. For
example, {,Joe Bloggs, Mary Worth, et al.} is equivalent to {Joe Bloggs; Mary Worth; et al.}. It
is not generally recommended to use this format, but it can be helpful when copy-pasting a long, comma-separated string
of authors, e.g. from Google Scholar.

The following inline modifiers are recognized:]=]
end

local function generate_inline_modifiers(ty)
	return {
	{"t", [=[The translation of the parameter or entity in question. Displayed in square brackets following the
	parameter or entity value. For authors or other entities referring to people, it is preferred to use the
	<code><t:...></code> parameter to specify the "common" or non-scientific spelling of the name, and optionally to
	use the <code><tr:...></code> parameter to specify the scientific transliteration. For example, the Russian name
	{{m|ru||Пётр Чайко́вский|tr=-}} might be translated as {{w|Pyotr Tchaikovsky}} but transliterated as
	''Pjotr Čajkóvskij''. Include Wikipedia links as necessary using {{tl|w}} or directly using
	{{code||[[w:LINK|NAME]]}}.]=]},
	{"gloss", [=[Alias for <code><t:...></code>. Generally, <code><t:...></code> is preferred.]=]},
	{"alt", [=[Display form of the parameter or entity in question. Generally this isn't necessary, as you can always
	use a two-part link such as {{code||[[Dennis Robertson (economist)|D.H. Robertson]]}}.]=]},
	{"tr", [=[Transliteration of the parameter or entity in question, if not in Latin script. See <code><t:...></code>
	above for when to use transliterations vs. translations for names of people. If a language code prefix is given and
	the text is in a non-Latin script, an automatic transliteration will be provided if the language supports it and
	this modifier is not given. In that case, use <code><tr:-></code> to suppress the automatic transliteration.]=]},
	{"subst", [=[Substitution expression(s) used to ensure correct transliteration, in lieu of specifying manual
	transliteration. This modifier works identically to the {{para|subst}} parameter but applies to the entity in
	question rather than the overall text of the quotation. See the {{tl|quote-book}} examples for examples of how to
	use this.]=]},
	{"ts", [=[Transcription of the parameter or entity in question, if not in Latin script and in a language where
	the transliteration is markedly different from the actual pronunciation (e.g. Akkadian or Tibetan). Do not use this
	merely to supply an IPA pronunciation. If supplied, this is shown between slashes, e.g.
	<code>[``transliteration`` /``transcription``/, ``translation``]/code>.]=]},
	{"sc", [=[Script code of the text of the parameter or entity, if not in a Latn script. See [[Wiktionary:Scripts]].
	It is rarely necessary to specify this, as the script code is autodetected based on the text (usually
	correctly).]=]},
	{"f", [=["Foreign" version of the parameter or entity, i.e. the version in a different script from that of the
	value itself. This comes in several variants:
	# {<f:``foreign``>}: The simplest variant. The foreign text will have language-independent script detection
	  applied to it and will be shown as-is, inside brackets before the translation. It is generally not recommended to
	  use this format as the significance of the text may not be clear; use the variant below with a tag.
	# {<f:/``script``:``foreign``>}: Same as previous except that a script code is explicitly given, in case the
	  autodetection doesn't work right.
	# {<f:``tag``:``foreign``>}: Include a tag to be displayed before the foreign text. The tag can be a language
	  code (including etymology languages), a script code, or arbitrary text. If it is recognized as a language code,
	  the canonical name of the language will be displayed as the tag and the language will be used to do script
	  detection of the foreign text, based on the allowable scripts of the language. If the tag is recognized as a
	  script code, it will be used as the foreign text's script when displaying the text, and the script's canonical
	  name will be displayed as the tag. Otherwise, the tag can be arbitrary text (e.g. a transliteration system such
	  as `Pinyin`), and will be displayed as-is, with language-independent script detection done on the foreign text.
	# {<f:``tag``/``script``:``foreign``>}: Same as previous except that a script code is explicitly given, in case
	  autodetection doesn't work right.
	# {<f:``tag``,``tag``,...:``foreign``>}: Include multiple tags for a given foreign text. All tags are displayed
	  slash-separated as described above, but only the first tag given is used for script detection.
	# {<f:``tag``,``tag``,.../``script``:``foreign``>}: Same as previous except that a script code is explicitly given,
	  in case autodetection doesn't work right.

	Unlike with other inline modifiers, the {<f:...>} modifier can be specified multiple times to indicate different
	foreign renderings of a given entity. An example where this is useful is the following:
	* {Liou Kia-hway<f:Hant:劉家槐><f:Pinyin:Liú Jiāhuái>}

	Here, we specify the author's name as given in the source, followed by the original Chinese-language version as
	well as a standardized Pinyin version.]=]},
	{"q", [=[Left qualifier for the parameter or entity, shown before it like this: {{q|left qualifier}}.]=]},
	{"qq", [=[Right qualifier for the parameter or entity, shown after it like this: {{q|right qualifier}}.]=]},
}
end


--[===[
Descriptions of individual parameters for the citation portion of the quotation (i.e. the first line). Because there
are so many parameters, we divide them into groups. The value of the following is a list of parameter groups, where
each group is a list, structured as follows:
1. The first element is the title of the parameter group.
2. The optional next element, if a string, is prefatory text describing the group in more detail, and will be displayed
   before the table of parameters. The string can be multiline (use [=[...]=] to enclose the text), and continuation
   lines have special handling, as for parameter descriptions; see below.
3. All following elements describe individual parameters.

An individual parameter description is as follows:
1. The first element is the parameter name or names. If a string, it specifies the only possible name of the parameter,
   and is equivalent to a single-element list containing the parameter name. Use a list of strings to specify multiple
   aliases with the same meaning, e.g. {"tlr", "translator", "translators"}. You can also specify a list of logically
   related parameters, where all parameters are described using a single description. In such a case, specify
   <code>useand = true</code> after the parameter names, which causes the parameters to be joined using "and" instead
   of "or" (as is normal for aliases). If <code>useand</code> is given, the individual elements of the list may
   themselves be lists of aliases, which are displayed separated by slashes. Any element can also be, in place of a
   string, a table of the form {param = "PARAM", non_generic = BOOLEAN} where if <code>non_generic = true</code>, the
   parameter is specific to a particular {{tl|quote-*}} implementation rather than generic.

   For example:

   * {"tlr", "translator", "translators"} displays as "|tlr=, |translator= or |translators=", referring to three
     aliases.
   * {"chapter_series", "chapter_seriesvolume", useand = true} displays as "|chapter_series= and |chapter_seriesvolume=",
     referring to logically related parameters.
   * {{"chapter_series", {param = "entry_series", non_generic = true}},
      {"chapter_seriesvolume", {param = "entry_seriesvolume", non_generic = true}},
	  useand = true} displays as "|chapter_series=/<b>|entry_series=</b> and |chapter_seriesvolume=/<b>|entry_seriesvolume=</b>",
	 referring to alias sets of logically related parameters, some of which are non-generic (in this case, the
	 {{para|entry_*}} params are {{tl|quote-book}}-specific aliases).

   Other named fields are possible:
   * <code>useand = true</code>: Join the parameters using "and" instead of "or"; see above.
   * <code>annotated = true</code>: Indicate that the parameter(s) can be annotated with a language prefix and/or
     inline modifiers.
   * <code>multientity = true</code>: Indicate that the parameter(s) can consist of multiple semicolon-separated
     entities (such as authors, translators, editors, publishers or locations), each of which can be annotated with a
	 language prefix and/or inline modifiers.
   * <code>boolean = true</code>: The parameter(s) are boolean-valued, and will be shown as e.g. {{para|nodate|1}}
     instead of just e.g. {{para|date}}.
   * <code>required = true</code>: The parameter(s) are required, which will be shown as e.g. {{para|title|req=1}}
     instead of just e.g. {{para|author}}.
   * <code>literal = true</code>: The parameter value (of which there should be only one) contains already-formatted
     parameter descriptions and should be displayed as-is rather than further formatted.
2. The second element is the description of the parameter(s). The string can be multiline (use [=[...]=] to enclose the
   text), and continuation lines have special handling. Specifically, a newline and following whitespace will normally
   be converted into a single space, so that a long line can be broken into multiple lines and indented appropriately.
   This does not happen when there is more than one newline in a row (in such a case, all newlines are preserved as-is).
   If the first character on a line is a list element symbol (<code>#</code> or <code>*</code>), the whitespace before
   it is deleted but the preceding newline is left as-is. This allows lists to be given in parameter descriptions.
]===]

local function generate_params(ty)
	return {
	{"Quoted text parameters",
	[=[The following parameters describe the quoted text itself. This and the following parameter group (for the
	original quoted text) describe the text of the quotation, while all remaining parameter groups control the citation
	line. The parameters in this group can be omitted if the quoted text is displayed separately (e.g. in certain East
	Asian languages, which have their own templates to display the quoted text, such as {{tl|ja-x}} for Japanese,
	{{tl|zh-x}} for Chinese, {{tl|ko-x}} for Korean, {{tl|th-x}} for Thai and {{tl|km-x}} for Khmer). Even in that case,
	however, {{para|1}} must still be supplied to indicate the language of the quotation.]=],
	{{"1", required = true},
	[=[A comma-separated list of language codes indicating the language(s) of the quoted text; for a list of the codes,
	see [[Wiktionary:List of languages]]. If the language is other than English, the template will indicate this fact
	by displaying "{(in ``language``)}" (for one language), or "{(in ``language`` and ``language``)}" (for two
	languages), or "{(in ``language``, ``language`` ... and ``language``)}" (for three or more languages). The entry
	page will also be added to a category in the form {Category:``language`` terms with quotations} for the first
	listed language (unless {{para|termlang}} is specified, in which case that language is used for the category, or
	{{para|nocat|1}} is specified, in which case the page will not be added to any category). The first listed language
	also determines the font to use and the appropriate transliteration to display, if the text is in a non-Latin
	script.

	Use {{para|worklang}} to specify the language(s) that the <<collection>> itself is written in: see below.

	<small>The parameter {{para|lang}} is a deprecated synonym for this parameter; please do not use. If this is used,
	all numbered parameters move down by one.</small>]=]},
	{{"text", "passage"},
	[=[The text being quoted. Use boldface to highlight the term being defined, like this:
	"{{code||<nowiki>'''humanities'''</nowiki>}}".]=]},
	{"worklang",
	[=[A comma-separated list of language codes indicating the language(s) that the book is written in, if different
	from the quoted text; for a list of the codes, see [[Wiktionary:List of languages]].]=]},
	{"termlang",
	[=[A language code indicating the language of the term being illustrated, if different from the quoted text; for a
	list of the codes, see [[Wiktionary:List of languages]]. If specified, this language is the one used when adding
	the page to a category of the form {Category:``language`` terms with quotations}; otherwise, the first listed
	language specified using {{para|1}} is used. Only specify this parameter if the language of the quotation is
	different from the term's language, e.g. a Middle English quotation used to illustrate a modern English term or an
	English definition of a Vietnamese term in a Vietnamese-English dictionary.]=]},
	{{"brackets", boolean = true},
	[=[Surround a quotation with [[bracket]]s. This indicates that the quotation either contains a mere mention of a
	term (for example, "some people find the word '''''manoeuvre''''' hard to spell") rather than an actual use of it
	(for example, "we need to '''manoeuvre''' carefully to avoid causing upset"), or does not provide an actual instance
	of a term but provides information about related terms.]=]},
	{{"t", "translation"},
	[=[If the quoted text is not in English, this parameter can be used to provide an English [[translation]] of
	it.]=]},
	{"lit",
	[=[If the quoted text is not in English and the translation supplied using {{para|t}} or {{para|translation}} is
	idiomatic, this parameter can be used to provide a [[literal]] English [[translation]].]=]},
	{"footer",
	[=[This parameter can be used to specify arbitrary text to insert in a separate line at the bottom, to specify a
	comment, footnote, etc.]=]},
	{{"norm", "normalization"},
	[=[If the quoted text is written using nonstandard spelling, this parameter supplies the normalized (standardized)
	version of the quoted text. This applies especially to older quotations. For example, for Old Polish, this parameter
	could supply a version based on modern Polish spelling conventions, and for Russian text prior to the 1917 spelling
	reform, this could supply the reformed spelling.]=]},
	{{"tr", "transliteration"},
	[=[If the quoted text uses a different {{w|writing system}} from the {{w|Latin alphabet}} (the usual alphabet used
	in English), this parameter can be used to provide a [[transliteration]] of it into the Latin alphabet. Note that
	many languages provide an automatic transliteration if this argument is not specified. If a normalized version of
	the quoted text is supplied using {{para|norm}}, the transliteration will be based on this version if possible
	(falling back to the actual quoted text if the transliteration of the normalized text fails or if the normalization
	is supplied in Latin script and the original in a non-Latin script).]=]},
	{"subst",
	[=[Phonetic substitutions to be applied to handle irregular transliterations in certain languages with a non-Latin
	writing system and automatic transliteration (e.g. Russian and Yiddish). The basic idea is to respell the quoted
	text phonetically prior to transliteration, so the transliteration correctly reflects the pronunciation rather than
	the irregular spelling. If specified, should be one or more substitution expressions separated by commas, where each
	substitution expression is of the form {FROM//TO} ({FROM/TO} is also accepted), where {FROM} specifies the source
	text in the source script (e.g. Cyrillic or Hebrew) and {TO} is the corresponding replacement text, also in the
	source script. The substitutions are applied in order and do not have to match an entire word. Note that Lua
	patterns can be used in {FROM} and {TO} in lieu of literal text; see [[WT:LUA]]. This means in particular that
	hyphens in {FROM} must be written as {%-} to prevent them from being interpreted as a Lua non-greedy pattern
	quantifier.

	See the {{tl|quote-book}} examples for examples of how to use this parameter. Additional examples can be found in
	the documentation to {{tl|ux}}; the usage is identical to that template. If {{para|norm}} is used to provide a
	normalized version of the quoted text, the substitutions will also apply to this version when transliterating
	it.]=]},
	{{"ts", "transcription"},
	[=[Phonetic transcription of the quoted text, if in a non-Latin script where the transliteration is markedly
	different from the actual pronunciation (e.g. Akkadian, Ancient Egyptian and Tibetan). This should not be used
	merely to supply the IPA pronunciation of the text.]=]},
	{"sc",
	[=[The script code of the quoted text, if not in the Latin script. See [[Wiktionary:Scripts]] for more information.
	It is rarely necessary to specify this as the script is autodetected based on the quoted text.]=]},
	{"normsc",
	[=[The script code of the normalized text in {{para|norm}}, if not in the Latin script. If unspecified, and a value
	was given in {{para|sc}}, this value will be used to determine the script of the normalized text; otherwise (or if
	{{para|normsc|auto}} was specified), the script of the normalized text will be autodetected based on that text.]=]},
	{"tag",
	[=[Dialect tag(s) of the quoted text. The tags are the same as those found in {{tl|alt}} and
	{{tl|syn}}/{{tl|ant}}/etc., and are language-specific. To find the defined tags for a given language, see
	[[:Category:Dialectal data modules]]. If a tag isn't recognized, it is displayed as-is. Multiple tags can be
	specified, comma-separated with no spaces between the tags (a comma with a space following it is not recognized as
	a delimiter, but is treated as part of the tag). Tags are displayed as right qualifiers, i.e. italicized, in parens
	and displayed to the right of the quoted text.]=]},
	},

	{"Original quoted text parameters",
	[=[The following parameters describe the original quoted text when the quoted text of the term being illustrated is
	a translation.]=],
	{"origtext",
	[=[The original version of the quoted text, from which the text in {{para|text}} or {{para|passage}} was
	translated. This text must be prefixed with the language code of the language of the text, e.g.
	{<nowiki>gl:O teito é de '''pedra'''.</nowiki>} for original text in Galician. When the main quoted text was
	translated from English, it is best to put the corresponding English text in {{para|origtext}} rather than in
	{{para|t}}; use the latter field for a re-translation into English of the translated text (not needed unless the
	quoted text is a free translation of the original).]=]},
	{"orignorm",
	[=[If the original quoted text is written using nonstandard spelling, this parameter supplies the normalized
	(standardized) version of the text. This is analogous to the {{para|norm}} parameter for the main quoted text.]=]},
	{"origtr",
	[=[If the original quoted text uses a different {{w|writing system}} from the {{w|Latin alphabet}}, this parameter
	can be used to provide a [[transliteration]] of it into the Latin alphabet. This is analogous to the {{para|tr}}
	parameter for the main quoted text.]=]},
	{"origsubst",
	[=[Phonetic substitutions to be applied to handle irregular transliterations of the original quoted text in certain
	languages with a non-Latin writing system and automatic transliteration (e.g. Russian and Yiddish). This is
	analogous to the {{para|subst}} parameter for the main quoted text.]=]},
	{"origts",
	[=[Phonetic transcription of the original quoted text, if in a non-Latin script where the transliteration is
	markedly different from the actual pronunciation (e.g. Akkadian, Ancient Egyptian and Tibetan). This is analogous
	to the {{para|ts}} parameter for the main quoted text and should not be used merely to supply the IPA pronunciation
	of the text.]=]},
	{"origsc",
	[=[The script code of the original quoted text, if not in the Latin script. See [[Wiktionary:Scripts]] for more
	information. It is rarely necessary to specify this as the script is autodetected based on the quoted text.]=]},
	{"orignormsc",
	[=[The script code of the normalized text in {{para|orignorm}}, if not in the Latin script. If unspecified, and a
	value was given in {{para|origsc}}, this value will be used to determine the script of the normalized text;
	otherwise (or if {{para|orignormsc|auto}} was specified), the script of the normalized text will be autodetected
	based on that text.]=]},
	{"origtag",
	[=[Dialect tag(s) of the original quoted text. This is analogous to the {{para|tag}} parameter for the main quoted
	text.]=]},
	},

	{"Date-related parameters",
	{"date",
	[=[The date that the <<work>> was published. Use either {{para|year}} (and optionally {{para|month}}), or
	{{para|date}}, not both. The value of {{para|date}} must be an actual date, with or without the day, rather than
	arbitrary text. Various formats are allowed; it is recommended that you either write in YYYY-MM-DD format, e.g.
	{2023-08-11}, or spell out the month, e.g. {2023 August 11} (permutations of the latter are
	allowed, such as {August 11 2023} or {11 August 2023}). You can omit the day and the code
	will attempt to display the date with only the month and year. Regardless of the input format, the output will be
	displayed in the format {'''2023''' August 11}, or {'''2023''' August} if the day was omitted.]=]},
	{{"year", "month", annotated = true, useand = true},
	[=[The year and (optionally) the month that the <<work>> was published. The values of these parameters are not
	parsed, and arbitrary text can be given if necessary. If the year is preceded by {c.}, e.g.
	{c. 1665}, it indicates that the publication year was {{glink|c.|circa}} (around) the specified year;
	similarly {a.} indicates a publication year {{glink|a.|ante}} (before) the specified year, and
	{p.} indicates a publication year {{glink|p.|post}} (after) the specified year. The year will be
	displayed boldface unless there is boldface already in the value of the {{para|year}} parameter, and the month
	(if given) will follow. If neither date nor year/month is given, the template displays the message
	"(Can we [[:Category:Requests for date|date]] this quote?)" and adds the page to the category
	[[:Category:Requests for date in LANG entries]], using the language specified in {{para|1}}. The message and
	category addition can be suppressed using {{para|nodate|1}}, but it is recommended that you try to provide a date
	or approximate date rather than do so. The category addition alone can be suppressed using {{para|nocat|1}}, but
	this is not normally recommended.]=]},
	{"start_date",
	[=[If the publication spanned a range of dates, place the starting date in {{para|start_date}} (or
	{{para|start_year}}/{{para|start_month}}) and the ending date in {{para|date}} (or {{para|year}}/{{para|month}}).
	The format of {{para|start_date}} is as for {{para|date}}. If the dates have the same year but different month and
	day, the year will only be displayed once, and likewise if only the days differ. Use only one of {{para|start_date}}
	or {{para|start_year}}/{{para|start_month}}, not both.]=]},
	{{"start_year", "start_month", annotated = true, useand = true},
	[=[Alternatively, specify a range by placing the start year and month in {{para|start_year}} and (optionally)
	{{para|start_month}}. These can contain arbitrary text, as with {{para|year}} and {{para|month}}. To indicate that
	publication is around, before or after a specified range, place the appropriate indicator ({c.},
	{a.} or {p.}) before the {{para|year}} value, not before the {{para|start_year}} value.]=]},
	{{"nodate", boolean = true},
	[=[Specify {{para|nodate|1}} if the <<work>> is undated and no date (even approximate) can reasonably be determined.
	This suppresses the maintenance line that is normally displayed if no date is given. Do not use this just because
	you don't know the date; instead, leave out the date and let the maintenance line be displayed and the page be added
	to the appropriate maintenance category, so that someone else can help.]=],},
	},

	{"Author-related parameters",
	{{"author", list = true, multientity = true},
	[=[The name(s) of the author(s) of the <<work>> quoted. Separate multiple authors with semicolons, or use the
	additional parameters {{para|author2}}, {{para|author3}}, etc. Alternatively, use {{para|last}} and {{para|first}}
	(for the first name, and middle names or initials), along with {{para|last2}}/{{para|first2}} for additional
	authors. Do not use both at once.]=]},
	{{"last", "first", useand = true, list = true},
	[=[The first (plus middle names or initials) and last name(s) of the author(s) of the <<work>> quoted. Use
	{{para|last2}}/{{para|first2}}, {{para|last3}}/{{para|first3}}, etc. for additional authors. It is preferred to use
	{{para|author}} over {{para|last}}/{{para|first}}, especially for names of foreign language speakers, where it may
	not be easy to segment into first and last names. Note that these parameters do not support inline modifiers or
	prefixed language codes, and do not do automatic script detection; hence they can only be used for Latin-script
	names.]=]},
	{{"authorlink", list = true},
	[=[The name of an [https://en.wikipedia.org English Wikipedia] article about the author, which will be linked to the
	name(s) specified using {{para|author}} or {{para|last}}/{{para|first}}. Additional articles can be linked to other
	authors' names using the parameters {{para|authorlink2}}, {{para|authorlink3}}, etc. Do not add the prefix
	{:en:} or {w:}.

	Alternatively, link each person's name directly, like this:
	{{para|author|<nowiki>[[w:Kathleen Taylor (biologist)|Kathleen Taylor]]</nowiki>}} or
	{{para|author|<nowiki>{{w|Samuel Johnson}}</nowiki>}}.]=]},
	{{"coauthors", multientity = true},
	"The names of the coauthor(s) of the <<work>>. Separate multiple names with semicolons."},
	{{"mainauthor", multientity = true},
	[=[If you wish to indicate who a part of <<work:a>> such as a foreword or introduction was written by, use
	{{para|author}} to do so, and use {{para|mainauthor}} to indicate the author(s) of the main part of the <<work>>.
	Separate multiple authors with semicolons.]=]},
	{{"tlr", "translator", "translators", multientity = true},
	[=[The name(s) of the translator(s) of the <<collection>>. Separate multiple names with semicolons. The actual
	display depends on whether there are preceding author(s) or coauthor(s) displayed. If not, the format
	{John Doe, Mary Bloggs, transl.} or {John Doe, Mary Bloggs, Richard Roe, transl.} will be used, with the names
	first. Otherwise, the format {translated by John Doe and Mary Bloggs} or {translated by John Doe, Mary Bloggs and
	Richard Roe} will be used, to more clearly distinguish the author(s) from the translator(s). Note that in neither
	case are semicolons used as delimiters in the output.]=]},
	{{"editor", multientity = true},
	[=[The name(s) of the editor(s) of the <<collection>>. Separate multiple names with semicolons. The follows similar
	principles to that of translators, as described above: With no preceding author(s), coauthor(s) or translator(s),
	the format {John Doe, editor} or {John Doe, Mary Bloggs, Richard Roe, editors} (if more than one editor is given)
	will be used. Otherwise, the format {edited by John Doe and Mary Bloggs} or {edited by John Doe, Mary Bloggs and
	Richard Roe} will be used.]=],},
	{{"editors", multientity = true},
	[=[The name(s) of the editors of the <<collection>>. Separate multiple names with semicolons. The only difference
	between this and {{para|editor}} is that when there are no preceding author(s), coauthor(s) or translator(s),
	this parameter always outputs {editors} while {{para|editor}} outputs either {editor} or {editors} depending on the
	number of specified entities. For example, with no preceding author(s), coauthor(s) or translator(s),
	{{para|editor|Mary Bloggs}} will show "{Mary Bloggs, editor}" and {{para|editors|Mary Bloggs}} will show
	"{Mary Bloggs, editors}" (which is incorrect in this instance, but would make sense if e.g.
	{{para|editors|the Bloggs Sisters}} were given).]=]},
	{{"compiler", multientity = true},
	[=[The name(s) of the compiler(s) of the <<collection>>. Separate multiple names with semicolons. Compilers are
	similar to editors but are used more specifically for anthologies collected from source materials (e.g. traditional
	stories, folk songs, letters of a well-known person, etc.). This field works identically to {{para|editor}} but
	displays {compiled} in place of {edited} and {compiler(s)} in place of {editor(s)}.]=]},
	{{"compilers", multientity = true},
	[=[The name(s) of the compilers of the <<collection>>. Separate multiple names with semicolons. See
	{{para|compiler}} for when to use this field. This field works identically to {{para|editors}} but displays
	{compiled} in place of {edited} and {compilers} in place of {editors}.]=]},
	{{"quotee", multientity = true},
	[=[The name of the person being quoted, if the whole text quoted is a quotation of someone other than the
	author.]=]},
	},

	{"Title-related parameters",
	{{"title", annotated = true, required = true},
	[=[The title of the <<collection>>.]=]},
	{"trans-title",
	[=[If the title of the <<collection>> is not in English, this parameter can be used to provide an English
	translation of the title, as an alternative to specifying the translation using an inline modifier (see above).]=]},
	{{"series", annotated = true},
	[=[The {{w|book series|series}} that the <<collection>> belongs to.]=]},
	{{"seriesvolume", annotated = true},
	[=[The volume number of the <<collection>> within the series that it belongs]=]},
	{"url",
	[=[The URL or web address of an external website containing the full text of the <<work>>. ''Do not link to any
	website that has content in breach of copyright''.]=]},
	{"urls",
	[=[Freeform text, intended for multiple URLs. Unlike {{para|url}}, the editor must supply the URL brackets
	{[]}.]=]},
	},

	{"Chapter-related parameters",
	{{"chapter", annotated = true},
	[=[The chapter of the <<collection>> quoted. You can either specify a chapter number in Arabic or Roman
	numerals (for example, {{para|chapter|7}} or {{para|chapter|VII}}) or a chapter title (for example,
	{{para|chapter|Introduction}}). A chapter given in Arabic or Roman numerals will be preceded by the word "chapter",
	while a chapter title will be enclosed in “curly quotation marks”.]=]},
	{{"chapter_number", annotated = true},
	[=[If the name of the chapter was supplied in {{para|chapter}}, use {{para|chapter_number}} to provide the
	corresponding chapter number, which will be shown in parentheses after the word "chapter", e.g.
	{“Experiments” (chapter 4)}.]=]},
	{{"chapter_plain", annotated = true},
	[=[The full value of the chapter, which will be displayed as-is. Include the word "chapter" and any desired
	quotation marks. If both {{para|chapter}} and {{para|chapter_plain}} are given, the value of {{para|chapter_plain}}
	is shown after the chapter, in parentheses. This is useful if chapters in this <<collection>> have are given a term
	other than "chapter".]=]},
	{"chapterurl",
	[=[The [[w:Universal Resource Locator|URL]] or web address of an external webpage to link to the chapter. Note that
	it is generally preferred to use {{para|pageurl}} to link directly to the page of the quoted text, if possible.
	''Do not link to any website that has content in breach of [[w:copyright|copyright]]''.]=]},
	{"trans-chapter",
	[=[If the chapter of the <<collection>> is not in English, this parameter can be used to provide an English
	translation of the chapter title, as an alternative to specifying the translation using an inline modifier (see
	above).]=]},
	{{"chapter_tlr", multientity = true},
	[=[The translator of the chapter, if separate from the overall translator of the <<collection>> (specified using
	{{para|tlr}} or {{para|translator}}).]=]},
	{{"chapter_series", "chapter_seriesvolume", useand = true, annotated = true},
	[=[If this chapter is part of a series of similar chapters, {{para|chapter_series}} can be used to specify the name
	of the series, and {{para|chapter_seriesvolume}} can be used to specify the index of the series, if it exists.
	Compare the {{para|series}} and {{para|seriesvolume}} parameters for the <<collection>> as a whole. These parameters
	are used especially in conjunction with recurring columns in a newspaper or similar. In {{tl|quote-journal}}, the
	{{para|chapter}} parameter is called {{para|title}} or {{para|article}} and is used to specify the name of a
	journal, magazine or newspaper article, and the {{para|chapter_series}} parameter is called {{para|article_series}}
	and is used to specify the name of the column or article series that the article is part of.]=]},
	},

	{"Section-related parameters",
	{{"section", annotated = true},
	[=[Use this parameter to identify a (usually numbered) portion of <<work:a>>, as an alternative or
	complement to specifying a chapter. For example, in a play, use {{para|section|act II, scene iv}}, and in a
	technical journal article, use {{para|section|4}}. If the value of this parameter looks like a Roman or Arabic
	numeral, it will be prefixed with the word "section", otherwise displayed as-is (compare the similar handling of
	{{para|chapter}}).]=]},
	{{"section_number", annotated = true},
	[=[If the name of a section was supplied in {{para|section}}, use {{para|section_number}} to provide the
	corresponding section number, which will be shown in parentheses after the word "section", e.g.
	{Experiments (section 4)}.]=]},
	{{"section_plain", annotated = true},
	[=[The full value of the section, which will be displayed as-is; compare {{para|chapter_plain}}. (This is provided
	only for completeness, and is not generally useful, since the value of {{para|section}} is also displayed as-is if
	it doesn't look like a number.)]=]},
	{"sectionurl",
	[=[The [[w:Universal Resource Locator|URL]] or web address of an external webpage to link to the section. ''Do not
	link to any website that has content in breach of [[w:copyright|copyright]]''.]=]},
	{"trans-section",
	[=[If the section of the <<work>> is not in English, this parameter can be used to provide an English
	translation of the section, as an alternative to specifying the translation using an inline modifier (see
	above).]=]},
	{{"section_series", "section_seriesvolume", useand = true, annotated = true},
	[=[If this section is part of a series of similar sections, {{para|section_series}} can be used to specify the name
	of the series, and {{para|section_seriesvolume}} can be used to specify the index of the series, if it exists.
	Compare the {{para|series}} and {{para|seriesvolume}} parameters for the <<collection>> as a whole, and the
	{{para|chapter_series}} and {{para|chapter_seriesvolume}} parameters for a chapter.]=]},
	},

	{"Page- and line-related parameters",
	{{"page", "pages", annotated = true},
	[=[The page number or range of page numbers of the <<work>>. Use an en dash (–) to separate the page numbers in the
	range. Under normal circumstances, {{para|page}} and {{para|pages}} are aliases of each other, and the code
	autodetects whether to display singular "page" or plural "pages" before the supplied number or range. The
	autodetection code displays the "pages" if it finds an en-dash (–), an em-dash (—), a hyphen between numbers,
	or a comma followed by a space and between numbers (the space is necessary, so that numbers like {1,478}
	with a thousands separator don't get treated as multiple pages). To suppress the autodetection (for example, some
	books have hyphenated page numbers like {3-16}), precede the value with an exclamation point
	({!}); if this is given, the name of the parameter determines whether to display "page" or "pages".
	Alternatively, use {{para|page_plain}}. As a special case, the value {unnumbered} causes
	{unnumbered page} to display.]=]},
	{{"page_plain", annotated = true},
	[=[Free text specifying the page or pages of the quoted text, e.g. {folio 8} or {back cover}.
	Use only one of {{para|page}}, {{para|pages}} and {{para|page_plain}}.]=]},
	{"pageurl",
	[=[The URL or web address of the webpage containing the page(s) of the <<work>> referred to. The page number(s) will
	be linked to this webpage.]=]},
	{{"line", "lines", annotated = true},
	[=[The line number(s) of the quoted text, e.g. {47} or {151–154}. These parameters work
	identically to {{para|page}} and {{para|pages}}, respectively. Line numbers are often used in plays, poems and
	certain technical works.]=]},
	{{"line_plain", annotated = true},
	[=[Free text specifying the line number(s) of the quoted text, e.g. {verses 44–45} or
	{footnote 3}. Use only one of {{para|line}}, {{para|lines}} and {{para|line_plain}}.]=]},
	{"lineurl", [=[The URL or web address of the webpage containing the line(s) of the <<work>> referred to. The line
	number(s) will be linked to this webpage.]=]},
	{{"column", "columns", "column_plain", useand = true, annotated = true},
	[=[The column number(s) of the quoted text. These parameters work identically to {{para|page}}, {{para|pages}} and
	{{para|page_plain}}, respectively.]=]},
	{"columnurl",
	[=[The URL of the column number(s) of the quoted text. This parameter works identically to {{para|pageurl}}.]=]},
	},

	{"Publication-related parameters",
	{{"publisher", multientity = true},
	[=[The name of one or more publishers of the <<collection>>. If more than one publisher is stated, separate the
	names with semicolons.]=]},
	{{"location", multientity = true},
	[=[The location where the <<collection>> was published. If more than one location is stated, separate the
	locations with semicolons, like this: {London; New York, N.Y.}.]=]},
	{{"edition", annotated = true},
	[=[The edition of the <<collection>> quoted, for example, {2nd} or <code>3rd corrected and
	revised</code>. This text will be followed by the word "edition" (use {{para|edition_plain}} to avoid this). If
	quoting from the first edition of the <<collection>>, it is usually not necessary to specify this fact.]=]},
	{{"edition_plain", annotated = true},
	[=[Free text specifying the edition of the <<collection>> quoted, e.g. {3rd printing} or
	{5th edition, digitized} or {version 3.72}.]=]},
	{{"year_published", "month_published", annotated = true, useand = true},
	[=[If {{para|year}} is used to state the year when the original version of the <<issue>> was published,
	{{para|year_published}} can be used to state the year in which the version quoted from was published, for example,
	"{|year=1665|year_published=2005}". {{para|month_published}} can optionally be used to specify the month
	of publication. The year published is preceded by the word "published". These parameters are handled in an
	identical fashion to {{para|year}} and {{para|month}} (except that the year isn't displayed boldface by default).
	This means, for example, that the prefixes {c.}, {a.} and {p.} are recognized to
	specify that the publication happened circa/before/after a specified date.]=]},
	{"date_published",
	[=[The date that the version of the <<issue>> quoted from was published. Use either {{para|year_published}} (and
	optionally {{para|month_published}}), or {{para|date_published}}, not both. As with {{para|date}}, the value of
	{{para|date_published}} must be an actual date, with or without the day, rather than arbitrary text. The same
	formats are recognized as for {{para|date}}.]=]},
	{{"start_year_published", "start_month_published", annotated = true, useand = true},
	[=[If the publication of the version quoted from spanned a range of dates, specify the starting year (and optionally
	month) using these parameters and place the ending date in {{para|year_published}}/{{para|month_published}} (or
	{{para|date_published}}). This works identically to {{para|start_year}}/{{para|start_month}}. It is rarely necessary
	to use these parameters.]=]},
	{"start_date_published",
	[=[Start date of the publication of the version quoted from, as an alternative to specifying
	{{para|start_year_published}}/{{para|start_month_published}}. This works like {{para|start_date}}. It is
	rarely necessary to specify this parameter.]=]},
	{{"origyear", "origmonth", annotated = true, useand = true},
	[=[The year when the <<work>> was originally published, if the <<work>> quoted from is a new version of <<work:a>>
	(not merely a new printing). For example, if quoting from a modern edition of Shakespeare or Milton, put the date of
	the modern edition in {{para|year}}/{{para|month}} or {{para|date}} and the date of the original edition in
	{{para|origyear}}/{{para|origmonth}} or {{para|origdate}}. {{para|origmonth}} can optionally be used to supply the
	original month of publication, or a full date can be given using {{para|origdate}}. Use either
	{{para|origyear}}/{{para|origmonth}} or {{para|origdate}}, not both. These parameters are handled in an
	identical fashion to {{para|year}} and {{para|month}} (except that the year isn't displayed boldface by default).
	This means, for example, that the prefixes {c.}, {a.} and {p.} are recognized to
	specify that the original publication happened circa/before/after a specified date.]=]},
	{"origdate",
	[=[The date that the original version of the <<work>> quoted from was published. Use either {{para|origyear}} (and
	optionally {{para|origmonth}}), or {{para|origdate}}, not both. As with {{para|date}}, the value of
	{{para|origdate}} must be an actual date, with or without the day, rather than arbitrary text. The same formats are
	recognized as for {{para|date}}.]=]},
	{{"origstart_year", "origstart_month", annotated = true, useand = true},
	[=[The start year/month of the original version of publication, if the publication happened over a range. Use
	either {{para|origstart_year}} (and optionally {{para|origstart_month}}), or {{para|origstart_date}}, not both.
	These work just like {{para|start_year}} and {{para|start_month}}, and very rarely need to be specified.]=]},
	{"origstart_date",
	[=[The start date of the original version of publication, if the publication happened over a range. This works just
	like {{para|start_date}}, and very rarely needs to be specified.]=]},
	{{"platform", multientity = true},
	[=[The platform on which the <<work>> has been published. This is intended for content aggregation platforms such
	as {{w|YouTube}}, {{w|Issuu}} and {{w|Magzter}}. This displays as "via PLATFORM".]=]},
	{{"source", multientity = true},
	[=[The source of the content of the <<work>>. This is intended e.g. for news agencies such as the {{w|Associated
	Press}}, {{w|Reuters}} and {{w|Agence France-Presse}} (AFP) (and is named {{para|newsagency}} in
	{{tl|quote-journal}} for this reason). This displays as "sourced from SOURCE".]=]},
	},

	{"Volume-related parameters",
	{{"volume", "volumes", annotated = true},
	[=[The volume number(s) of the <<collection>>. This displays as "volume VOLUME", or "volumes VOLUMES" if a range of
	numbers is given. Whether to display "volume" or "volumes" is autodetected, exactly as for {{para|page}} and
	{{para|pages}}; use {!} at the beginning of the value to suppress this and respect the parameter name.
	Use {{para|volume_plain}} if you wish to suppress the word "volume" appearing in front of the volume number.]=]},
	{{"volume_plain", annotated = true},
	[=[Free text specifying the volume number(s) of the <<collection>>, e.g. {book II}. Use only one of
	{{para|volume}}, {{para|volumes}} and {{para|volume_plain}}.]=]},
	{"volumeurl",
	[=[The URL or web address of the webpage corresponding to the volume containing the quoted text, if the
	<<collection>> has multiple volumes with different URL's. The volume number(s) will be linked to this webpage.]=]},
	{{{"issue", "number"}, {"issues", "numbers"}, {"issue_plain", "number_plain"}, useand = true, annotated = true},
	[=[The issue number(s) of the quoted text. These parameters work identically to {{para|page}}, {{para|pages}} and
	{{para|page_plain}}, respectively, except that the displayed text contains the term "number" or "numbers"
	(regardless of whether the {{para|issue}} or {{para|number}} series of parameters are used; they are aliases).
	Examples of the use of {{para|issue_plain}} are {book 2} (if the <<collection>> is divided into volumes
	and volumes are divided into books) or {Sonderheft 1} (where ''Sonderheft'' means "special issue" in
	German).]=]},
	{{{"issueurl", "numberurl"}, useand = true},
	[=[The URL of the issue number(s) of the quoted text. This parameter works identically to {{para|volumeurl}}.]=]},
	},

	{"ID-related parameters",
	{{"doi", "DOI"}, [=[The [[w:Digital object identifier|digital object identifier]] (DOI) of the <<work>>.]=]},
	{{"isbn", "ISBN"}, [=[The [[w:International Standard Book Number|International Standard Book Number]] (ISBN) of
	the <<collection>>. 13-digit ISBN's are preferred over 10-digit ones.]=]},
	{{"issn", "ISSN"}, [=[The [[w:International Standard Serial Number|International Standard Serial Number]] (ISSN) of the
	<<collection>>.]=]},
	{{"jstor", "JSTOR"}, [=[The [[w:JSTOR|JSTOR]] number of the <<work>>.]=]},
	{{"lccn", "LCCN"}, [=[The [[w:Library of Congress Control Number|Library of Congress Control Number]] (LCCN) of
	the <<work>>.]=]},
	{{"oclc", "OCLC"}, [=[The [[w:OCLC|Online Computer Library Center]] (OCLC) number of the <<work>> (which can be looked
	up at the [http://www.worldcat.org WorldCat] website).]=]},
	{{"ol", "OL"}, [=[The [[w:Open Library|Open Library]] number (omitting "OL") of the <<work>>.]=]},
	{{"pmid", "PMID"}, [=[The [[w:PubMed#PubMed identifier|PubMed]] identifier (PMID) of the <<work>>.]=]},
	{{"pmcid", "PMCID"}, [=[The [[w:PubMed Central#PMCID|PubMed Central]] identifier (PMCID) of the <<work>>.]=]},
	{{"ssrn", "SSRN"}, [=[The [[w:Social Science Research Network|Social Science Research Network]] (SSRN) identifier
	of the <<work>>.]=]},
	{"bibcode", [=[The {{w|bibcode}} (bibliographic code, used in astronomical data systems) of the <<work>>.]=]},
	{"id", [=[Any miscellaneous identifier of the <<work>>.]=]},
	},

	{"Archive and access-related parameters",
	{{"archiveurl", "archivedate", useand = true}, [=[Use {{para|archiveurl}} and {{para|archivedate}} (which must be
	used together) to indicate the URL or web address of a webpage on a website such as the [https://archive.org
	Internet Archive] or [https://perma.cc Perma.cc] at which the webpage has been archived, and the date on which the
	webpage was archived.]=]},
	{"accessdate", [=[If the webpage cannot be archived, use {{para|accessdate}} to indicate the date when the webpage
	was last accessed. Unlike other date parameters, this parameter is free text. (If the webpage has been archived, it
	is unnecessary to use this parameter.)]=]},
	},

	{"Miscellaneous citation parameters",
	{"format", [=[The format that the <<work>> is in, for example, "{hardcover}" or "{paperback}" for
	a book or "{blog}" for a web page.]=]},
	{"genre", [=[The {{w|literary genre}} of the <<work>>, for example, "{fiction}" or
	"{non-fiction}".]=]},
	{"medium", [=[The medium of the recording of the <<work>>, for example, "{Blu-ray}", "{CD}", "{DVD}",
	"{motion picture}", "{podcast}", "{television production}", "{audio recording}" or "{videotape}".]=]},
	{{"nocat", boolean = true}, [=[Specify {{para|nocat|1}} to suppress adding the page to a category of the form
	{Category:``language`` terms with quotations}. This should not normally be done.]=]},
	{{"nocolon", boolean = true}, [=[Specify {{para|nocolon|1}} to suppress adding the colon at the end of the citation
	line. This can be used if the title itself (or rarely, some other value in the citation line) illustrates the term
	in question. Make sure to use triple quotes in the term being illustrated, e.g.
	<code><nowiki>'''term'''</nowiki></code>, to make it clear what the quoted text is.]=]},
	},

	{"New version of <<work:a>>",
	[=[The following parameters can be used to indicate a new version of the <<work>>, such as a reprint, a new edition, or
	some other republished version. The general means of doing this is as follows:
	# Specify {{para|newversion|republished as}}, {{para|newversion|translated as}}, {{para|newversion|quoted in}} or
	similar to indicate what the new version is. (Under some circumstances, this parameter can be omitted; see below.)
	# Specify the author(s) of the new version using {{para|2ndauthor}} (separating multiple authors with a semicolon)
	or {{para|2ndlast}}/{{para|2ndfirst}}.
	# Specify the remaining properties of the new version by appending a {2} to the parameters as specified
	above, e.g. {{para|title2}} for the title of the new version, {{para|page2}} for the page number of the new
	version, etc.

	Some special-case parameters are supplied as an alternative to specifying a new version this way. For example, the
	{{para|original}} and {{para|by}} parameters can be used when quoting a translated version of <<work:a>>; see
	below.]=],
	{"newversion",
	[=[The template assumes that a new version of the <<work>> is referred to if {{para|newversion}} or
	{{para|location2}} are given, or if the parameters specifying the author of the new version are given
	({{para|2ndauthor}} or {{para|2ndlast}}), or if any other parameter indicating the title or author of the new
	version is given (any of {{para|chapter2}}, {{para|title2}}, {{para|tlr2}}, {{para|translator2}},
	{{para|translators2}}, {{para|mainauthor2}}, {{para|editor2}} or {{para|editors2}}). It then behaves as follows:
	* If an author, editor and/or title are stated, it indicates "republished as".
	* If only the place of publication, publisher and date of publication are stated, it indicates "republished".
	* If an edition is stated, no text is displayed.
	Use {{para|newversion}} to override this behaviour, for example, by indicating "quoted in" or "reprinted as".]=]},
	{{"2ndauthor", multientity = true},
	[=[The author of the new version. Separate multiple authors with a semicolon. Alternatively, use {{para|2ndlast}}
	and {{para|2ndfirst}}.]=]},
	{{"2ndlast", "2ndfirst", useand = true},
	[=[The first (plus middle names or initials) and last name(s) of the author of the new version. It is preferred to
	use {{para|2ndauthor}} over {{para|2ndlast}}/{{para|2ndfirst}}, for multiple reasons:
	# The names of foreign language speakers may not be easy to segment into first and last names.
	# Only one author can be specified using {{para|2ndlast}}/{{para|2ndfirst}}, whereas multiple semicolon-separated
	authors can be given using {{para|2ndauthor}}.
	# Inline modifiers are not supported for {{para|2ndlast}} and {{para|2ndfirst}} and script detection is not done,
	meaning that only Latin-script author names are supported.]=]},
	{"2ndauthorlink",
	[=[The name of an [https://en.wikipedia.org English Wikipedia] article about the author, which will be linked to the
	name(s) specified using {{para|2ndauthor}} or {{para|2ndlast}}/{{para|2ndfirst}}. Do not add the prefix
	{:en:} or {w:}. Alternatively, link each person's name directly, like this:
	{{para|2ndauthor|<nowiki>[[w:Kathleen Taylor (biologist)|Kathleen Taylor]]</nowiki>}}.]=]},
	{{"{{para|title2}}, {{para|editor2}}, {{para|location2}}, ''etc.''", literal = true, multientity = true},
	[=[Most of the parameters listed above can be applied to a new version of the <<work>> by adding "{2}"
	after the parameter name. It is recommended that at a minimum the imprint information of the new version of the
	<<work>> should be provided using {{para|location2}}, {{para|publisher2}}, and {{para|date2}} or
	{{para|year2}}.]=]},
	},

	{"Alternative special-case ways of specifying a new version of <<work:a>>",
	[=[The following parameters provide alternative ways of specifying new version of <<work:a>>, such as a reprint or
	translation, or a case where part of one <<work>> is quoted in another. If you find that these parameters are
	insufficient for specifying all the information about both works, do not try to shoehorn the extra information in.
	Instead, use the method described above using {{para|newversion}} and {{para|2ndauthor}}, {{para|title2}}, etc.]=],
	{{"original", annotated = true},
	[=[If you are citing a {{w|derivative work}} such as a translation, use {{para|original}} to state the title of the
	original work, {{para|by}} to state the author of the original work and {{para|deriv}} to state the type of
	derivative work. Either {{para|original}} or {{para|by}} must be given for this method to be applicable. If all
	three are given, the code displays "{``deriv`` of ``original`` by ``by``}". If {{para|original}} is omitted, the
	literal text "{original}" is used. If {{para|deriv}} is omitted, the literal text "{translation}" is used. If
	{{para|by}} is omitted, the "by {``by``}" clause is left out.]=]},
	{{"by", multientity = true},
	[=[If you are citing a {{w|derivative work}} such as a translation, use {{para|by}} to state the author(s) of the
	original work. See {{para|original}} above.]=]},
	{"deriv",
	[=[If you are citing a {{w|derivative work}} such as a translation, use {{para|deriv}} to state the type of
	derivative work. See {{para|original}} above.]=]},
	{{"quoted_in", annotated = true},
	[=[If the quoted text is from book A which states that the text is from another book B, do the following:
	* Use {{para|title}}, {{para|edition}}, and {{para|others}} to provide information about book B. (As an example,
	{{para|others}} can be used like this: "{{para|others=1893, page 72}}".)
	* Use {{para|quoted_in}} (for the title of book A), {{para|location}}, {{para|publisher}}, {{para|year}},
	{{para|page}}, {{para|oclc}}, and other standard parameters to provide information about book A.]=]},
	},
}
end


local quote_mods = {
	["quote-book"] = {
	{"#substitute", work = "book", collection = "book", issue = "book"},
	{"year", addalias = "2"},
	{"author", addalias = "3"},
	{"title", addalias = "4"},
	{"url", addalias = "5"},
	{"page", addalias = "6"},
	{"text", addalias = "7"},
	{"translation", addalias = "8"},
	{"chapter", addalias = "entry", append_desc = [=[The parameter {{para|entry}} can be used if quoting from a
	dictionary.]=]},
	{"trans-chapter", addalias = "trans-entry", replace_desc = [=[If the chapter of, or the entry in, the book is
	not in English, this parameter can be used to provide an English translation of the chapter or entry, as an
	alternative to specifying the translation using an inline modifier (see above).]=]},
	{"chapterurl", addalias = "entryurl", replace_desc = [=[The [[w:Universal Resource Locator|URL]] or web address of
	an external webpage to link to the chapter or entry name. For example, if the book has no page numbers, the webpage
	can be linked to the chapter or entry name using this parameter. ''Do not link to any website that has content in
	breach of [[w:copyright|copyright]]''.]=]},
	},

	["quote-journal"] = {
	{"#substitute", work = "article", collection = "journal", issue = "journal issue"},
	{"year", addalias = "2"},
	{"author", addalias = "3"},
	{"title", replace_params = {"journal", "magazine", "newspaper", "work", "5", annotated = true}},
	{"trans-title", replace_params = {"trans-journal", "trans-magazine", "trans-newspaper", "trans-work"}},
	{"url", addalias = "6"},
	{"page", addalias = "7"},
	{"text", addalias = "8"},
	{"translation", addalias = "9"},
	{"source", addalias = "newsagency"},
	{"#replace_group", "Chapter-related parameters", {"Article-related parameters",
		{{"title", "article", "4", annotated = true, semi_required = true},
		[=[The title of the journal article quoted, which will be enclosed in “curly quotation marks”.]=]},
		{{"title_plain", "article_plain", annotated = true},
		[=[The title of the article, which will be displayed as-is. Include any desired quotation marks
		and other words. If both {{para|title}} and {{para|title_plain}} are given, the value of {{para|title_plain}}
		is shown after the title, in parentheses. This is useful e.g. to indicate an article number or other
		identifier.]=]},
		{{"titleurl", "article_url"},
		[=[The [[w:Universal Resource Locator|URL]] or web address of an external webpage to link to the
		article. Note that it is generally preferred to use {{para|pageurl}} to link directly to the page of the quoted
		text, if possible. ''Do not link to any website that has content in breach of [[w:copyright|copyright]]''.]=]},
		{{"trans-title", "trans-article"},
		[=[If the journal article is not in English, this parameter can be used to provide an English
		translation of the title, as an alternative to specifying the translation using an inline modifier (see
		above).]=]},
		{{"article_tlr", multientity = true},
		[=[The translator of the article, if separate from the overall translator of the journal
		(specified using {{para|tlr}} or {{para|translator}}).]=]},
		{{"article_series", "article_seriesvolume", annotated = true, useand = true},
		[=[If this article is part of a series of similar articles, {{para|article_series}} can be used to specify the
		name of the series, and {{para|article_seriesvolume}} can be used to specify the index of the series, if it
		exists. Compare the {{para|series}} and {{para|seriesvolume}} parameters for the journal as a whole. These
		parameters can be used,	for example, for recurring columns in a newspaper.]=]},
		}
	},
	},
}


local function canonicalize_paramspec(paramspec, add_non_generic)
	-- Canonicalize a top-level string param to a list.
	if type(paramspec) == "string" then
		paramspec = {paramspec}
	end
	for j, paramset in ipairs(paramspec) do
		-- Canonicalize a second-level string param to a list.
		if type(paramset) ~= "table" or paramset.param then
			paramset = {paramset}
			paramspec[j] = paramset
		end
		for k, param in ipairs(paramset) do
			-- Canonicalize a single param to object form.
			if type(param) == "string" then
				param = {param = param}
				if add_non_generic and param.non_generic == nil then
					param.non_generic = true
				end
				paramset[k] = param
			end
		end
	end

	return paramspec
end


local function canonicalize_param_group(group, add_non_generic)
	local ind = 2
	if type(group[2]) == "string" then
		ind = ind + 1
	end

	for i = ind, #group do
		-- Canonicalize the parameter spec to the maximally-expressed form for easier processing.
		local paramspec, desc = unpack(group[i])
		group[i][1] = canonicalize_paramspec(paramspec, add_non_generic)
	end
end


local function canonicalize_param_list(params, add_non_generic)
	-- Canonicalize an addalias= spec to a list for easier processing.
	if type(params) ~= "table" or params.param then
		params = {params}
	end
	for i, p in ipairs(params) do
		-- Canonicalize.
		if type(p) == "string" then
			p = {param = p}
			params[i] = p
		end
		if add_non_generic and p.non_generic == nil then
			p.non_generic = true
		end
	end

	return params
end


-- Apply the modifications specified in `mods` to the parameters in `params`.
local function apply_mods(params, mods)
	local mod_table = {}
	local subvals
	-- First, convert the modifications to a dictionary for easy lookup as we traverse the existing parameters.
	for _, mod in ipairs(mods) do
		local param = mod[1]
		if param == "#substitute" then
			mod[1] = nil
			subvals = mod
		elseif param ~= "#replace_group" then
			-- Need to do replace_group after aliases because replace_group might introduce new params that we don't want aliases
			-- to touch (e.g. |title= in {{quote-journal}}).
			mod_table[param] = mod
		end
	end

	-- Process each group in turn.
	for _, group in ipairs(params) do
		canonicalize_param_group(group)

		local ind = 2
		if type(group[2]) == "string" then
			ind = ind + 1
		end

		for i = ind, #group do
			-- Go through each parameter group looking for modifications, and make them. To avoid problems
			-- side-effecting lists as we process them, we first clone the group and iterate over the clone, which
			-- remains unmodified.
			local paramspec, desc = unpack(group[i])
			local specclone = m_table.deepcopy(paramspec)
			for j, paramset in ipairs(specclone) do
				for k, param in ipairs(paramset) do
					local mod = mod_table[param.param]
					if mod then
						if mod.addalias then
							-- Canonicalize an addalias= spec to a list for easier processing.
							local to_add = canonicalize_param_list(mod.addalias, "add non-generic")
							for _, ta in ipairs(to_add) do
								if paramspec.useand then
									-- Top level refers to logically-related params so alias goes at second level.
									table.insert(paramspec[j], ta)
								else
									table.insert(paramspec, {ta})
								end
							end
						end

						if mod.replace_params then
							group[i][1] = canonicalize_paramspec(mod.replace_params, "add non-generic")
						end

						if mod.append_desc then
							group[i][2] = group[i][2] .. " " .. mod.append_desc
						end

						if mod.replace_desc then
							group[i][2] = mod.replace_desc
						end
					end
				end
			end
		end
	end

	for _, mod in ipairs(mods) do
		local param = mod[1]
		if param == "#replace_group" then
			local _, existing_group_name, new_group = unpack(mod)
			canonicalize_param_group(new_group)

			local ind = 2
			if type(new_group[2]) == "string" then
				ind = ind + 1
			end

			for i = ind, #new_group do
				local paramspec, desc = unpack(new_group[i])
				for j, paramset in ipairs(paramspec) do
					for k, param in ipairs(paramset) do
						if param.non_generic == nil then
							param.non_generic = true
						end
					end
				end
			end

			local replaced = false
			for i, group in ipairs(params) do
				if group[1] == existing_group_name then
					params[i] = new_group
					replaced = true
					break
				end
			end
			if not replaced then
				error(("Internal error: Unable to locate existing group '%s'"):format(existing_group_name))
			end
		end
	end

	return subvals
end


-- Format a param spec as found in the first element of a param description.
local function format_param_spec(paramspec)
	if type(paramspec) ~= "table" or paramspec.param then
		paramspec = {paramspec}
	end

	local function format_one_param(param, non_generic)
		if non_generic then
			param = "<b>" .. param .. "</b>"
		end
		if paramspec.boolean then
			return ("<code>|%s=1</code>"):format(param)
		else
			return ("<code>|%s=</code>"):format(param)
		end
	end

	local function format_all_params_no_list(suffix)
		local formatted = {}
		for _, paramset in ipairs(paramspec) do
			if type(paramset) ~= "table" or paramset.param then
				paramset = {paramset}
			end
			local formatted_paramset = {}
			for _, p in ipairs(paramset) do
				if type(p) == "string" then
					p = {param = p}
				end
				-- Skip ...2 and ...3 versions of numeric params.
				if suffix == "" or not rfind(p.param, "^[0-9]+") then
					table.insert(formatted_paramset, format_one_param(p.param .. suffix, p.non_generic))
				end
			end
			local to_insert = table.concat(formatted_paramset, "/")
			if to_insert ~= "" then
				table.insert(formatted, to_insert)
			end
		end
		return m_table.serialCommaJoin(formatted, {conj = paramspec.useand and "and" or "or"})
	end

	local function format_all_params()
		if paramspec.list then
			local formatted = {}
			table.insert(formatted, format_all_params_no_list(""))
			table.insert(formatted, format_all_params_no_list("2"))
			table.insert(formatted, format_all_params_no_list("3"))
			table.insert(formatted, "etc.")
			return table.concat(formatted, "; ")
		else
			return format_all_params_no_list("")
		end
	end

	local formatted_params
	if paramspec.literal then
		formatted_params = preprocess(paramspec[1][1].param)
	else
		formatted_params = format_all_params()
	end

	local reqtext = paramspec.required and " '''(required)'''" or ""
	return formatted_params .. reqtext
end


local function process_continued_string(desc, subvals)
	desc = rsub(desc, "{{", TEMP_DOUBLE_LBRACE)
	desc = rsub(desc, "}}", TEMP_DOUBLE_RBRACE)
	-- Join continuation lines. Do it twice in case of a single-character line (admittedly rare).
	desc = rsub(desc, "([^\n])\n[ \t]*([^ \t\n#*])", "%1 %2")
	desc = rsub(desc, "([^\n])\n[ \t]*([^ \t\n#*])", "%1 %2")
	-- Remove whitespace before list elements.
	desc = rsub(desc, "\n[ \t]*([#*])", "\n%1")
	desc = rsub(desc, "^[ \t]*([#*])", "%1")
	 -- placeholder variable names between double backquotes
	desc = rsub(desc, "``([A-Za-z0-9_%-]+)``", "<var>%1</var>")
	-- variable/parameter names between backquotes
	desc = rsub(desc, "`([A-Za-z0-9_%-]+)`", '<code class="n">%1</code>')
	desc = rsub(desc, "%b{}", function(m0) -- {} blocks
			return "<code>" .. m0:sub(2, -2) .. "</code>"
		end)
	desc = rsub(desc, "<<([^><]+)>>", function(item)
		local parts = rsplit(item, ":")
		item = parts[1]
		if subvals[item] then
			if type(subvals[item]) == "string" or type(subvals[item]) == "number" then
				item = subvals[item]
			else
				error("The item '<<" .. item .. ">>' is a " .. type(items[item]) .. " and can't be concatenated.")
			end
		else
			error("The item '" .. item .. "' was not found in the 'subvals' table.")
		end
		for i, part in ipairs(parts) do
			if i > 1 then
				if part == "a" then
					if rfind(item, "^[aeiouAEIOU]") then
						item = "an " .. item
					else
						item = "a " .. item
					end
				elseif part == "cap" then
					item = mw.getContentLanguage():ucfirst("" .. item)
				end
			end
		end
		return item
	end)
	desc = rsub(desc, TEMP_DOUBLE_LBRACE, "{{")
	desc = rsub(desc, TEMP_DOUBLE_RBRACE, "}}")
	desc = preprocess(desc)
	return desc
end


local function format_parameter_group(group, subvals, level)
	local parts = {}
	local function ins(txt)
		table.insert(parts, txt)
	end
	local prefsuf = ("="):rep(level)
	ins(prefsuf .. process_continued_string(group[1], subvals) .. prefsuf)
	local ind = 2
	if type(group[2]) == "string" then
		ins(process_continued_string(group[2], subvals))
		ind = ind + 1
	end
	ins('{| class="wikitable"')
	ins("! Parameter")
	ins("! Can be annotated")
	ins("! Can contain multiple semicolon-separated entities")
	ins("! Remarks")
	for i = ind, #group do
		local paramspec, desc = unpack(group[i])
		ins('|- style="vertical-align: top"')
		ins('| style="text-align: center" | ' .. format_param_spec(paramspec))
		ins('| style="text-align: center" | ' .. ((paramspec.annotated or paramspec.multientity) and "'''Yes'''" or "No"))
		ins('| style="text-align: center" | ' .. (paramspec.multientity and "'''Yes'''" or "No"))
		ins("| " .. process_continued_string(desc, subvals))
	end
	ins("|}")
	return table.concat(parts, "\n")
end


local function format_inline_modifiers(mods)
	local parts = {}
	local function ins(txt)
		table.insert(parts, txt)
	end
	ins('{| class="wikitable"')
	ins("! Modifier")
	ins("! Remarks")
	for _, modspec in ipairs(mods) do
		local modifier, desc = unpack(modspec)
		ins('|- style="vertical-align: top"')
		ins('| style="text-align: center" | <code>' .. modifier .. "</code>")
		ins("| " .. process_continued_string(desc, {}))
	end
	ins("|}")
	return table.concat(parts, "\n")
end


local function format_introduction(template)
	local parts = {}
	local function ins(txt)
		table.insert(parts, txt)
	end


	ins("===Introduction===")
	ins(process_continued_string(generate_param_intro_text(template), {}))
	ins("")
	ins('{| class="wikitable"')
	ins("! Modifier")
	ins("! Remarks")
	for _, modspec in ipairs(generate_inline_modifiers(template)) do
		local modifier, desc = unpack(modspec)
		ins('|- style="vertical-align: top"')
		ins('| style="text-align: center" | <code>' .. modifier .. "</code>")
		ins("| " .. process_continued_string(desc, {}))
	end
	ins("|}")
	return table.concat(parts, "\n")
end


function export.show_doc(template)
	if type(template) == "table" then
		template = template.args[1]
	end
	local params = generate_params(template)
	local mods = quote_mods[template]
	if not mods then
		error(("No modifications found for template '%s'"):format(template))
	end
	local subvals = apply_mods(params, mods)

	local parts = { format_introduction(template) }
	for _, group in ipairs(params) do
		table.insert(parts, format_parameter_group(group, subvals, 3))
	end
	return table.concat(parts, "\n\n")
end


return export

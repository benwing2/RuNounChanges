--[=[
	This module contains functions to implement {{form of/*doc}} templates.
	The module contains the actual implementation, meant to be called from other
	Lua code. See [[Module:form of doc/templates]] for the function meant to be
	called directly from templates.

	Author: Benwing2
]=]

local export = {}

local m_template_link = require("Module:template link")
local m_languages = require("Module:languages")
local m_table = require("Module:table")
local form_of_module = "Module:form of"
local m_form_of = require(form_of_module)
local labels_module = "Module:labels"
local strutils = require("Module:string utilities")

local usub = mw.ustring.sub
local uupper = mw.ustring.upper
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub


-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end


local function lang_name(langcode, param)
	local lang = m_languages.getByCode(langcode, param)
	return lang:getCanonicalName()
end


local function ucfirst(text)
	return uupper(usub(text, 1, 1)) .. usub(text, 2)
end


local function preprocess(desc)
	if desc:find("{") then
		desc = mw.getCurrentFrame():preprocess(desc)
	end
	return desc
end


function link_box(content)
	return "<div class=\"noprint plainlinks\" style=\"float: right; clear: both; margin: 0 0 .5em 1em; background: #f9f9f9; border: 1px #aaaaaa solid; margin-top: -1px; padding: 5px; font-weight: bold; font-size: small;\">"
		.. content .. "</div>"
end


function show_editlink(page)
	return link_box("[" .. tostring(mw.uri.fullUrl(page, "action=edit")) .. " Edit]")
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
   of "or" (as is normal for aliases). Other named fields are possible:
   * <code>useand = true</code>: Join the parameters using "and" instead of "or"; see above.
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

local params = {
	{"Date-related parameters",
	{"date", [=[The date that the {{{worktype}}} was published. Use either {{para|year}} (and optionally {{para|month}}), or
	{{para|date}}, not both. The value of {{para|date}} must be an actual date, with or without the day, rather than
	arbitrary text. Various formats are allowed; it is recommended that you either write in YYYY-MM-DD format, e.g.
	<code>2023-08-11</code>, or spell out the month, e.g. <code>2023 August 11</code> (permutations of the latter are
	allowed, such as <code>August 11 2023</code> or <code>11 August 2023</code>). You can omit the day and the code
	will attempt to display the date with only the month and year. Regardless of the input format, the output will be
	displayed in the format <code>'''2023''' August 11</code>, or <code>'''2023''' August</code> if the day was
	omitted.]=]},
	{{"year", "month", useand = true}, [=[The year and (optionally) the month that the {{{worktype}}} was published. The values
	of these parameters are not parsed, and arbitrary text can be given if necessary. If the year is preceded by
	<code>c.</code>, e.g. <code>c. 1665</code>, it indicates that the publication year was {{glink|c.|circa}} (around)
	the specified year; similarly <code>a.</code> indicates a publication year {{glink|a.|ante}} (before) the specified
	year, and <code>p.</code> indicates a publication year {{glink|p.|post}} (after) the specified year. The year will
	be displayed boldface unless there is boldface already in the value of the {{para|year}} parameter, and the month
	(if given) will follow. If neither date nor year/month is given, the template displays the message
	"(Can we [[:Category:Requests for date|date]] this quote?)" and adds the page to the category
	[[:Category:Requests for date in LANG entries]], using the language specified in {{para|1}}. The message and
	category addition can be suppressed using {{para|nodate|1}}, but it is recommended that you try to provide a date
	or approximate date rather than do so. The category addition alone can be suppressed using {{para|nocat|1}}, but
	this is not normally recommended.]=]},
	{"start_date", [=[If the publication spanned a range of dates, place the starting date in {{para|start_date}} (or
	{{para|start_year}}/{{para|start_month}}) and the ending date in {{para|date}} (or {{para|year}}/{{para|month}}).
	The format of {{para|start_date}} is as for {{para|date}}. If the dates have the same year but different month and
	day, the year will only be displayed once, and likewise if only the days differ. Use only one of {{para|start_date}}
	or {{para|start_year}}/{{para|start_month}}, not both.]=]},
	{{"start_year", "start_month", useand = true}, [=[Alternatively, specify a range by placing the start year and
	month in {{para|start_year}} and (optionally) {{para|start_month}}. These can contain arbitrary text, as with
	{{para|year}} and {{para|month}}. To indicate that publication is around, before or after a specified range, place
	the appropriate indicator (<code>c.</code>, <code>a.</code> or <code>p.</code>) before the {{para|year}} value,
	not before the {{para|start_year}} value.]=]},
	{{"nodate", boolean = true}, [=[Specify {{para|nodate|1}} if the {{{worktype}}} is undated and no date (even approximate) can
	reasonably be determined. This suppresses the maintenance line that is normally displayed if no date is given. Do
	not use this just because you don't know the date; instead, leave out the date and let the maintenance line be
	displayed and the page be added to the appropriate maintenance category, so that someone else can help.]=],},
	},

	{"Author-related parameters",
	{{"author", list = true}, [=[The name(s) of the author(s) of the {{{worktype}}} quoted. Separate multiple authors with
	semicolons, or use the additional parameters {{para|author2}}, {{para|author3}}, etc. Alternatively, use
	{{para|last}} and {{para|first}} (for the first name, and middle names or initials), along with
	{{para|last2}}/{{para|first2}} for additional authors. Do not use both at once.]=]},
	{{"last", "first", useand = true, list = true}, [=[The first (plus middle names or initials) and last name(s) of
	the author(s) of the {{{worktype}}} quoted. Use {{para|last2}}/{{para|first2}}, {{para|last3}}/{{para|first3}}, etc. for
	additional authors. It is preferred to use {{para|author}} over {{para|last}}/{{para|first}}, especially for names
	of foreign language speakers, where it may not be easy to segment into first and last names. Note that these
	parameters do not support inline modifiers and do not do automatic script detection; hence they can only be used
	for Latin-script names.]=]},
	{{"authorlink", list = true}, [=[The name of an [https://en.wikipedia.org English Wikipedia] article about the
	author, which will be linked to the name(s) specified using {{para|author}} or {{para|last}}/{{para|first}}.
	Additional articles can be linked to other authors' names using the parameters {{para|authorlink2}},
	{{para|authorlink3}}, etc. Do not add the prefix <code>:en:</code> or <code>w:</code>.

	Alternatively, link each person's name directly, like this:
	{{para|author|<nowiki>[[w:Kathleen Taylor (biologist)|Kathleen Taylor]]</nowiki>}} or
	{{para|author|<nowiki>{{w|Samuel Johnson}}</nowiki>}}.]=]},
	{"coauthors", "The names of the coauthor(s) of the {{{worktype}}}. Separate multiple names with semicolons."},
	{"mainauthor", [=[If you wish to indicate who a part of {{{a_worktype}}} such as a foreword or introduction was written by,
	use {{para|author}} to do so, and use {{para|mainauthor}} to indicate the author(s) of the main part of the {{{worktype}}}.
	Separate multiple authors with semicolons.]=]},
	{{"tlr", "translator", "translators"}, [=[The name(s) of the translator(s) of the {{{worktype}}}. Separate multiple names
	with semicolons.]=]},
	{{"editor", "editors"}, [=[The name(s) of the editor(s) of the {{{worktype}}}. Separate multiple names with semicolons.]=],},
	{"quotee", [=[The name of the person being quoted, if the whole text quoted is a quotation of someone other than
	the author.]=]},
	},

	{"Title-related parameters",
	{{"title", required = true}, [=[The title of the {{{worktype}}}.]=]},
	{"trans-title", [=[If the title of the {{{worktype}}} is not in English, this parameter can be used to provide an English
	translation of the title, as an alternative to specifying the translation using an inline modifier (see below).]=]},
	{{"series", "seriesvolume", useand = true}, [=[The {{w|book series|series}} that the {{{worktype}}} belongs to, and the
	volume number of the {{{worktype}}} within the series.]=]},
	{"url", [=[The URL or web address of an external website containing the full text of the {{{worktype}}}. ''Do not link to
	any website that has content in breach of copyright''.]=]},
	{"urls", [=[Freeform text, intended for multiple URLs. Unlike {{para|url}}, the editor must supply the URL brackets
	<code>[]</code>.]=]},
	},

	{"Chapter-related parameters",
	{"chapter", [=[The chapter of the {{{worktype}}} quoted. You can either specify a chapter number in Arabic or Roman numerals
	(for example, {{para|chapter|7}} or {{para|chapter|VII}}) or a chapter title (for example,
	{{para|chapter|Introduction}}). A chapter given in Arabic or Roman numerals will be preceded by the word "chapter",
	while a chapter title will be enclosed in “curly quotation marks”.]=]},
	{"chapter_number", [=[If the name of the chapter was supplied in {{para|chapter}}, use {{para|chapter_number}} to
	provide the corresponding chapter number, which will be shown in parentheses after the word "chapter", e.g.
	<code>“Experiments” (chapter 4)</code>.]=]},
	{"chapter_plain", [=[The full value of the chapter, which will be displayed as-is. Include the word "chapter" and
	any desired quotation marks. If both {{para|chapter}} and {{para|chapter_plain}} are given, the value of
	{{para|chapter_plain}} is shown after the chapter, in parentheses. This is useful if chapters in this {{{worktype}}} have are
	given a term other than "chapter".]=]},
	{"chapterurl", [=[The [[w:Universal Resource Locator|URL]] or web address of an external webpage to link to the
	chapter. For example, if the {{{worktype}}} has no page numbers, the webpage can be linked to the chapter using this
	parameter. ''Do not link to any website that has content in breach of [[w:copyright|copyright]]''.]=]},
	{"trans-chapter", [=[If the chapter of the {{{worktype}}} is not in English, this parameter can be used to provide an English
	translation of the chapter, as an alternative to specifying the translation using an inline modifier (see
	below).]=]},
	{"chapter_tlr", [=[The translator of the chapter, if separate from the overall translator of the {{{worktype}}} (specified
	using {{para|tlr}} or {{para|translator}}).]=]},
	{{"chapter_series", "chapter_seriesvolume", useand = true}, [=[If this chapter is part of a series of similar
	chapters, {{para|chapter_series}} can be used to specify the name of the series, and {{para|chapter_seriesvolume}}
	can be used to specify the index of the series, if it exists. Compare the {{para|series}} and {{para|seriesvolume}}
	parameters for the {{{worktype}}} as a whole. These parameters are used especially in conjunction with recurring columns in
	a newspaper or similar. In {{tl|quote-journal}}, the {{para|chapter}} parameter is called {{para|title}} and is
	used to specify the name of a journal, magazine or newspaper article, and the {{para|chapter_series}} parameter is
	called {{para|title_series}} and is used to specify the name of the column or article series that the article is
	part of.]=]},
	},

	{"Section-related parameters",
	{"section", [=[Use this parameter to identify a (usually numbered) portion of {{{a_worktype}}}, as an alternative or
	complement to specifying a chapter. For example, in a play, use {{para|section|act II, scene iv}}, and in a
	technical journal article, use {{para|section|4}}. If the value of this parameter looks like a Roman or Arabic
	numeral, it will be prefixed with the word "section", otherwise displayed as-is (compare the similar handling of
	{{para|chapter}}).]=]},
	{"section_number", [=[If the name of a section was supplied in {{para|section}}, use {{para|section_number}} to
	provide the corresponding section number, which will be shown in parentheses after the word "section", e.g.
	<code>Experiments (section 4)</code>.]=]},
	{"section_plain", [=[The full value of the section, which will be displayed as-is; compare {{para|chapter_plain}}.
	(This is provided only for completeness, and is not generally useful, since the value of {{para|section}} is also
	displayed as-is if it doesn't look like a number.)]=]},
	{"sectionurl", [=[The [[w:Universal Resource Locator|URL]] or web address of an external webpage to link to the
	section. ''Do not link to any website that has content in breach of [[w:copyright|copyright]]''.]=]},
	{"trans-section", [=[If the section of the {{{worktype}}} is not in English, this parameter can be used to provide an English
	translation of the section, as an alternative to specifying the translation using an inline modifier (see
	below).]=]},
	{{"section_series", "section_seriesvolume", useand = true}, [=[If this section is part of a series of similar
	sections, {{para|section_series}} can be used to specify the name of the series, and {{para|section_seriesvolume}}
	can be used to specify the index of the series, if it exists. Compare the {{para|series}} and {{para|seriesvolume}}
	parameters for the {{{worktype}}} as a whole, and the {{para|chapter_series}} and {{para|chapter_seriesvolume}} parameters
	for a chapter.]=]},
	},

	{"Page- and line-related parameters",
	{{"page", "pages"}, [=[The page number or range of page numbers of the {{{worktype}}}. Use an en dash (–) to separate the
	page numbers in the range. Under normal circumstances, {{para|page}} and {{para|pages}} are aliases of each other,
	and the code autodetects whether to display singular "page" or plural "pages" before the supplied number or range.
	The autodetection code displays the "pages" if it finds an en-dash (–), an em-dash (—), a hyphen between numbers,
	or a comma followed by a space and between numbers (the space is necessary, so that numbers like <code>1,478</code>
	with a thousands separator don't get treated as multiple pages). To suppress the autodetection (for example, some
	books have hyphenated page numbers like <code>3-16</code>), precede the value with an exclamation point
	(<code>!</code>); if this is given, the name of the parameter determines whether to display "page" or "pages".
	Alternatively, use {{para|page_plain}}. As a special case, the value <code>unnumbered</code> causes
	<code>unnumbered page</code> to display.]=]},
	{"page_plain", [=[Free text specifying the page or pages of the quoted text, e.g. <code>folio 8</code> or
	<code>back cover</code>. Use only one of {{para|page}}, {{para|pages}} and {{para|page_plain}}.]=]},
	{"pageurl", [=[The URL or web address of the webpage containing the page(s) of the {{{worktype}}} referred to. The page
	number(s) will be linked to this webpage.]=]},
	{{"line", "lines"}, [=[The line number(s) of the quoted text, e.g. <code>47</code> or <code>151–154</code>. These
	parameters {{{worktype}}} identically to {{para|page}} and {{para|pages}}, respectively. Line numbers are often used in
	plays, poems and certain technical works.]=]},
	{"line_plain", [=[Free text specifying the line number(s) of the quoted text, e.g. <code>verses 44–45</code> or
	<code>footnote 3</code>. Use only one of {{para|line}}, {{para|lines}} and {{para|line_plain}}.]=]},
	{"lineurl", [=[The URL or web address of the webpage containing the line(s) of the {{{worktype}}} referred to. The line
	number(s) will be linked to this webpage.]=]},
	{{"column", "columns", "column_plain", "columnurl", useand = true}, [=[The column number(s) of the quoted text.
	These parameters {{{worktype}}} identically to {{para|page}}, {{para|pages}}, {{para|page_plain}} and {{para|pageurl}},
	respectively.]=]},
	},

	{"Publication-related parameters",
	{"publisher", [=[The name of one or more publishers of the {{{worktype}}}. If more than one publisher is stated, separate the
	names with semicolons.]=]},
	{"location", [=[The location where the {{{worktype}}} was published. If more than one location is stated, separate the
	locations with semicolons, like this: <code>London; New York, N.Y.</code>.]=]},
	{"edition", [=[The edition of the {{{worktype}}} quoted, for example, <code>2nd</code> or <code>3rd corrected and revised</code>.
	This text will be followed by the word "edition" (use {{para|edition_plain}} to avoid this). If quoting from the
	first edition of the {{{worktype}}}, it is usually not necessary to specify this fact.]=]},
	{"edition_plain", [=[Free text specifying the edition of the {{{worktype}}} quoted, e.g. <code>3rd printing</code> or
	<code>5th edition, digitized</code> or <code>version 3.72</code>.]=]},
	{{"year_published", "month_published", useand = true}, [=[If {{para|year}} is used to state the year when the
	original version of the {{{worktype}}} was published, {{para|year_published}} can be used to state the year in which the
	version quoted from was published, for example, "<code>|year=1665|year_published=2005</nowiki>".
	{{para|month_published}} can optionally be used to specify the month of publication. The year published is preceded
	by the word "published". These parameters are handled in an identical fashion to {{para|year}} and {{para|month}}
	(except that the year isn't displayed boldface by default). This means, for example, that the prefixes
	<code>c.</code>, <code>a.</code> and <code>p.</code> are recognized to specify that the publication happened
	circa/before/after a specified date.]=]},
	{"date_published", [=[The date that the version of the {{{worktype}}} quoted from was published. Use either
	{{para|year_published}} (and optionally {{para|month_published}}), or {{para|date_published}}, not both. As with
	{{para|date}}, the value of {{para|date_published}} must be an actual date, with or without the day, rather than
	arbitrary text. The same formats are recognized as for {{para|date}}.]=]},
	{{"start_year_published", "start_month_published", useand = true}, [=[If the publication of the version quoted from
	spanned a range of dates, specify the starting year (and optionally month) using these parameters and place the
	ending date in {{para|year_published}}/{{para|month_published}} (or {{para|date_published}}). This works identically
	to {{para|start_year}}/{{para|start_month}}. It is rarely necessary to use these parameters.]=]},
	{"start_date_published", [=[Start date of the publication of the version quoted from, as an alternative to
	specifying {{para|start_year_published}}/{{para|start_month_published}}. This works like {{para|start_date}}. It is
	rarely necessary to specify this parameter.]=]},
	{{"origyear", "origmonth", useand = true}, [=[The year when the {{{worktype}}} was originally published, if the {{{worktype}}} quoted
	from is a new version of {{{a_worktype}}} (not merely a new printing). For example, if quoting from a modern edition of
	Shakespeare or Milton, put the date of the modern edition in {{para|year}}/{{para|month}} or {{para|date}} and the
	date of the original edition in {{para|origyear}}/{{para|origmonth}} or {{para|origdate}}. {{para|origmonth}} can
	optionally be used to supply the original month of publication, or a full date can be given using {{para|origdate}}.
	Use either {{para|origyear}}/{{para|origmonth}} or {{para|origdate}}, not both. These parameters are handled in an
	identical fashion to {{para|year}} and {{para|month}} (except that the year isn't displayed boldface by default).
	This means, for example, that the prefixes <code>c.</code>, <code>a.</code> and <code>p.</code> are recognized to
	specify that the original publication happened circa/before/after a specified date.]=]},
	{"origdate", [=[The date that the original version of the {{{worktype}}} quoted from was published. Use either
	{{para|origyear}} (and optionally {{para|origmonth}}), or {{para|origdate}}, not both. As with {{para|date}}, the
	value of {{para|origdate}} must be an actual date, with or without the day, rather than arbitrary text. The same
	formats are recognized as for {{para|date}}.]=]},
	{{"origstart_year", "origstart_month", "origstart_date", useand = true}, [=[The start year/month or date of the
	original version of publication, if the publication happened over a range.  Use either {{para|origstart_year}} (and
	optionally {{para|origstart_month}}), or {{para|origstart_date}}, not both. These {{{worktype}}} just like
	{{para|start_year}}, {{para|start_month}} and {{para|start_date}}, and very rarely need to be specified.]=]},
	{"platform", [=[The platform on which the {{{worktype}}} has been published. This is intended for content aggregation
	platforms such as {{w|YouTube}}, {{w|Issuu}} and {{w|Magzter}}. This displays as "via PLATFORM".]=]},
	{"source", [=[The source of the content of the {{{worktype}}}. This is intended e.g. for news agencies such as the
	{{w|Associated Press}}, {{w|Reuters}} and {{w|Agence France-Presse}} (AFP) (and is named {{para|newsagency}} in
	{{tl|quote-journal}} for this reason). This displays as "sourced from SOURCE".]=]},
	},

	{"Volume-related parameters",
	{{"volume", "volumes"}, [=[The volume number(s) of the {{{worktype}}}. This displays as "volume VOLUME", or "volumes VOLUMES"
	if a range of numbers is given. Whether to display "volume" or "volumes" is autodetected, exactly as for
	{{para|page}} and {{para|pages}}; use <code>!</code> at the beginning of the value to suppress this and respect the
	parameter name. Use {{para|volume_plain}} if you wish to suppress the word "volume" appearing in front of the volume
	number.]=]},
	{"volume_plain", [=[Free text specifying the volume number(s) of the {{{worktype}}}, e.g. <code>book II</code>. Use only one
	of {{para|volume}}, {{para|volumes}} and {{para|volume_plain}}.]=]},
	{"volumeurl", [=[The URL or web address of the webpage corresponding to the volume containing the quoted text, if
	the {{{worktype}}} has multiple volumes with different URL's. The volume number(s) will be linked to this webpage.]=]},
	{{"issue", "issues", "issue_plain", "issueurl", useand = true}, [=[The issue number(s) of the quoted text. These
	parameters {{{worktype}}} identically to {{para|page}}, {{para|pages}}, {{para|page_plain}} and {{para|pageurl}},
	respectively, except that the displayed text contains the term "number" or "numbers" rather than "issue" or
	"issues", as might be expected. Examples of the use of {{para|issue_plain}} are <code>book 2</code> (if {{{a_worktype}}} is
	divided into volumes and volumes are divided into books) or <code>Sonderheft 1</code> (where ''Sonderheft'' means
	"special issue" in German).]=]},
	},

	{"ID-related parameters",
	{{"doi", "DOI"}, [=[The [[w:Digital object identifier|digital object identifier]] (DOI) of the {{{worktype}}}.]=]},
	{{"isbn", "ISBN"}, [=[The [[w:International Standard Book Number|International Standard Book Number]] (ISBN) of
	the {{{worktype}}}. 13-digit ISBN's are preferred over 10-digit ones.]=]},
	{{"issn", "ISSN"}, [=[w:International Standard Serial Number|International Standard Serial Number]] (ISSN) of the
	{{{worktype}}}.]=]},
	{{"jstor", "JSTOR"}, [=[The [[w:JSTOR|JSTOR]] number of the {{{worktype}}}.]=]},
	{{"lccn", "LCCN"}, [=[The [[w:Library of Congress Control Number|Library of Congress Control Number]] (LCCN) of
	the {{{worktype}}}.]=]},
	{{"oclc", "OCLC"}, [=[The [[w:OCLC|Online Computer Library Center]] (OCLC) number of the {{{worktype}}} (which can be looked
	up at the [http://www.worldcat.org WorldCat] website).]=]},
	{{"ol", "OL"}, [=[The [[w:Open Library|Open Library]] number (omitting "OL") of the {{{worktype}}}.]=]}.
	{{"pmid", "PMID"}, [=[The [[w:PubMed#PubMed identifier|PubMed]] identifier (PMID) of the {{{worktype}}}.]=]}.
	{{"pmcid", "PMCID"}, [=[The [[w:PubMed Central#PMCID|PubMed Central]] identifier (PMCID) of the {{{worktype}}}.]=]}.
	{{"ssrn", "SSRN"}, [=[The [[w:Social Science Research Network|Social Science Research Network]] (SSRN) identifier
	of the {{{worktype}}}.]=]}.
	{"bibcode", [=[The {{w|bibcode}} (bibliographic code, used in astronomical data systems) of the {{{worktype}}}.]=]},
	{"id", [=[Any miscellaneous identifier of the {{{worktype}}}.]=]}.
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
	{"format", [=[The format that the {{{worktype}}} is in, for example, "<code>hardcover</code>" or "<code>paperback</code>" for
	a book or "<code>blog</code>" for a web page.]=]},
	{"genre", [=[The {{w|literary genre}} of the {{{worktype}}}, for example, "<code>fiction</code>" or
	"<code>non-fiction</code>".]=]},
	{{"nocat", boolean = true}, [=[Specify {{para|nocat|1}} to suppress adding the page to a category of the form
	<code>Category:LANGUAGE terms with quotations</code>. This should not normally be done.]=]},
	},

	{"Quoted text parameters",
	{{"1", required = true}, [=[A comma-separated list of language codes indicating the language(s) of the quoted text;
	for a list of the codes, see [[Wiktionary:List of languages]]. If the language is other than English, the template
	will indicate this fact by displaying "(in [''language''])" (for one language), or "(in [''language''] and
	[''language''])" (for two languages), or "(in [''language''], [''language''] ... and [''language''])" (for three or
	more languages). The entry page will also be added to a category in the form <code>Category:LANGUAGE terms with
	quotations</code> for the first listed language (unless {{para|termlang}} is specified, in which case that language
	is used for the category, or {{para|nocat|1}} is specified, in which case the page will not be added to any
	category). The first listed language also determines the font to use and the appropriate transliteration to display,
	if the text is in a non-Latin script.

	Use {{para|worklang}} to specify the language(s) that the book itself is written in: see below.

	<small>The parameter {{para|lang}} is a deprecated synonym for this parameter; please do not use. If this is used,
	all numbered parameters move down by one.</small>]=]},
	{{"text", "passage"}, [=[The text being quoted. Use boldface to highlight the term being defined, like this:
	"<code><nowiki>'''humanities'''</nowiki></code>".]=]},
	{"worklang", [=[A comma-separated list of language codes indicating the language(s) that the book is written in, if
	different from the quoted text; for a list of the codes, see [[Wiktionary:List of languages]].]=]},
	{"termlang", [=[A language code indicating the language of the term being illustrated, if different from the quoted
	text; for a list of the codes, see [[Wiktionary:List of languages]]. If specified, this language is the one used
	when adding the page to a category of the form <code>Category:LANGUAGE terms with quotations</code>; otherwise, the
	first listed language specified using {{para|1}} is used. Only specify this parameter if the language of the
	quotation is different from the term's language, e.g. a Middle English quotation used to illustrate a modern
	English term or an English definition of a Vietnamese term in a Vietnamese-English dictionary.]=]},
	{{"brackets", boolean = true}, [=[Surround a quotation with [[bracket]]s. This indicates that the quotation either
	contains a mere mention of a term (for example, "some people find the word '''''manoeuvre''''' hard to spell")
	rather than an actual use of it (for example, "we need to '''manoeuvre''' carefully to avoid causing upset"), or
	does not provide an actual instance of a term but provides information about related terms.]=]},
	{{"t", "translation"}, [=[If the quoted text is not in English, this parameter can be used to provide an English
	[[translation]] of it.]=]},
	{"lit", [=[If the quoted text is not in English and the translation supplied using {{para|t}} or
	{{para|translation}} is idiomatic, this parameter can be used to provide a [[literal]] English [[translation]].]=]},
	{"footer", [=[This parameter can be used to specify arbitrary text to insert in a separate line at the bottom, to
	specify a comment, footnote, etc.]=]},
	{{"norm", "normalization"}, [=[If the quoted text is written using nonstandard spelling, this parameter supplies
	the normalized (standardized) version of the quoted text. This applies especially to older quotations. For example,
	for Old Polish, this parameter could supply a version based on modern Polish spelling conventions, and for Russian
	text prior to the 1917 spelling reform, this could supply the reformed spelling.]=]},
	{{"tr", "transliteration"}, [=[If the quoted text uses a different {{w|writing system}} from the {{w|Latin
	alphabet}} (the usual alphabet used in English), this parameter can be used to provide a [[transliteration]] of it
	into the Latin alphabet. Note that many languages provide an automatic transliteration if this argument is not
	specified. If a normalized version of the quoted text is supplied using {{para|norm}}, the transliteration will be
	based on this version if possible (falling back to the actual quoted text if the transliteration of the normalized
	text fails or if the normalization is supplied in Latin script and the original in a non-Latin script).]=]},
	{"subst", [=[Phonetic substitutions to be applied to handle irregular transliterations in certain languages with a
	non-Latin writing system and automatic transliteration (e.g. Russian and Yiddish). If specified, should be one or
	more substitution expressions separated by commas, where each substitution expression is of the form
	<code>FROM//TO</code> (<code>FROM/TO</code> is also accepted), where <code>FROM</code> specifies the source text in
	the source script (e.g. Cyrillic or Hebrew) and <code>TO</code> is the corresponding replacement text, also in the
	source script. The intent is to respell irregularly-pronounced words phonetically prior to transliteration, so that
	the transliteration reflects the pronunciation rather than the spelling. The substitutions are applied in order.
	Note that Lua patterns can be used in <code>FROM</code> and <code>TO</code> in lieu of literal text; see [[WT:LUA]].
	See also {{temp|ux}} for an example of using {{para|subst}} (the usage is identical to that template). If
	{{para|norm}} is used to provide a normalized version of the quoted text, the substitutions will also apply to this
	version when transliterating it.]=]},
	{{"ts", "transcription"}, [=[Phonetic transcription of the quoted text, if in a non-Latin script where the
	transliteration is markedly different from the actual pronunciation (e.g. Akkadian, Ancient Egyption and Tibetan).
	This should not be used merely to supply the IPA pronunciation of the text.]=]},
	{"sc", [=[The script code of the quoted text, if not in the Latin script. See [[Wiktionary:Scripts]] for more
	information. It is rarely necessary to specify this as the script is autodetected based on the quoted text.]=]},
	{"normsc", [=[The script code of the normalized text in {{para|norm}}, if not in the Latin script. If unspecified,
	and a value was given in {{para|sc}}, this value will be used to determine the script of the normalized text;
	otherwise (or if {{para|normsc|auto}} was specified), the script of the normalized text will be autodetected based
	on that text.]=]},
	},

	{"New version of {{{a_worktype}}}",
	[=[The following parameters can be used to indicate a new version of the {{{worktype}}}, such as a reprint, a new edition, or
	some other republished version. The general means of doing this is as follows:
	# Specify {{para|newversion|republished as}}, {{para|newversion|translated as}}, {{para|newversion|quoted in}} or
	similar to indicate what the new version is. (Under some circumstances, this parameter can be omitted; see below.)
	# Specify the author(s) of the new version using {{para|2ndauthor}} (separating multiple authors with a semicolon)
	or {{para|2ndlast}}/{{para|2ndfirst}}.
	# Specify the remaining properties of the new version by appending a <code>2</code> to the parameters as specified
	above, e.g. {{para|title2}} for the title of the new version, {{para|page2}} for the page number of the new
	version, etc.

	Some special-case parameters are supplied as an alternative to specifying a new version this way. For example, the
	{{para|original}} and {{para|by}} parameters can be used when quoting a translated version of {{{a_worktype}}}; see
	below.]=],
	{"newversion", [=[The template assumes that a new version of the {{{worktype}}} is referred to if {{para|newversion}} or
	{{para|location2}} are given, or if the parameters specifying the author of the new version are given
	({{para|2ndauthor}} or {{para|2ndlast}}), or if any other parameter indicating the title or author of the new
	version is given (any of {{para|chapter2}}, {{para|title2}}, {{para|tlr2}}, {{para|translator2}},
	{{para|translators2}}, {{para|mainauthor2}}, {{para|editor2}} or {{para|editors2}}). It then behaves as follows:
	* If an author, editor and/or title are stated, it indicates "republished as".
	* If only the place of publication, publisher and date of publication are stated, it indicates "republished".
	* If an edition is stated, no text is displayed.
	Use {{para|newversion}} to override this behaviour, for example, by indicating "quoted in" or "reprinted as".]=]},
	{"2ndauthor", [=[The author of the new version. Separate multiple authors with a semicolon. Alternatively, use
	{{para|2ndlast}} and {{para|2ndfirst}}.]=]},
	{{"2ndlast", "2ndfirst", useand = true}, [=[The first (plus middle names or initials) and last name(s) of the
	author of the new version. It is preferred to use {{para|2ndauthor}} over {{para|2ndlast}}/{{para|2ndfirst}}, for
	multiple reasons:
	# The names of foreign language speakers may not be easy to segment into first and last names.
	# Only one author can be specified using {{para|2ndlast}}/{{para|2ndfirst}}, whereas multiple semicolon-separated
	authors can be given using {{para|2ndauthor}}.
	# Inline modifiers are not supported for {{para|2ndlast}} and {{para|2ndfirst}} and script detection is not done,
	meaning that only Latin-script author names are supported.]=]},
	{"2ndauthorlink", [=[The name of an [https://en.wikipedia.org English Wikipedia] article about the author, which
	will be linked to the name(s) specified using {{para|2ndauthor}} or {{para|2ndlast}}/{{para|2ndfirst}}. Do not add
	the prefix <code>:en:</code> or <code>w:</code>. Alternatively, link each person's name directly, like this:
	{{para|2ndauthor|<nowiki>[[w:Kathleen Taylor (biologist)|Kathleen Taylor]]</nowiki>}}.]=]},
	{{"{{para|title2}}, {{para|editor2}}, {{para|location2}}, ''etc.''", literal = true}, [=[Most of the parameters
	listed above can be applied to a new version of the {{{worktype}}} by adding "<code>2</code>" after the parameter name. It is
	recommended that at a minimum the imprint information of the new version of the {{{worktype}}} should be provided using
	{{para|location2}}, {{para|publisher2}}, and {{para|date2}} or {{para|year2}}.]=]},
	},

	{"Alternative special-case ways of specifying a new version of {{{a_worktype}}}",
	[=[The following parameters provide alternative ways of specifying new version of {{{a_worktype}}}, such as a reprint or
	translation, or a case where part of one {{{worktype}}} is quoted in another. If you find that these parameters are
	insufficient for specifying all the information about both works, do not try to shoehorn the extra information in.
	Instead, use the method described above using {{para|newversion}} and {{para|2ndauthor}}, {{para|title2}}, etc.]=],
	{{"type", "original", "by", useand = true}, [=[If you are citing a {{w|derivative {{{worktype}}}}} such as a translation, use
	{{para|type}} to state the type of derivative {{{worktype}}}, {{para|original}} to state the title of the original {{{worktype}}}, and
	{{para|by}} to state the author of the original {{{worktype}}}. If {{para|type}} is not indicated, the template assumes that
	the derivative {{{worktype}}} is a translation.]=]},
	{"quoted_in", [=[If the quoted text is from book A which states that the text is from another book B, do the
	following:
	* Use {{para|title}}, {{para|edition}}, and {{para|others}} to provide information about book B. (As an example,
	{{para|others}} can be used like this: "{{para|others=1893, page 72}}".)
	* Use {{para|quoted_in}} (for the title of book A), {{para|location}}, {{para|publisher}}, {{para|year}},
	{{para|page}}, {{para|oclc}}, and other standard parameters to provide information about book A.]=]},
	},
}

local quote_book_mods = {
	{"#substitute", worktype = "book", a_worktype = "a book"},
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
	alternative to specifying the translation using an inline modifier (see below).]=]},
	{"chapterurl", addalias = "entryurl", [=[The [[w:Universal Resource Locator|URL]] or web address of
	an external webpage to link to the chapter or entry name. For example, if the book has no page numbers, the webpage
	can be linked to the chapter or entry name using this parameter. ''Do not link to any website that has content in
	breach of [[w:copyright|copyright]]''.]=]},
}

local quote_journal_mods = {
	{"#substitute", worktype = "article", a_worktype = "an article"},
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
	alternative to specifying the translation using an inline modifier (see below).]=]},
	{"chapterurl", addalias = "entryurl", [=[The [[w:Universal Resource Locator|URL]] or web address of
	an external webpage to link to the chapter or entry name. For example, if the book has no page numbers, the webpage
	can be linked to the chapter or entry name using this parameter. ''Do not link to any website that has content in
	breach of [[w:copyright|copyright]]''.]=]},
}

local function apply_mods(params, quote_book_mods)
	local mod_table = {}
	local subvals
	for _, mod in ipairs(quote_book_mods) do
		local param = mod[1]
		param[1] = nil
		if param == "#substitute" then
			subvals = param
		else
			mod_table[param] = mod
		end
	end

	for _, group in ipairs(params) do
		local ind = 2
		if type(group[2]) == "string" then
			ind = ind + 1
		end
		ins('{| class="wikitable"')
		ins("! Parameter")
		ins("! Remarks")
		for i = ind, #group do
			local paramspec, desc = unpack(group[i])
			ins('|- style="vertical-align: top"')
			ins('| style="text-align: center" | ' .. format_param_spec(paramspec))
			ins('| ' .. process_continued_string(desc, subvals))
		end
		end
end


-- Format a param spec as found in the first element of a param description.
local function format_param_spec(paramspec)
	if type(paramspec) ~= "table" or paramspec.param then
		paramspec = {paramspec}
	end

	local function format_one_param(param, non_generic)
		if non_generic then
			param = "<u>" .. param .. "</u>"
		if paramspec.boolean then
			return ("<code>|%s=1</code>"):format(param)
		else
			return ("<code>|%s=</code>"):format(param)
		end
	end

	local function format_all_params_no_list(suffix)
		local formatted = {}
		for _, p in ipairs(paramspec) do
			if type(p) == "string" then
				p = {param = p}
			end
			table.insert(formatted, format_one_param(p.param .. suffix, p.non_generic))
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
		formatted_params = paramspec[1]
	else
		formatted_params = format_all_params()
	end

	local reqtext = paramspec.required and " '''(required)'''" or ""
	return formatted_params .. reqtext
end


local function process_continued_string(desc, subvals)
	-- Join continuation lines. Do it twice in case of a single-character line (admittedly rare).
	desc = rsub(desc, "([^\n])\n[ \t]*([^ \t\n#*])", "%1 %2")
	desc = rsub(desc, "([^\n])\n[ \t]*([^ \t\n#*])", "%1 %2")
	-- Remove whitespace before list elements.
	desc = rsub(desc, "\n[ \t]*([#*])", "\n%1")
	desc = rsub(desc, "^[ \t]*([#*])", "%1")
	desc = rsub(desc, "{{{([^%}%{]+)}}}", function(item)
		if subvals[item] then
			if type(subvals[item]) == "string" or type(subvals[item]) == "number" then
				return subvals[item]
			else
				error("The item '{{{" .. item .. "}}}' is a " .. type(items[item]) .. " and can't be concatenated.")
			end
		else
			error("The item '" .. item .. "' was not found in the 'subvals' table.")
		end
	end)
	return preprocess(desc)
end


local function format_parameter_group(group, level, subvals)
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
	ins("! Remarks")
	for i = ind, #group do
		local paramspec, desc = unpack(group[i])
		ins('|- style="vertical-align: top"')
		ins('| style="text-align: center" | ' .. format_param_spec(paramspec))
		ins('| ' .. process_continued_string(desc, subvals))
	end
	ins("|}")
	return table.concat(parts, "\n")
end







	local 
end

local function template_name(preserve_lang_code)
	-- Fetch the template name, minus the '/documentation' suffix that may follow
	-- and without any language-specific prefixes (e.g. 'el-' or 'bsl-ine-pro-')
	-- (unless `preserve_lang_code` is given).
	local PAGENAME =  mw.title.getCurrentTitle().text
	local tempname = rsub(PAGENAME, "/documentation$", "")
	if not preserve_lang_code then
		while true do
			-- Repeatedly strip off language code prefixes, in case there are multiple.
			local newname = rsub(tempname, "^[a-z][a-z][a-z]?%-", "")
			if newname == tempname then
				break
			end
			tempname = newname
		end
	end
	return tempname
end


function export.introdoc(args)
	local langname = args.lang and lang_name(args.lang, "lang")
	local exlangnames = {}
	for _, exlang in ipairs(args.exlang) do
		table.insert(exlangnames, lang_name(exlang, "exlang"))
	end
	parts = {}
	table.insert(parts, mw.getCurrentFrame():expandTemplate {title="uses lua", args={form_of_module .. "/templates"}})
	table.insert(parts, "This template creates a definition line for ")
	table.insert(parts, args.pldesc or rsub(template_name(), " of$", "") .. "s")
	table.insert(parts, " ")
	table.insert(parts, args.primaryentrytext or "of primary entries")
	if args.lang then
		table.insert(parts, " in " .. langname)
	elseif #args.exlang > 0 then
		table.insert(parts, ", e.g. in " .. m_table.serialCommaJoin(exlangnames, {conj = "or"}))
	end
	table.insert(parts, ".")
	if #args.cat > 0 then
		table.insert(parts, " It also categorizes the page into ")
		local catparts = {}
		for _, cat in ipairs(args.cat) do
			if args.lang then
				table.insert(catparts, "[[:Category:" .. langname .. " " .. cat .. "]]")
			else
				table.insert(catparts, "the proper language-specific subcategory of [[:Category:" .. ucfirst(cat) .. " by language]] (e.g. [[:Category:" .. (exlangnames[1] or "English") .. " " .. cat .. "]])")
			end
		end
		table.insert(parts, m_table.serialCommaJoin(catparts))
		table.insert(parts, ".")
	end
	if args.addlintrotext then
		table.insert(parts, " ")
		table.insert(parts, args.addlintrotext)
	end
	table.insert(parts, "\n")
	if args.withcap and args.withdot then
		table.insert(parts, [===[

By default, this template displays its output as a full sentence, with an initial capital letter and a trailing period (full stop). This can be overridden using <code>|nocap=1</code> and/or <code>|nodot=1</code> (see below).
]===])
	elseif args.withcap then
		table.insert(parts, [===[

By default, this template displays its output with an initial capital letter. This can be overridden using <code>|nocap=1</code> (see below).
]===])
	end
	table.insert(parts, [===[

This template is '''not''' meant to be used in etymology sections.]===])
	if args.etymtemp then
		table.insert(parts, " For those sections, use <code>{{[[Template:" .. args.etymtemp .. "|" .. args.etymtemp .. "]]}}</code> instead.")
	end
	table.insert(parts, [===[


Note that users can customize how the output of this template displays by modifying their monobook.css files. See [[:Category:Form-of templates|“Form of” templates]] for details.
]===])
	return table.concat(parts)
end


function export.paramdoc(args)
	local parts = {}

	local function param_and_doc(params, list, required, doc)
		table.insert(parts, "; ")
		table.insert(parts, param(params, list, required))
		table.insert(parts, "\n")
		table.insert(parts, ": ")
		table.insert(parts, doc)
		table.insert(parts, "\n")
	end

	local tempname = template_name()
	local art = args.art or rfind(tempname, "^[aeiouAEIOU]") and "an" or "a"
	local sgdescof = args.sgdescof or art .. " " .. tempname
	table.insert(parts, "''Positional (unnamed) parameters:''\n")
	if args.lang then
		param_and_doc("1", false, true, "The term to link to (which this page is " .. sgdescof .. "). This should include any needed diacritics as appropriate to " .. lang_name(args.lang, "lang") .. ". These diacritics will automatically be stripped out in the appropriate fashion in order to create the link to the page.")
		param_and_doc("2", false, false, "The text to be shown in the link to the term. If empty or omitted, the term specified by the first parameter will be used. This parameter is normally not necessary, and should not be used solely to indicate diacritics; instead, put the diacritics in the first parameter.")
	else
		param_and_doc("1", false, true, "The [[WT:LANGCODE|language code]] of the term linked to (which this page is " .. sgdescof .. "). See [[Wiktionary:List of languages]]. <small>The parameter <code>|lang=</code> is a deprecated synonym; please do not use. If this is used, all numbered parameters move down by one.</small>")
		param_and_doc("2", false, true, "The term to link to (which this page is " .. sgdescof .. "). This should include diacritics as appropriate to the language (e.g. accents in Russian to mark the stress, vowel diacritics in Arabic, macrons in Latin to indicate vowel length, etc.). These diacritics will automatically be stripped out in a language-specific fashion in order to create the link to the page.")
		param_and_doc("3", false, false, "The text to be shown in the link to the term. If empty or omitted, the term specified by the second parameter will be used. This parameter is normally not necessary, and should not be used solely to indicate diacritics; instead, put the diacritics in the second parameter.")
	end
	table.insert(parts, "''Named parameters:''\n")
	if args.etymtemp == 'contraction' then
		param_and_doc("mandatory", false, false, "If <code>|mandatory=1</code>, indicates that the contraction is mandatory.")
		param_and_doc("optional", false, false, "If <code>|optional=1</code>, indicates that the contraction is optional.")
	end
	param_and_doc({"t", args.lang and "3" or "4"}, false, false, "A gloss or short translation of the term linked to. <small>The parameter <code>|gloss=</code> is a deprecated synonym; please do not use.</small>")
	param_and_doc("tr", false, false, "Transliteration for non-Latin-script terms, if different from the automatically-generated one.")
	param_and_doc("ts", false, false, "Transcription for non-Latin-script terms whose transliteration is markedly different from the actual pronunciation. Should not be used for IPA pronunciations.")
	param_and_doc("sc", false, false, "Script code to use, if script detection does not work. See [[Wiktionary:Scripts]].")
	if args.withfrom then
		param_and_doc("from", true, false, "A label (see " .. m_template_link.format_link({"label"}) .. ") that gives additional information on the dialect that the term belongs to, the place that it originates from, or something similar.")
	end
	if args.withdot then
		param_and_doc("dot", false, false, "A character to replace the final dot that is normally shown automatically.")
		param_and_doc("nodot", false, false, "If <code>|nodot=1</code>, then no automatic dot will be shown.")
	end
	if args.withcap then
		param_and_doc("nocap", false, false, "If <code>|nocap=1</code>, then the first letter will be in lowercase.")
	end
	param_and_doc("id", false, false, "A sense id for the term, which links to anchors on the page set by the " .. m_template_link.format_link({"senseid"}) .. " template.")
	return table.concat(parts)
end


function export.usagedoc(args)
	local exlangs = {}
	for _, exlang in ipairs(args.exlang) do
		table.insert(exlangs, exlang)
	end
	table.insert(exlangs, 'en')
	table.insert(exlangs, 'de')
	table.insert(exlangs, 'ja')
	exlangs = m_table.removeDuplicates(exlangs)
	local sub = {}
	local langparts = {}
	for i, langcode in ipairs(exlangs) do
		table.insert(langparts, '<code>' .. langcode .. '</code> for ' .. lang_name(langcode, "exlang"))
	end
	sub.exlangs = m_table.serialCommaJoin(langparts, {conj = "or"})
	sub.tempname = template_name("preserve lang code")

	if args.lang then
		return strutils.format([===[
==Usage==
Use in the definition line, most commonly as follows:
 # {\op}{\op}{tempname}|<var><primary entry goes here></var>{\cl}{\cl}

===Parameters===
]===], sub) .. export.paramdoc(args)
	else
		return strutils.format([===[
==Usage==
Use in the definition line, most commonly as follows:
 # {\op}{\op}{tempname}|<var><langcode></var>|<var><primary entry goes here></var>{\cl}{\cl}
where <code><var><langcode></var></code> is the [[Wiktionary:Languages|language code]], e.g. {exlangs}.

===Parameters===
]===], sub) .. export.paramdoc(args)
	end
end


function export.fulldoc(args)
	local docsubpage = mw.getCurrentFrame():expandTemplate{title="documentation subpage", args={}}
	local shortcuts = #args.shortcut > 0 and require("Module:shortcut box").show(args.shortcut) or ""
	local introdoc = export.introdoc(args)
	local usagedoc = export.usagedoc(args)
	return docsubpage .. "\n" .. shortcuts .. introdoc .. "\n" .. usagedoc
end


function export.infldoc(args)
	args = m_table.shallowcopy(args)
	args.sgdesc = args.sgdesc or (args.art or "the") .. " " ..
		rsub(template_name(), " of$", "") .. (args.form and " " .. args.form or "")
	args.pldesc = args.sgdesc
	args.sgdescof = args.sgdescof or args.sgdesc .. " of"
	args.primaryentrytext = args.primaryentrytext or "of a primary entry"
	return export.fulldoc(args)
end


local tag_type_to_description = {
	-- If not listed, we just capitalize the first letter
	["tense-aspect"] = "Tense/aspect",
	["voice-valence"] = "Voice/valence",
	["comparison"] = "Degrees of comparison",
	["class"] = "Inflectional class",
	["sound change"] = "Sound changes",
	["grammar"] = "Misc grammar",
	["other"] = "Other tags",
}


local tag_type_order = {
	"person",
	"number",
	"gender",
	"animacy",
	"tense-aspect",
	"mood",
	"voice-valence",
	"non-finite",
	"case",
	"state",
	"comparison",
	"register",
	"deixis",
	"clusivity",
	"class",
	"attitude",
	"sound change",
	"grammar",
	"other",
}


local function tag_type_desc(tag_type)
	return tag_type_to_description[tag_type] or strutils.ucfirst(tag_type)
end


local function sort_by_first(namedata1, namedata2)
	return namedata1[1] < namedata2[1]
end


local function get_display_form(tag_set, lang)
	local norm_tag_sets = m_form_of.normalize_tag_set(tag_set, lang)
	if #norm_tag_sets == 1 then
		return m_form_of.get_tag_set_display_form(norm_tag_sets[1], lang)
	end
	-- If we have a conjoined shortcut that expands to multiple tag sets, display them using a numbered list.
	-- In order to do that inside a table we need a newline before the list.
	local display_forms = {}
	for _, norm_tag_set in ipairs(norm_tag_sets) do
		table.insert(display_forms, "\n# " .. m_form_of.get_tag_set_display_form(norm_tag_set, lang))
	end
	return table.concat(display_forms)
end

local function organize_tag_data(data_module)
	local tab = {}
	for name, data in pairs(data_module.tags) do
		if not data.tag_type then
			-- Throw an error because hopefully it will get noticed and fixed. If we just skip it, it may never get
			-- fixed.
			error("Tag '" .. name .. "' has no tag_type")
		end
		if not tab[data.tag_type] then
			tab[data.tag_type] = {}
		end
		table.insert(tab[data.tag_type], {name, data})
	end
	local tag_type_order_set = m_table.listToSet(tag_type_order)
	for tag_type, tags_of_type in pairs(tab) do
		if not tag_type_order_set[tag_type] then
			-- See justification above for throwing an error.
			error("Tag type '" .. tag_type .. "' not listed in tag_type_order")
		end
		table.sort(tags_of_type, sort_by_first)
	end

	return tab
end

function export.tagtable()
	local data_tab = organize_tag_data(mw.loadData(m_form_of.form_of_data_module))
	local data2_tab = organize_tag_data(mw.loadData(m_form_of.form_of_data2_module))

	local parts = {}

	local function ins(text)
		table.insert(parts, text)
	end

	local function insert_group(group)
		for _, namedata in ipairs(group) do
			local sparts = {}
			local name, data = unpack(namedata)
			table.insert(sparts, "| <code>" .. name .. "</code> || ")
			if data.shortcuts then
				local ssparts = {}
				for _, shortcut in ipairs(data.shortcuts) do
					table.insert(ssparts, "<code>" .. shortcut .. "</code>")
				end
				table.insert(sparts, table.concat(ssparts, ", ") .. " ")
			end
			table.insert(sparts, "|| " .. m_form_of.get_tag_display_form(name))
			ins("|-")
			ins(table.concat(sparts))
		end
	end

	ins('{|class="wikitable"')
	ins("! Canonical tag !! Shortcut(s) !! Display form")
	for _, tag_type in ipairs(tag_type_order) do
		local group_tab = data_tab[tag_type]
		if group_tab then
			ins("|-")
			ins('! colspan="3" style="text-align: center; background: #dddddd;" | ' ..  tag_type_desc(tag_type) ..
				" (more common)")
			insert_group(group_tab)
		end
		group_tab = data2_tab[tag_type]
		if group_tab then
			ins("|-")
			ins('! colspan="3" style="text-align: center; background: #dddddd;" | ' ..  tag_type_desc(tag_type) ..
				" (less common)")
			insert_group(group_tab)
		end
	end
	ins("|}")

	return table.concat(parts, "\n")
end

local function organize_non_alias_shortcut_data(data_module, lang)
	local non_alias_shortcuts = {}
	for shortcut, full in pairs(data_module.shortcuts) do
		if type(full) == "table" or m_form_of.is_link_or_html(full) or full:find("//") or full:find(":") then
			table.insert(non_alias_shortcuts, {shortcut, full, get_display_form({shortcut}, lang)})
		end
	end

	table.sort(non_alias_shortcuts, sort_by_first)

	return non_alias_shortcuts
end

function export.non_alias_shortcut_table()
	local non_alias_shortcuts = organize_non_alias_shortcut_data(mw.loadData(m_form_of.form_of_data_module))
	local non_alias_shortcuts2 = organize_non_alias_shortcut_data(mw.loadData(m_form_of.form_of_data2_module))

	local parts = {}

	local function ins(text)
		table.insert(parts, text)
	end

	local function insert_shortcut_group(shortcuts)
		for _, spec in ipairs(shortcuts) do
			local shortcut, full, display = unpack(spec)
			ins("|-")
			if type(full) == "table" then
				-- Grrr. table.concat() doesn't work on a table that comes from loadData(); use shallowcopy() to convert to
				-- regular table.
				full = "{" .. table.concat(m_table.shallowcopy(full), " ") .. "}"
			end
			ins(("| <code>%s</code> || <code>%s</code> || %s"):format(shortcut, full, display))
		end
	end

	ins('{|class="wikitable"')
	ins("! Shortcut !! Expansion !! Display form")
	if #non_alias_shortcuts > 0 then
		ins("|-")
		ins('! colspan="3" style="text-align: center; background: #dddddd;" | More common:')
		insert_shortcut_group(non_alias_shortcuts)
	end
	if #non_alias_shortcuts2 > 0 then
		ins("|-")
		ins('! colspan="3" style="text-align: center; background: #dddddd;" | Less common:')
		insert_shortcut_group(non_alias_shortcuts2)
	end
	ins("|}")

	return table.concat(parts, "\n")
end


local function find_categories_and_labels(catstruct)
	local cats = {}
	local labels = {}

	local function process_spec(spec)
		if type(spec) == "string" then
			table.insert(cats, spec)
			return
		elseif not spec or spec == true then
			-- Ignore labels, etc.
			return
		elseif type(spec) ~= "table" then
			error("Wrong type of condition " .. spec .. ": " .. type(spec))
		elseif spec.labels then
			m_table.extendList(labels, spec.labels)
			return
		end
		local predicate = spec[1]
		if predicate == "multi" or predicate == "cond" then
			-- WARNING! #spec doesn't work for objects loaded from loadData()
			for i, sp in ipairs(spec) do
				if i > 1 then
					process_spec(sp)
				end
			end
		elseif predicate == "pexists" then
			process_spec(spec[2])
			process_spec(spec[3])
		elseif predicate == "has" or predicate == "hasall" or predicate == "hasany" or
			predicate == "tags=" or predicate == "p=" or predicate == "pany" or
			predicate == "not" then
			process_spec(spec[3])
			process_spec(spec[4])
		elseif predicate == "and" or predicate == "or" then
			process_spec(spec[3])
			process_spec(spec[4])
		elseif predicate == "call" then
			return
		else
			error("Unrecognized predicate: " .. predicate)
		end
	end

	for _, spec in ipairs(catstruct) do
		process_spec(spec)
	end
	return cats, labels
end


local function construct_category_table(cats)
	local category_parts = {}
	local function ins(text)
		table.insert(category_parts, text)
	end
	ins('{|class="wikitable"')
	ins("! Category")
	for _, cat in ipairs(cats) do
		ins("|-")
		ins("| <code>" .. cat .. "</code>")
	end
	ins("|}")
	return table.concat(category_parts, "\n")
end


local function construct_label_table(labels, lang, replace_und)
	local label_parts = {}
	local function ins(text)
		table.insert(label_parts, text)
	end
	ins('{|class="wikitable"')
	ins("! Label !! Display form !! Associated categories")
	for _, label in ipairs(labels) do
		ins("|-")
		local label_data = require(labels_module).get_label_info {
			label = label,
			lang = lang,
			already_seen = {},
		}
		local coded_categories = {}
		for _, cat in ipairs(label_data.categories) do
			if replace_und then
				cat = cat:gsub("^und:", "LANGCODE:")
				cat = cat:gsub("^Undetermined ", "LANG ")
			end
			table.insert(coded_categories, "<code>" .. cat .. "</code>")
		end
		ins(("| <code>%s</code> || %s || %s"):format(label, label_data.label,
			table.concat(coded_categories, ",")))
	end
	ins("|}")
	return table.concat(label_parts, "\n")
end


function export.lang_specific_tables()
	local m_cats = mw.loadData(m_form_of.form_of_cats_module)
	local parts = {}

	local function ins(text)
		table.insert(parts, text)
	end

	local data_by_lang = {}

	local langs_with_lang_specific_data = mw.clone(m_form_of.langs_with_lang_specific_tags)
	for langcode, _ in pairs(m_cats) do
		if langcode ~= "und" then
			langs_with_lang_specific_data[langcode] = true
		end
	end

	for langcode, _ in pairs(langs_with_lang_specific_data) do
		local lang = m_languages.getByCode(langcode, true)
		local data_module_name = m_form_of.form_of_lang_data_module_prefix .. langcode
		local data_module = m_form_of.langs_with_lang_specific_tags[langcode] and mw.loadData(data_module_name) or nil

		-- First do base-lemma params.
		local base_lemma_param_table
		-- Can't just call #data_module.base_lemma_params as this comes from loadData().
		if data_module and data_module.base_lemma_params and data_module.base_lemma_params[1] then
			local base_lemma_param_parts = {}
			local function ins(text)
				table.insert(base_lemma_param_parts, text)
			end
			ins('{|class="wikitable"')
			ins("! Parameter !! Display form")
			for _, base_lemma_param in ipairs(data_module.base_lemma_params) do
				ins("|-")
				ins(("| <code>%s</code> || %s"):format(base_lemma_param.param,
					get_display_form(base_lemma_param.tags, lang)))
			end
			ins("|}")
			base_lemma_param_table = table.concat(base_lemma_param_parts, "\n")
		end


		-- Then do inflection tags.
		local data_tab = data_module and organize_tag_data(data_module) or {}
		local tag_parts = {}
		local function ins(text)
			table.insert(tag_parts, text)
		end
		ins('{|class="wikitable"')
		ins("! Canonical tag !! Shortcut(s) !! Tag type !! Display form")
		local saw_any_tag = false
		for _, tag_type in ipairs(tag_type_order) do
			local group_tab = data_tab[tag_type]
			if group_tab then
				for _, namedata in ipairs(group_tab) do
					local sparts = {}
					local name, data = unpack(namedata)
					table.insert(sparts, "| <code>" .. name .. "</code> || ")
					if data.shortcuts then
						local ssparts = {}
						for _, shortcut in ipairs(data.shortcuts) do
							table.insert(ssparts, "<code>" .. shortcut .. "</code>")
						end
						table.insert(sparts, table.concat(ssparts, ", ") .. " ")
					end
					table.insert(sparts, "|| " .. tag_type_desc(tag_type) .. " || " ..
						m_form_of.get_tag_display_form(name, lang))
					ins("|-")
					ins(table.concat(sparts))
					saw_any_tag = true
				end
			end
		end
		ins("|}")

		local tag_table = saw_any_tag and table.concat(tag_parts, "\n") or nil

		-- Then do non-alias shortcuts.
		local non_alias_shortcut_table
		local non_alias_shortcuts = data_module and organize_non_alias_shortcut_data(data_module, lang) or {}
		if #non_alias_shortcuts > 0 then
			local non_alias_shortcut_parts = {}
			local function ins(text)
				table.insert(non_alias_shortcut_parts, text)
			end
			ins('{|class="wikitable"')
			ins("! Shortcut !! Expansion !! Display form")
			for _, spec in ipairs(non_alias_shortcuts) do
				local shortcut, full, display = unpack(spec)
				ins("|-")
				if type(full) == "table" then
					-- Grrr. table.concat() doesn't work on a table that comes from loadData(); use shallowcopy() to
					-- convert to regular table.
					full = "{" .. table.concat(m_table.shallowcopy(full), " ") .. "}"
				end
				ins(("| <code>%s</code> || <code>%s</code> || %s"):format(shortcut, full, display))
			end
			ins("|}")
			non_alias_shortcut_table = table.concat(non_alias_shortcut_parts, "\n")
		end

		-- Then do categories and labels.
		local category_table, label_table
		if m_cats[langcode] then
			local cats, labels = find_categories_and_labels(m_cats[langcode])
			if #cats > 0 then
				category_table = construct_category_table(cats)
			end
			if #labels > 0 then
				label_table = construct_label_table(labels, lang)
			end
		end

		-- Concatenate all the tables together, with appropriate explanatory text.
		if base_lemma_param_table or tag_table or non_alias_shortcut_table or category_table or label_table then
			local langname = lang:getCanonicalName()
			local lang_parts = {}
			local function ins(text)
				table.insert(lang_parts, text)
			end
			ins("===" .. langname .. "===")
			ins(show_editlink(data_module_name))
			if base_lemma_param_table then
				ins(("%s-specific base lemma parameters:"):format(langname))
				ins(base_lemma_param_table)
			end
			if tag_table then
				ins(("%s-specific inflection tags:"):format(langname))
				ins(tag_table)
			end
			if non_alias_shortcut_table then
				ins(("%s-specific non-alias shortcuts:"):format(langname))
				ins(non_alias_shortcut_table)
			end
			if category_table then
				ins(("%s-specific categories (the exact conditions under which these are added are described in [[Module:form of/cats]]):"):
					format(langname))
				ins(category_table)
			end
			if label_table then
				ins(("%s-specific labels (the exact conditions under which these are added are described in [[Module:form of/cats]]):"):
					format(langname))
				ins(label_table)
			end
			table.insert(data_by_lang, {langname, table.concat(lang_parts, "\n")})
		end
	end

	local function sort_by_first_english_first(langdata1, langdata2)
		if langdata1[1] == "English" then
			-- English is "less than" (goes before) all other languages
			return true
		elseif langdata2[1] == "English" then
			-- All other languages are not "less than" (do not go before) English
			return false
		else
			return langdata1[1] < langdata2[1]
		end
	end

	table.sort(data_by_lang, sort_by_first_english_first)

	local parts = {}
	for _, lang_and_data in ipairs(data_by_lang) do
		table.insert(parts, lang_and_data[2])
	end
	return table.concat(parts, "\n")
end


function export.postable()
	m_pos = mw.loadData(m_form_of.form_of_pos_module)
	local shortcut_tab = {}
	for shortcut, full in pairs(m_pos) do
		if not shortcut_tab[full] then
			shortcut_tab[full] = {}
		end
		table.insert(shortcut_tab[full], shortcut)
	end
	local shorcut_list = {}
	for full, shortcuts in pairs(shortcut_tab) do
		table.sort(shortcuts)
		table.insert(shorcut_list, {full, shortcuts})
	end
	table.sort(shorcut_list, function(fs1, fs2) return fs1[1] < fs2[1] end)

	local parts = {}
	table.insert(parts, '{|class="wikitable"')
	table.insert(parts, "! Canonical part of speech !! Shortcut(s)")
	for _, full_shortcuts in ipairs(shorcut_list) do
		local full = full_shortcuts[1]
		local shortcuts = full_shortcuts[2]
		table.insert(parts, "|-")
		local sparts = {}
		for _, shortcut in ipairs(shortcuts) do
			table.insert(sparts, "<code>" .. shortcut .. "</code>")
		end
		table.insert(parts, "| <code>" .. full .. "</code> || " .. table.concat(sparts, ", "))
	end
	table.insert(parts, "|}")
	return table.concat(parts, "\n")
end


function export.lang_independent_category_table()
	local m_cats = mw.loadData(m_form_of.form_of_cats_module)
	if m_cats["und"] then
		local cats, labels = find_categories_and_labels(m_cats["und"])
		if #cats > 0 then
			return construct_category_table(cats)
		end
	end
	return "(no language-independent categories currently)"
end


function export.lang_independent_label_table()
	local m_cats = mw.loadData(m_form_of.form_of_cats_module)
	if m_cats["und"] then
		local cats, labels = find_categories_and_labels(m_cats["und"])
		if #labels > 0 then
			return construct_label_table(labels, m_languages.getByCode("und", true), "replace und")
		end
	end
	return "(no language-independent labels currently)"
end


return export

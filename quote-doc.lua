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

local rfind = mw.ustring.find
local rsplit = mw.text.split
local rsubn = mw.ustring.gsub


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
	  useand = true} displays as "|chapter_series=/<u>|entry_series=</u> and |chapter_seriesvolume=/<u>|entry_seriesvolume=</u>",
	 referring to alias sets of logically related parameters, some of which are non-generic (in this case, the
	 {{para|entry_*}} params are {{tl|quote-book}}-specific aliases).

   Other named fields are possible:
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

local function generate_params(ty)
	return {
	{"Date-related parameters",
	{"date", [=[The date that the <<work>> was published. Use either {{para|year}} (and optionally {{para|month}}), or
	{{para|date}}, not both. The value of {{para|date}} must be an actual date, with or without the day, rather than
	arbitrary text. Various formats are allowed; it is recommended that you either write in YYYY-MM-DD format, e.g.
	<code>2023-08-11</code>, or spell out the month, e.g. <code>2023 August 11</code> (permutations of the latter are
	allowed, such as <code>August 11 2023</code> or <code>11 August 2023</code>). You can omit the day and the code
	will attempt to display the date with only the month and year. Regardless of the input format, the output will be
	displayed in the format <code>'''2023''' August 11</code>, or <code>'''2023''' August</code> if the day was
	omitted.]=]},
	{{"year", "month", useand = true}, [=[The year and (optionally) the month that the <<work>> was published. The values
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
	{{"nodate", boolean = true}, [=[Specify {{para|nodate|1}} if the <<work>> is undated and no date (even approximate) can
	reasonably be determined. This suppresses the maintenance line that is normally displayed if no date is given. Do
	not use this just because you don't know the date; instead, leave out the date and let the maintenance line be
	displayed and the page be added to the appropriate maintenance category, so that someone else can help.]=],},
	},

	{"Author-related parameters",
	{{"author", list = true}, [=[The name(s) of the author(s) of the <<work>> quoted. Separate multiple authors with
	semicolons, or use the additional parameters {{para|author2}}, {{para|author3}}, etc. Alternatively, use
	{{para|last}} and {{para|first}} (for the first name, and middle names or initials), along with
	{{para|last2}}/{{para|first2}} for additional authors. Do not use both at once.]=]},
	{{"last", "first", useand = true, list = true}, [=[The first (plus middle names or initials) and last name(s) of
	the author(s) of the <<work>> quoted. Use {{para|last2}}/{{para|first2}}, {{para|last3}}/{{para|first3}}, etc. for
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
	{"coauthors", "The names of the coauthor(s) of the <<work>>. Separate multiple names with semicolons."},
	{"mainauthor", [=[If you wish to indicate who a part of <<work:a>> such as a foreword or introduction was written by,
	use {{para|author}} to do so, and use {{para|mainauthor}} to indicate the author(s) of the main part of the <<work>>.
	Separate multiple authors with semicolons.]=]},
	{{"tlr", "translator", "translators"}, [=[The name(s) of the translator(s) of the <<collection>>. Separate multiple names
	with semicolons.]=]},
	{{"editor", "editors"}, [=[The name(s) of the editor(s) of the <<collection>>. Separate multiple names with semicolons.]=],},
	{"quotee", [=[The name of the person being quoted, if the whole text quoted is a quotation of someone other than
	the author.]=]},
	},

	{"Title-related parameters",
	{{"title", required = true}, [=[The title of the <<collection>>.]=]},
	{"trans-title", [=[If the title of the <<collection>> is not in English, this parameter can be used to provide an English
	translation of the title, as an alternative to specifying the translation using an inline modifier (see below).]=]},
	{{"series", "seriesvolume", useand = true}, [=[The {{w|book series|series}} that the <<collection>> belongs to, and the
	volume number of the <<collection>> within the series.]=]},
	{"url", [=[The URL or web address of an external website containing the full text of the <<work>>. ''Do not link to
	any website that has content in breach of copyright''.]=]},
	{"urls", [=[Freeform text, intended for multiple URLs. Unlike {{para|url}}, the editor must supply the URL brackets
	<code>[]</code>.]=]},
	},

	{"Chapter-related parameters",
	{"chapter", [=[The chapter of the <<collection>> quoted. You can either specify a chapter number in Arabic or Roman
	numerals (for example, {{para|chapter|7}} or {{para|chapter|VII}}) or a chapter title (for example,
	{{para|chapter|Introduction}}). A chapter given in Arabic or Roman numerals will be preceded by the word "chapter",
	while a chapter title will be enclosed in “curly quotation marks”.]=]},
	{"chapter_number", [=[If the name of the chapter was supplied in {{para|chapter}}, use {{para|chapter_number}} to
	provide the corresponding chapter number, which will be shown in parentheses after the word "chapter", e.g.
	<code>“Experiments” (chapter 4)</code>.]=]},
	{"chapter_plain", [=[The full value of the chapter, which will be displayed as-is. Include the word "chapter" and
	any desired quotation marks. If both {{para|chapter}} and {{para|chapter_plain}} are given, the value of
	{{para|chapter_plain}} is shown after the chapter, in parentheses. This is useful if chapters in this <<collection>>
	have are given a term other than "chapter".]=]},
	{"chapterurl", [=[The [[w:Universal Resource Locator|URL]] or web address of an external webpage to link to the
	chapter. Note that it is generally preferred to use {{para|pageurl}} to link directly to the page of the quoted
	text, if possible. ''Do not link to any website that has content in breach of [[w:copyright|copyright]]''.]=]},
	{"trans-chapter", [=[If the chapter of the <<collection>> is not in English, this parameter can be used to provide an
	English translation of the chapter title, as an alternative to specifying the translation using an inline modifier
	(see below).]=]},
	{"chapter_tlr", [=[The translator of the chapter, if separate from the overall translator of the <<collection>>
	(specified using {{para|tlr}} or {{para|translator}}).]=]},
	{{"chapter_series", "chapter_seriesvolume", useand = true}, [=[If this chapter is part of a series of similar
	chapters, {{para|chapter_series}} can be used to specify the name of the series, and {{para|chapter_seriesvolume}}
	can be used to specify the index of the series, if it exists. Compare the {{para|series}} and {{para|seriesvolume}}
	parameters for the <<collection>> as a whole. These parameters are used especially in conjunction with recurring
	columns in a newspaper or similar. In {{tl|quote-journal}}, the {{para|chapter}} parameter is called {{para|title}}
	and is used to specify the name of a journal, magazine or newspaper article, and the {{para|chapter_series}}
	parameter is called {{para|article_series}} and is used to specify the name of the column or article series that the
	article is part of.]=]},
	},

	{"Section-related parameters",
	{"section", [=[Use this parameter to identify a (usually numbered) portion of <<work:a>>, as an alternative or
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
	{"trans-section", [=[If the section of the <<work>> is not in English, this parameter can be used to provide an English
	translation of the section, as an alternative to specifying the translation using an inline modifier (see
	below).]=]},
	{{"section_series", "section_seriesvolume", useand = true}, [=[If this section is part of a series of similar
	sections, {{para|section_series}} can be used to specify the name of the series, and {{para|section_seriesvolume}}
	can be used to specify the index of the series, if it exists. Compare the {{para|series}} and {{para|seriesvolume}}
	parameters for the <<collection>> as a whole, and the {{para|chapter_series}} and {{para|chapter_seriesvolume}} parameters
	for a chapter.]=]},
	},

	{"Page- and line-related parameters",
	{{"page", "pages"}, [=[The page number or range of page numbers of the <<work>>. Use an en dash (–) to separate the
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
	{"pageurl", [=[The URL or web address of the webpage containing the page(s) of the <<work>> referred to. The page
	number(s) will be linked to this webpage.]=]},
	{{"line", "lines"}, [=[The line number(s) of the quoted text, e.g. <code>47</code> or <code>151–154</code>. These
	parameters work identically to {{para|page}} and {{para|pages}}, respectively. Line numbers are often used in
	plays, poems and certain technical works.]=]},
	{"line_plain", [=[Free text specifying the line number(s) of the quoted text, e.g. <code>verses 44–45</code> or
	<code>footnote 3</code>. Use only one of {{para|line}}, {{para|lines}} and {{para|line_plain}}.]=]},
	{"lineurl", [=[The URL or web address of the webpage containing the line(s) of the <<work>> referred to. The line
	number(s) will be linked to this webpage.]=]},
	{{"column", "columns", "column_plain", "columnurl", useand = true}, [=[The column number(s) of the quoted text.
	These parameters <<work>> identically to {{para|page}}, {{para|pages}}, {{para|page_plain}} and {{para|pageurl}},
	respectively.]=]},
	},

	{"Publication-related parameters",
	{"publisher", [=[The name of one or more publishers of the <<collection>>. If more than one publisher is stated, separate the
	names with semicolons.]=]},
	{"location", [=[The location where the <<collection>> was published. If more than one location is stated, separate the
	locations with semicolons, like this: <code>London; New York, N.Y.</code>.]=]},
	{"edition", [=[The edition of the <<collection>> quoted, for example, <code>2nd</code> or <code>3rd corrected and revised</code>.
	This text will be followed by the word "edition" (use {{para|edition_plain}} to avoid this). If quoting from the
	first edition of the <<collection>>, it is usually not necessary to specify this fact.]=]},
	{"edition_plain", [=[Free text specifying the edition of the <<collection>> quoted, e.g. <code>3rd printing</code> or
	<code>5th edition, digitized</code> or <code>version 3.72</code>.]=]},
	{{"year_published", "month_published", useand = true}, [=[If {{para|year}} is used to state the year when the
	original version of the <<issue>> was published, {{para|year_published}} can be used to state the year in which the
	version quoted from was published, for example, "<code>|year=1665|year_published=2005</code>".
	{{para|month_published}} can optionally be used to specify the month of publication. The year published is preceded
	by the word "published". These parameters are handled in an identical fashion to {{para|year}} and {{para|month}}
	(except that the year isn't displayed boldface by default). This means, for example, that the prefixes
	<code>c.</code>, <code>a.</code> and <code>p.</code> are recognized to specify that the publication happened
	circa/before/after a specified date.]=]},
	{"date_published", [=[The date that the version of the <<issue>> quoted from was published. Use either
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
	{{"origyear", "origmonth", useand = true}, [=[The year when the <<work>> was originally published, if the <<work>> quoted
	from is a new version of <<work:a>> (not merely a new printing). For example, if quoting from a modern edition of
	Shakespeare or Milton, put the date of the modern edition in {{para|year}}/{{para|month}} or {{para|date}} and the
	date of the original edition in {{para|origyear}}/{{para|origmonth}} or {{para|origdate}}. {{para|origmonth}} can
	optionally be used to supply the original month of publication, or a full date can be given using {{para|origdate}}.
	Use either {{para|origyear}}/{{para|origmonth}} or {{para|origdate}}, not both. These parameters are handled in an
	identical fashion to {{para|year}} and {{para|month}} (except that the year isn't displayed boldface by default).
	This means, for example, that the prefixes <code>c.</code>, <code>a.</code> and <code>p.</code> are recognized to
	specify that the original publication happened circa/before/after a specified date.]=]},
	{"origdate", [=[The date that the original version of the <<work>> quoted from was published. Use either
	{{para|origyear}} (and optionally {{para|origmonth}}), or {{para|origdate}}, not both. As with {{para|date}}, the
	value of {{para|origdate}} must be an actual date, with or without the day, rather than arbitrary text. The same
	formats are recognized as for {{para|date}}.]=]},
	{{"origstart_year", "origstart_month", "origstart_date", useand = true}, [=[The start year/month or date of the
	original version of publication, if the publication happened over a range.  Use either {{para|origstart_year}} (and
	optionally {{para|origstart_month}}), or {{para|origstart_date}}, not both. These <<work>> just like
	{{para|start_year}}, {{para|start_month}} and {{para|start_date}}, and very rarely need to be specified.]=]},
	{"platform", [=[The platform on which the <<work>> has been published. This is intended for content aggregation
	platforms such as {{w|YouTube}}, {{w|Issuu}} and {{w|Magzter}}. This displays as "via PLATFORM".]=]},
	{"source", [=[The source of the content of the <<work>>. This is intended e.g. for news agencies such as the
	{{w|Associated Press}}, {{w|Reuters}} and {{w|Agence France-Presse}} (AFP) (and is named {{para|newsagency}} in
	{{tl|quote-journal}} for this reason). This displays as "sourced from SOURCE".]=]},
	},

	{"Volume-related parameters",
	{{"volume", "volumes"}, [=[The volume number(s) of the <<collection>>. This displays as "volume VOLUME", or "volumes VOLUMES"
	if a range of numbers is given. Whether to display "volume" or "volumes" is autodetected, exactly as for
	{{para|page}} and {{para|pages}}; use <code>!</code> at the beginning of the value to suppress this and respect the
	parameter name. Use {{para|volume_plain}} if you wish to suppress the word "volume" appearing in front of the volume
	number.]=]},
	{"volume_plain", [=[Free text specifying the volume number(s) of the <<collection>>, e.g. <code>book II</code>. Use only one
	of {{para|volume}}, {{para|volumes}} and {{para|volume_plain}}.]=]},
	{"volumeurl", [=[The URL or web address of the webpage corresponding to the volume containing the quoted text, if
	the <<collection>> has multiple volumes with different URL's. The volume number(s) will be linked to this webpage.]=]},
	{{{"issue", "number"}, {"issues", "numbers"}, {"issue_plain", "number_plain"}, {"issueurl", "numberurl"}, useand = true},
	[=[The issue number(s) of the quoted text. These parameters work identically to {{para|page}}, {{para|pages}},
	{{para|page_plain}} and {{para|pageurl}}, respectively, except that the displayed text contains the term "number"
	or "numbers" rather than "issue" or "issues", as might be expected. Examples of the use of {{para|issue_plain}} are
	<code>book 2</code> (if the <<collection>> is divided into volumes and volumes are divided into books) or
	<code>Sonderheft 1</code> (where ''Sonderheft'' means "special issue" in German).]=]},
	},

	{"ID-related parameters",
	{{"doi", "DOI"}, [=[The [[w:Digital object identifier|digital object identifier]] (DOI) of the <<work>>.]=]},
	{{"isbn", "ISBN"}, [=[The [[w:International Standard Book Number|International Standard Book Number]] (ISBN) of
	the <<collection>>. 13-digit ISBN's are preferred over 10-digit ones.]=]},
	{{"issn", "ISSN"}, [=[w:International Standard Serial Number|International Standard Serial Number]] (ISSN) of the
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
	{"format", [=[The format that the <<work>> is in, for example, "<code>hardcover</code>" or "<code>paperback</code>" for
	a book or "<code>blog</code>" for a web page.]=]},
	{"genre", [=[The {{w|literary genre}} of the <<work>>, for example, "<code>fiction</code>" or
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

	Use {{para|worklang}} to specify the language(s) that the <<collection>> itself is written in: see below.

	<small>The parameter {{para|lang}} is a deprecated synonym for this parameter; please do not use. If this is used,
	all numbered parameters move down by one.</small>]=]},
	{{"text", "passage"}, [=[The text being quoted. Use boldface to highlight the term being defined, like this:
	"{{code||<nowiki>'''humanities'''</nowiki>}}".]=]},
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

	{"New version of <<work:a>>",
	[=[The following parameters can be used to indicate a new version of the <<work>>, such as a reprint, a new edition, or
	some other republished version. The general means of doing this is as follows:
	# Specify {{para|newversion|republished as}}, {{para|newversion|translated as}}, {{para|newversion|quoted in}} or
	similar to indicate what the new version is. (Under some circumstances, this parameter can be omitted; see below.)
	# Specify the author(s) of the new version using {{para|2ndauthor}} (separating multiple authors with a semicolon)
	or {{para|2ndlast}}/{{para|2ndfirst}}.
	# Specify the remaining properties of the new version by appending a <code>2</code> to the parameters as specified
	above, e.g. {{para|title2}} for the title of the new version, {{para|page2}} for the page number of the new
	version, etc.

	Some special-case parameters are supplied as an alternative to specifying a new version this way. For example, the
	{{para|original}} and {{para|by}} parameters can be used when quoting a translated version of <<work:a>>; see
	below.]=],
	{"newversion", [=[The template assumes that a new version of the <<work>> is referred to if {{para|newversion}} or
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
	listed above can be applied to a new version of the <<work>> by adding "<code>2</code>" after the parameter name. It is
	recommended that at a minimum the imprint information of the new version of the <<work>> should be provided using
	{{para|location2}}, {{para|publisher2}}, and {{para|date2}} or {{para|year2}}.]=]},
	},

	{"Alternative special-case ways of specifying a new version of <<work:a>>",
	[=[The following parameters provide alternative ways of specifying new version of <<work:a>>, such as a reprint or
	translation, or a case where part of one <<work>> is quoted in another. If you find that these parameters are
	insufficient for specifying all the information about both works, do not try to shoehorn the extra information in.
	Instead, use the method described above using {{para|newversion}} and {{para|2ndauthor}}, {{para|title2}}, etc.]=],
	{{"type", "original", "by", useand = true}, [=[If you are citing a {{w|derivative work}} such as a translation, use
	{{para|type}} to state the type of derivative work, {{para|original}} to state the title of the original work, and
	{{para|by}} to state the author of the original work. If {{para|type}} is not indicated, the template assumes that
	the derivative work is a translation.]=]},
	{"quoted_in", [=[If the quoted text is from book A which states that the text is from another book B, do the
	following:
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
	alternative to specifying the translation using an inline modifier (see below).]=]},
	{"chapterurl", addalias = "entryurl", replace_desc = [=[The [[w:Universal Resource Locator|URL]] or web address of
	an external webpage to link to the chapter or entry name. For example, if the book has no page numbers, the webpage
	can be linked to the chapter or entry name using this parameter. ''Do not link to any website that has content in
	breach of [[w:copyright|copyright]]''.]=]},
	},

	["quote-journal"] = {
	{"#substitute", work = "article", collection = "journal", issue = "journal issue"},
	{"year", addalias = "2"},
	{"author", addalias = "3"},
	{"title", addalias = "5"},
	{"url", addalias = "6"},
	{"page", addalias = "7"},
	{"text", addalias = "8"},
	{"translation", addalias = "9"},
	{"#replace_group", "Chapter-related parameters", {"Article-related parameters",
		{{"title", "4"}, [=[The title of the journal article quoted, which will be enclosed in “curly quotation marks”.]=]},
		{"title_plain", [=[The title of the article, which will be displayed as-is. Include any desired quotation marks
		and other words. If both {{para|title}} and {{para|title_plain}} are given, the value of {{para|title_plain}}
		is shown after the title, in parentheses. This is useful e.g. to indicate an article number or other
		identifier.]=]},
		{"titleurl", [=[The [[w:Universal Resource Locator|URL]] or web address of an external webpage to link to the
		article. Note that it is generally preferred to use {{para|pageurl}} to link directly to the page of the quoted
		text, if possible. ''Do not link to any website that has content in breach of [[w:copyright|copyright]]''.]=]},
		{"trans-title", [=[If the journal article is not in English, this parameter can be used to provide an English
		translation of the title, as an alternative to specifying the translation using an inline modifier (see
		below).]=]},
		{"article_tlr", [=[The translator of the article, if separate from the overall translator of the journal
		(specified using {{para|tlr}} or {{para|translator}}).]=]},
		{{"article_series", "article_seriesvolume", useand = true}, [=[If this article is part of a series of similar
		articles, {{para|article_series}} can be used to specify the name of the series, and
		{{para|article_seriesvolume}} can be used to specify the index of the series, if it exists. Compare the
		{{para|series}} and {{para|seriesvolume}} parameters for the journal as a whole. These parameters can be used,
		for example, for recurring columns in a newspaper.]=]},
		}
	},
	},
}


local function canonicalize_param_group(group)
	local ind = 2
	if type(group[2]) == "string" then
		ind = ind + 1
	end

	for i = ind, #group do
		-- Canonicalize the parameter spec to the maximally-expressed form for easier processing.
		local paramspec, desc = unpack(group[i])
		-- Canonicalize a top-level string param to a list.
		if type(paramspec) == "string" then
			paramspec = {paramspec}
			group[i][1] = paramspec
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
					paramset[k] = param
				end
			end
		end
	end
end


-- Apply the modifications specified in `mods` to the parameters in `params`.
local function apply_mods(params, mods)
	local mod_table = {}
	local subvals
	-- First, convert the modifications to a dictionary for easy lookup as we traverse the existing parameters.
	for _, mod in ipairs(mods) do
		local param = mod[1]
		mod[1] = nil
		if param == "#substitute" then
			subvals = mod
		elseif param == "#replace_group" then
			local _, existing_group_name, new_group = unpack(mod)
			canonicalize_param_group(new_group)

			local ind = 2
			if type(new_group[2]) == "string" then
				ind = ind + 1
			end

			for i = ind, #new_group do
				local paramspec, desc = unpack(group[i])
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
		else
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
							local to_add = mod.addalias
							-- Canonicalize an addalias= spec to a list for easier processing.
							if type(to_add) ~= "table" or to_add.param then
								to_add = {to_add}
							end
							for _, ta in ipairs(to_add) do
								-- Canonicalize.
								if type(ta) == "string" then
									ta = {param = ta}
								end
								if ta.non_generic == nil then
									ta.non_generic = true
								end
								if paramspec.useand then
									-- Top level refers to logically-related params so alias goes at second level.
									table.insert(paramspec[j], ta)
								else
									table.insert(paramspec, {ta})
								end
							end
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

	return subvals
end


-- Format a param spec as found in the first element of a param description.
local function format_param_spec(paramspec)
	if type(paramspec) ~= "table" or paramspec.param then
		paramspec = {paramspec}
	end

	local function format_one_param(param, non_generic)
		if non_generic then
			param = "<u>" .. param .. "</u>"
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
	-- Join continuation lines. Do it twice in case of a single-character line (admittedly rare).
	desc = rsub(desc, "([^\n])\n[ \t]*([^ \t\n#*])", "%1 %2")
	desc = rsub(desc, "([^\n])\n[ \t]*([^ \t\n#*])", "%1 %2")
	-- Remove whitespace before list elements.
	desc = rsub(desc, "\n[ \t]*([#*])", "\n%1")
	desc = rsub(desc, "^[ \t]*([#*])", "%1")
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
	return preprocess(desc)
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

	local parts = {}
	for _, group in ipairs(params) do
		table.insert(parts, format_parameter_group(group, subvals, 3))
	end
	return table.concat(parts, "\n\n")
end


return export

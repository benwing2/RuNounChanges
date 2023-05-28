local labels = {}
local raw_categories = {}
local raw_handlers = {}


-----------------------------------------------------------------------------
--                                                                         --
--                                  LABELS                                 --
--                                                                         --
-----------------------------------------------------------------------------


labels["entry maintenance"] = {
	description = "{{{langname}}} entries, or entries in other languages containing {{{langname}}} terms, that are being tracked for attention and improvement by editors.",
	parents = {{name = "{{{langcat}}}", raw = true}},
	umbrella_parents = "Fundamental",
}

labels["entries without References header"] = {
	description = "{{{langname}}} entries without a References header.",
	parents = {"entry maintenance"},
	can_be_empty = true,
	hidden = true,
}

labels["entries without References or Further reading header"] = {
	description = "{{{langname}}} entries without a References or Further reading header.",
	parents = {"entry maintenance"},
	can_be_empty = true,
	hidden = true,
}

labels["entries with outdated source"] = {
	description = "{{{langname}}} entries that have been partly or fully imported from an outdated source.",
	parents = {"entry maintenance"},
}

labels["entries that don't exist"] = {
	description = "{{{langname}}} terms that do not meet the [[Wiktionary:Criteria for inclusion|criteria for inclusion]] (CFI). They are added to the category with the template {{temp|no entry|{{{langcode}}}}}.",
	parents = {"entry maintenance"},
}

labels["undefined derivations"] = {
	description = "{{{langname}}} etymologies using {{tl|undefined derivation}}, where a more specific template such as {{tl|borrowed}} or {{tl|inherited}} should be used instead.",
	parents = {"entry maintenance"},
	can_be_empty = true,
	hidden = true,
}

labels["descendants to be fixed in desctree"] = {
	description = "Entries that use {{tl|desctree}} to link to {{{langname}}} entries with no Descendants section.",
	parents = {"entry maintenance"},
	can_be_empty = true,
	hidden = true,
}

labels["term requests"] = {
	description = "Entries with [[Template:der]], [[Template:inh]], [[Template:m]] and similar templates lacking the parameter for linking to {{{langname}}} terms.",
	parents = {"entry maintenance"},
	can_be_empty = true,
	hidden = true,
}

labels["redlinks"] = {
	description = "Links to {{{langname}}} entries that have not been created yet.",
	parents = {"entry maintenance"},
	catfix = false,
	can_be_empty = true,
	hidden = true,
}

labels["terms with IPA pronunciation"] = {
	description = "{{{langname}}} terms that include the pronunciation in the form of IPA. For requests related to this category, see [[:Category:Requests for pronunciation in {{{langname}}} entries]].",
	parents = {"entry maintenance"},
}

labels["terms with hyphenation"] = {
	description = "{{{langname}}} terms that include hyphenation.",
	parents = {"entry maintenance"},
}

labels["terms with audio links"] = {
	description = "{{{langname}}} terms that include the pronunciation in the form of an audio link.",
	parents = {"entry maintenance"},
}

labels["descendant hubs"] = {
	description = "{{{langname}}} terms that do not mean more than the sum of their parts but exist for listing two or more inclusion-worthy descendants.",
	parents = {"entry maintenance"},
}

labels["terms needing to be assigned to a sense"] = {
	description = "{{{langname}}} entries that have terms under headers such as \"Synonyms\" or \"Antonyms\" not assigned to a specific sense of the entry in which they appear. Use [[Template:syn]] or [[Template:ant]] to fix these.",
	parents = {"entry maintenance"},
	can_be_empty = true,
	hidden = true,
}

--[=[
labels["terms with inflection tables"] = {
	description = "{{{langname}}} entries that contain inflection tables. For requests related to this category, see [[:Category:Requests for inflections in {{{langname}}} entries]].",
	parents = {"entry maintenance"},
}
]=]

labels["terms with collocations"] = {
	description = "{{{langname}}} entries that contain [[collocation]]s that were added using templates such as [[Template:co]]. For requests related to this category, see [[:Category:Requests for collocations in {{{langname}}}]]. See also [[:Category:Requests for quotations in {{{langname}}}]] and [[:Category:Requests for example sentences in {{{langname}}}]].",
	parents = {"entry maintenance"},
}

labels["terms with usage examples"] = {
	description = "{{{langname}}} entries that contain usage examples that were added using templates such as [[Template:ux]]. For requests related to this category, see [[:Category:Requests for example sentences in {{{langname}}}]]. See also [[:Category:Requests for collocations in {{{langname}}}]] and [[:Category:Requests for quotations in {{{langname}}}]].",
	parents = {"entry maintenance"},
}

labels["terms with quotations"] = {
	description = "{{{langname}}} entries that contain quotes that were added using templates such as [[Template:quote]], [[Template:quote-book]], [[Template:quote-journal]], etc. For requests related to this category, see [[:Category:Requests for quotations in {{{langname}}}]]. See also [[:Category:Requests for collocations in {{{langname}}}]] and [[:Category:Requests for example sentences in {{{langname}}}]].",
	parents = {"entry maintenance"},
}

labels["terms with redundant head parameter"] = {
	description = "{{{langname}}} terms that contain a redundant head= parameter in their headword (called using {{tl|head}} or a language-specific equivalent).",
	additional = "Individual languages can prevent terms from being added to this category by setting `data.no_redundant_head_cat`.",
	parents = {"entry maintenance"},
	can_be_empty = true,
	hidden = true,
}

labels["terms with red links in their headword lines"] = {
	description = "{{{langname}}} terms that contain red links (i.e. uncreated forms) in their headword lines.",
	parents = {"redlinks"},
	can_be_empty = true,
	hidden = true,
}

labels["terms with red links in their inflection tables"] = {
	description = "{{{langname}}} terms that contain red links (i.e. uncreated forms) in their inflection tables.",
	parents = {"redlinks"},
	can_be_empty = true,
	hidden = true,
}

labels["requests for English equivalent term"] = {
	description = "{{{langname}}} entries with definitions that have been tagged with {{tl|rfeq}}. Read the documentation of the template for more information.",
	parents = {"entry maintenance"},
	can_be_empty = true,
	hidden = true,
}

for _, pos in ipairs({"nouns", "proper nouns", "verbs", "adjectives", "adverbs", "participles", "determiners", "pronouns", "numerals", "suffixes", "contractions"}) do
	labels[pos .. " with red links in their headword lines"] = {
		description = "{{{langname}}} " .. pos .. " that contain red links (i.e. uncreated forms) in their headword lines.",
		parents = {"terms with red links in their headword lines"},
		breadcrumb = pos,
		can_be_empty = true,
		hidden = true,
	}

	labels[pos .. " with red links in their inflection tables"] = {
		description = "{{{langname}}} " .. pos .. " that contain red links (i.e. uncreated forms) in their inflection tables.",
		parents = {"terms with red links in their inflection tables"},
		breadcrumb = pos,
		can_be_empty = true,
		hidden = true,
	}
end


-- Add 'umbrella_parents' key if not already present.
for key, data in pairs(labels) do
	if not data.umbrella_parents then
		data.umbrella_parents = "Entry maintenance subcategories by language"
	end
end





-----------------------------------------------------------------------------
--                                                                         --
--                              RAW CATEGORIES                             --
--                                                                         --
-----------------------------------------------------------------------------


raw_categories["Entry maintenance subcategories by language"] = {
	description = "Umbrella categories covering topics related to entry maintenance.",
	additional = "{{{umbrella_meta_msg}}}",
	parents = {
		"Umbrella metacategories",
		{name = "entry maintenance", is_label = true, sort = " "},
	},
}

raw_categories["Requests"] = {
	intro = "{{shortcut|WT:CR|WT:RQ}}",
	description = "A parent category for the various request categories.",
	parents = {"Category:Wiktionary"},
}

raw_categories["Requests by language"] = {
	description = "Categories with requests in various specific languages.",
	additional = "{{{umbrella_msg}}}",
	parents = {
		{name = "Request subcategories by language", sort = " "},
		{name = "Requests", sort = " "},
	},
	breadcrumb = "By language",
}

raw_categories["Request subcategories by language"] = {
	description = "Umbrella categories covering topics related to requests.",
	additional = "{{{umbrella_meta_msg}}}",
	parents = {
		"Umbrella metacategories",
		{name = "Requests", sort = " "},
	},
}

raw_categories["Requests for quotation by source"] = {
	description = "Categories with requests for quotation, broken out by the source of the quotation.",
	additional = "Some abbreviated names of sources are explained at [[Wiktionary:Abbreviated Authorities in Webster]].",
	parents = {{name = "Requests for quotation", sort = "source"}},
	breadcrumb = "By source",
}

raw_categories["Requests for quotation"] = {
	-- FIXME
	description = "Words are added to this category by the inclusion in their entries of {{temp|rfv-quote}}.",
	parents = {{name = "Requests", sort = "quotation"}},
	breadcrumb = "Quotation",
}

raw_categories["Requests for date by source"] = {
	description = "Categories with requests for date, broken out by the source of the quotation whose date is sought.",
	parents = {{name = "Requests for date", sort = "source"}},
	breadcrumb = "By source",
}

raw_categories["Requests for date"] = {
	-- FIXME, break date requests by language and make not-hidden
	description = "Requests for a date to be added to a quotation.",
	additional = "To add an article to this category, use {{temp|rfdate}} or {{temp|rfdatek}} to include the author. " ..
	"Please remove the template from the article once the date has been provided. Articles are also added automatically by " ..
	"templates such as {{temp|quote-book}} if the year= parameter is not provided. Providing the parameter in each case on " ..
	"the page automatically removes the article from this category. See [[Wiktionary:Quotations]] for information about " ..
	"formatting dates and quotations.",
	parents = {{name = "Requests", sort = "date"}},
	breadcrumb = "Date",
	hidden = true,
}

raw_categories["Entries using missing taxonomic names"] = {
	description = "Entries that link to wikispecies because there is no corresponding Wiktionary entry for the taxonomic name in the template {{temp|taxlink}}.",
	additional = "The missing name is one or more of those enclosed in {{temp|taxlink}}. The entries are sorted by the missing taxonomic name." ..
	"\n\nSee [[:Category:mul:Taxonomic names]].",
	parents = {{name = "entry maintenance", is_label = true, lang = "mul"}},
	breadcrumb = "Missing taxonomic names",
	hidden = true,
}


-----------------------------------------------------------------------------
--                                                                         --
--                               RAW HANDLERS                              --
--                                                                         --
-----------------------------------------------------------------------------


-- This array consists of category match specs. Each spec contains one or more properties, whose values are strings
-- that may contain references to other properties using the {{{PROPERTY}}} syntax. Each such spec should have at least
-- a `regex` property that matches the name of the category. Capturing groups in this regex can be referenced in other
-- properties using {{{1}}} for the first group, {{{2}}} for the second group, etc. Property expansion happens
-- recursively if needed (i.e. a property can reference another property, which in turn references a third property).
--
-- If there is a `language_name` propery, it specifies the language name (and will typically be a reference to a
-- capturing group from the `regex` property); if not specified, it defaults to "{{{1}}}" unless the `nolang` property
-- is set, in which case there is no language name derivable from the category name. The language name must be the
-- canonical name of a recognized language, or an error is thrown. Based on the language name, the `language_code` and
-- `language_object` properties are automatically filled in. 
--
-- If the `regex` values of multiple category specs match, the first one takes precedence.
--
-- Recognized or predefined properties:
--
-- `pagename`: Current pagename.
-- `regex`: See above.
-- `1`, `2`, `3`, ...: See above.
-- `language_name`, `language_code`, `language_object`: See above.
-- `nolang`: See above.
-- `description`: Override the description (normally taken directly from the pagename).
-- `template_name`: Name of template which generates this category.
-- `template_sample_call`: Syntax for calling the template. Defaults to "{{{template_name}}}|{{{language_code}}}".
--    Used to display an example template call and the output of this call.
-- `template_actual_sample_call`: Syntax for calling the template. Takes precedence over `template_sample_call` when
--    generating example template output (but not when displaying an example template call) and is intended for a
--    template call that uses the |nocat=1 parameter.
-- `template_example_output`: Override the text that displays example template output (see `template_sample_call`).
-- `additional_template_description`: Extra text to be displayed after the example template output.
-- `parents`: Parent categories. Should be a list of elements, each of which is an object containing at least a name=
--    and sort= field (same format as parents= for regular raw categories, except that the name= and sort= field will
--    have {{{PROPERTY}}} references expanded). If no parents are specified, and the pagename is of the form
--    "Requests for FOO by language", the parent will be "Request subcategories by language" with FOO as the sort key.
--    Otherwise, the `language_name` property must exist, and the parent will be "Requests concerning LANGNAME" with
--    the pagename minus any initial "Requests for " as the sort key.
-- `umbrella`: Parent all-language category. Sort key is based on the language name.
-- `breadcrumb`: Specify the breadcrumb. If `parents` is given, there is no default (i.e. it will end up being the
--    pagename). Otherwise, if the pagename is of the form "Requests for FOO by language", "Requests for FOO in BAR",
--    or "Requests for FOO", it will be FOO.
-- `not_hidden_category`: Don't hide the category.
-- `catfix`: Same as `catfix` in regular labels and raw categories, except that request-specific {{{PROPERTY}}} syntax
--    is expanded.
-- `toc_template`, `toc_template_full`: Same as the corresponding fields in regular labels and raw categories, except
--    that request-specific {{{PROPERTY}}} syntax is expanded.
--
-- An actual template call can be inserted into a string using the syntax <<{{TEMPLATE|ARG1|ARG2|...}}>>.
local requests_categories = {
	{
		regex = "^Requests concerning (.+)$",
		description = "Categories with {{{1}}} entries that need the attention of experienced editors.",
		parents = {{name = "entry maintenance", is_label = true, sort = "requests"}},
		umbrella = "Requests by language",
		breadcrumb = "Requests",
		not_hidden_category = true
	},
	{
		regex = "^Requests for etymologies in (.+) entries$",
		umbrella = "Requests for etymologies by language",
		template_name = "rfe",
	},
	{
		regex = "^Requests for expansion of etymologies in (.+) entries$",
		umbrella = "Requests for expansion of etymologies by language",
		template_name = "etystub",
	},
	{
		regex = "^Requests for pronunciation in (.+) entries$",
		umbrella = "Requests for pronunciation by language",
		template_name = "rfp",
	},
	{
		regex = "^Requests for audio pronunciation in (.+) entries$",
		umbrella = "Requests for audio pronunciation by language",
		template_name = "rfap",
	},
	{
		regex = "^Requests for definitions in (.+) entries$",
		umbrella = "Requests for definitions by language",
		template_name = "rfdef",
	},
	{
		regex = "^Requests for clarification of definitions in (.+) entries$",
		umbrella = "Requests for clarification of definitions by language",
		template_name = "rfclarify",
	},
	{
		-- This is for part-of-speech-specific categories such as
		-- "Requests for inflections in Northern Ndebele noun entries" or
		-- "Requests for accents in Ukrainian proper noun entries".
		-- Here and below, we assume that the part of speech is begins with
		-- a lowercase letter, while the preceding language name ends in a
		-- capitalized word. Note that this entry comes before the
		-- following one and takes precedence over it.
		regex = "^Requests for inflections in (.-) ([a-z]+[a-z ]*) entries$",
		parents = {{name = "Requests for inflections in {{{language_name}}} entries", sort = "{{{2}}}"}},
		umbrella = "Requests for inflections of {{{2}}}s by language",
		breadcrumb = "{{{2}}}",
		template_name = "rfinfl",
		template_sample_call = "{{rfinfl|{{{language_code}}}|{{{2}}}}}",
	},
	{
		regex = "^Requests for inflections in (.+) entries$",
		umbrella = "Requests for inflections by language",
		template_name = "rfinfl",
	},
	{
		regex = "^Requests for inflections of (.+) by language$",
		nolang = true,
	},
	{
		regex = "^Requests for tone in (.-) ([a-z]+[a-z ]*) entries$",
		parents = {{name = "Requests for tone in {{{language_name}}} entries", sort = "{{{2}}}"}},
		umbrella = "Requests for tone of {{{2}}}s by language",
		breadcrumb = "{{{2}}}",
		template_name = "rftone",
		template_sample_call = "{{rftone|{{{language_code}}}|{{{2}}}}}",
	},
	{
		regex = "^Requests for tone in (.+) entries$",
		umbrella = "Requests for tone by language",
		template_name = "rftone",
	},
	{
		regex = "^Requests for tone of (.+) by language$",
		nolang = true,
	},
	{
		regex = "^Requests for accents in (.-) ([a-z]+[a-z ]*) entries$",
		parents = {{name = "Requests for accents in {{{language_name}}} entries", sort = "{{{2}}}"}},
		umbrella = "Requests for accents of {{{2}}}s by language",
		breadcrumb = "{{{2}}}",
		template_name = "rfaccents",
		template_sample_call = "{{rfaccents|{{{language_code}}}|{{{2}}}}}",
	},
	{
		regex = "^Requests for accents in (.+) entries$",
		umbrella = "Requests for accents by language",
		template_name = "rfaccents",
	},
	{
		regex = "^Requests for accents of (.+) by language$",
		nolang = true,
	},
	{
		regex = "^Requests for aspect in (.-) ([a-z]+[a-z ]*) entries$",
		parents = {{name = "Requests for aspect in {{{language_name}}} entries", sort = "{{{2}}}"}},
		umbrella = "Requests for aspect of {{{2}}}s by language",
		breadcrumb = "{{{2}}}",
		template_name = "rfaspect",
		template_sample_call = "{{rfaspect|{{{language_code}}}|{{{2}}}}}",
	},
	{
		regex = "^Requests for aspect in (.+) entries$",
		umbrella = "Requests for aspect by language",
		template_name = "rfaspect",
	},
	{
		regex = "^Requests for aspect of (.+) by language$",
		nolang = true,
	},
	{
		regex = "^Requests for gender in (.-) ([a-z]+[a-z ]*) entries$",
		parents = {{name = "Requests for gender in {{{language_name}}} entries", sort = "{{{2}}}"}},
		umbrella = "Requests for gender of {{{2}}}s by language",
		breadcrumb = "{{{2}}}",
		template_name = "rfgender",
		template_sample_call = "{{rfgender|{{{language_code}}}|{{{2}}}}}",
	},
	{
		regex = "^Requests for gender in (.+) entries$",
		umbrella = "Requests for gender by language",
		template_name = "rfgender",
	},
	{
		regex = "^Requests for gender of (.+) by language$",
		nolang = true,
	},
	{
		regex = "^Requests for example sentences in (.+)$",
		umbrella = "Requests for example sentences by language",
		template_name = "rfex",
	},
	{
		regex = "^Requests for collocations in (.+)$",
		umbrella = "Requests for collocations by language",
		template_name = "rfcoll",
	},
	{
		regex = "^Requests for quotations in (.+)$",
		umbrella = "Requests for quotations by language",
		template_name = "rfquote",
	},
	{
		regex = "^Requests for translations into (.+)$",
		umbrella = "Requests for translations by language",
		template_name = "t-needed",
		catfix = "en",
	},
	{
		regex = "^Requests for translations of (.+) usage examples$",
		umbrella = "Requests for translations of usage examples by language",
		breadcrumb = "Translations of usage examples",
		template_name = "t-needed",
		template_sample_call = "{{t-needed|{{{language_code}}}|usex=1}}",
		template_actual_sample_call = "{{t-needed|{{{language_code}}}|usex=1|nocat=1}}",
		additional_template_description = "The {{temp|ux}}, {{temp|uxi}}, {{temp|ja-usex}} and {{temp|zh-x}} templates automatically add the page to this category if the example is in a foreign language and the translation is missing."
	},
	{
		regex = "^Requests for translations of (.+) quotations$",
		umbrella = "Requests for translations of quotations by language",
		breadcrumb = "Translations of quotations",
		template_name = "t-needed",
		template_sample_call = "{{t-needed|{{{language_code}}}|quote=1}}",
		template_actual_sample_call = "{{t-needed|{{{language_code}}}|quote=1|nocat=1}}",
		additional_template_description = "The {{temp|quote}} and {{temp|Q}} templates automatically add the page to this category if the example is in a foreign language and the translation is missing."
	},
	{
		regex = "^Requests for review of (.+) translations$",
		umbrella = "Requests for review of translations by language",
		breadcrumb = "Review of translations",
		template_name = "t-check",
		template_sample_call = "{{t-check|{{{language_code}}}|example}}",
		template_example_output = "",
		catfix = "en",
	},
	{
		regex = "^Requests for transliteration of (.+) terms$",
		umbrella = "Requests for transliteration by language",
		template_name = "rftranslit",
		additional_template_description = "The {{temp|head}} template, and the large number of language-specific variants of it, automatically add " ..
		"the page to this category if the example is in a foreign language and no transliteration can be generated (particularly in languages without " ..
		"automated transliteration, such as Hebrew and Persian).",
	},
	{
		regex = "^Requests for native script for (.+) terms$",
		umbrella = "Requests for native script by language",
		template_name = "rfscript",
		template_actual_sample_call = "{{rfscript|{{{language_code}}}|nocat=1}}",
		catfix = false,
		additional_template_description = "Many templates such as {{temp|l}}, {{temp|m}} and {{temp|t}} automatically place the page in this category when they are missing the term but have been provided with a transliteration."
	},
	{
		regex = "^Requests for native script in (.+) usage examples$",
		umbrella = "Requests for native script in usage examples by language",
		template_name = "rfscript",
		template_sample_call = "{{rfscript|{{{language_code}}}|usex=1}}",
		template_actual_sample_call = "{{rfscript|{{{language_code}}}|usex=1|nocat=1}}",
		catfix = false,
		additional_template_description = "The {{temp|ux}} and {{temp|uxi}} templates automatically add the page to this category if the example itself is missing but the translation is supplied."
	},
	{
		regex = "^Requests for (.+) script for (.+) terms$",
		language_name = "{{{2}}}",
		parents = {{name = "Requests for native script for {{{language_name}}} terms", sort = "{{{1}}} script"}},
		umbrella = "Requests for {{{1}}} script by language",
		breadcrumb = "{{{1}}} script",
		template_name = "rfscript",
		script_code = "<<{{#invoke:scripts/templates|getByCanonicalName|{{{1}}}}}>>",
		template_sample_call = "{{rfscript|{{{language_code}}}|sc={{{script_code}}}}}",
		template_actual_sample_call = "{{rfscript|{{{language_code}}}|sc={{{script_code}}}|nocat=1}}",
		catfix = false,
		additional_template_description = "Many templates such as {{temp|l}}, {{temp|m}} and {{temp|t}} automatically place the page in this category when they are missing the term but have been provided with a transliteration."
	},
	{
		regex = "^Requests for (.+) script by language$",
		nolang = true,
	},
	{
		regex = "^Requests for images in (.+) entries$",
		umbrella = "Requests for images by language",
		template_name = "rfi",
	},
	{
		regex = "^Requests for references for (.+) terms$",
		umbrella = "Requests for references by language",
		template_name = "rfref",
	},
	{
		regex = "^Requests for references for etymologies in (.+) entries$",
		parents = {{name = "Requests for references for {{{language_name}}} terms", sort = "etymologies"}},
		umbrella = "Requests for references for etymologies by language",
		breadcrumb = "Etymologies",
		template_name = "rfv-etym",
	},
	{
		regex = "^Requests for references for pronunciations in (.+) entries$",
		parents = {{name = "Requests for references for {{{language_name}}} terms", sort = "pronunciations"}},
		umbrella = "Requests for references for pronunciations by language",
		breadcrumb = "Pronunciations",
		template_name = "rfv-pron",
	},
	{
		regex = "^Requests for attention concerning (.+)$",
		umbrella = "Requests for attention by language",
		template_name = "attention",
		template_example_output = "This template does not generate any text in entries.",
		-- These pages typically contain a mixture of English and native-language entries, so disable catfix.
		catfix = false,
		-- Setting catfix = false will normally trigger the English table of contents template.
		-- We still want the native-language table of contents template, though.
		toc_template = "{{{language_code}}}-categoryTOC",
		toc_template_full = "{{{language_code}}}-categoryTOC/full", 
	},
	{
		regex = "^Requests for cleanup in (.+) entries$",
		umbrella = "Requests for cleanup by language",
		template_name = "rfc",
		template_actual_sample_call = "{{rfc|{{{language_code}}}|nocat=1}}",
	},
	{
		regex = "^Requests for cleanup of Pronunciation N headers in (.+) entries$",
		umbrella = "Requests for cleanup of Pronunciation N headers by language",
		template_name = "rfc-pron-n",
		template_actual_sample_call = "{{rfc-pron-n|{{{language_code}}}|nocat=1}}",
		template_example_output = "This template does not generate any text in entries.",
		additional_template_description = [=[
The purpose of this category is to tag entries that use headers with "Pronunciation" and a number.

While these headers and structure are sometimes used, they are not specifically prescribed by [[WT:ELE]]. No complete proposal has yet been made on how they should work, what the semantics are, or how they interact with multiple etymologies. As a result they should generally be avoided. Instead, merge the entries (possibly under multiple Etymology sections, if appropriate), and list all pronunciations, appropriately tagged, under a Pronunciation header.

[[User:KassadBot|KassadBot]] tags these entries (or used to tag these entries, when the bot was operational). At some point if a proposal is made and adopted as policy, these entries should be reviewed.

This category is hidden.]=],
	},
	{
		regex = "^Requests for deletion in (.+) entries$",
		umbrella = "Requests for deletion by language",
		template_name = "rfd",
		template_actual_sample_call = "{{rfd|{{{language_code}}}|nocat=1}}",
	},
	{
		regex = "^Requests for verification in (.+) entries$",
		umbrella = "Requests for verification by language",
		template_name = "rfv",
	},
	{
		regex = "^Requests for attention in etymologies in (.+) entries$",
		umbrella = "Requests for attention in etymologies by language",
	},
	{
		regex = "^Requests for quotation/(.+)$",
		description = "Requests for a quotation or for quotations from {{{1}}}.",
		parents = {{name = "Requests for quotation by source", sort = "{{{1}}}"}},
		breadcrumb = "{{{1}}}",
		nolang = true,
		template_name = "rfquotek",
		template_sample_call = "{{rfquotek|LANGCODE|{{{1}}}}}",
		template_example_output = "\n(where LANGCODE is the language code of the entry)\n\nIt results in the message below:\n\n{{rfquotek|und|{{{1}}}}}",
	},
	{
		regex = "^Requests for date/(.+)$",
		description = "Requests for a date for a quotation or quotations from {{{1}}}.",
		parents = {{name = "Requests for date by source", sort = "{{{1}}}"}},
		breadcrumb = "{{{1}}}",
		nolang = true,
		template_name = "rfdatek",
		template_sample_call = "{{rfdatek|LANGCODE|{{{1}}}}}",
		template_example_output = "\n(where LANGCODE is the language code of the entry)\n\nIt results in the message below:\n\n{{rfdatek|und|{{{1}}}}}",
	},
}

table.insert(raw_handlers, function(data)
	local items = {pagename = data.category}

	local function replace_template_refs(result)
		if not result then
			return result
		end

		--[[	Replaces pseudo-template code {{{ }}} with the corresponding member
				of the "items" table. Has to be done at least twice,
				since some of the items are nested:

				{{{template_sample_call_with_temp}}}
					⇓
				{{{{{template_name}}}|{{{language_code}}}}}
					⇓
				{{attention|en}}							]]

		while result:find("{{{") do
			result = mw.ustring.gsub(
				result,
				"{{{([^%}%{]+)}}}",
				function(item)
					if items[item] then
						if type(items[item]) == "string" or type(items[item]) == "number" then
							return items[item]
						else
							error('The item "{{{' .. item .. '}}}" is a ' .. type(items[item]) .. ' and can\'t be concatenated. (Pagename: ' .. items.pagename .. '.)')
						end
					else
						error('The item "' .. item .. '" was not found in the "items" table. (Pagename: ' .. items.pagename .. '.)')
					end
				end
			)
		end

		-- Preprocess template code surrounded by << >>, repeatedly from inside out
		-- in case we have a << >> template call nested inside of another one
		-- (this doesn't currently happen). We need this mechanism at all because
		-- in "Requests for SCRIPT script for LANGUAGE terms", we need to convert the
		-- script to a script code before insertion into the template example code,
		-- which is inside of <pre> so it won't get expanded by the normal poscatboiler
		-- mechanism.
		while result:find("<<") do
			result = mw.ustring.gsub(
				result,
				"<<([^><]+)>>",
				function (template_code)
					return mw.getCurrentFrame():preprocess(template_code)
				end
			)
		end

		return result
	end

	local valid_category = false

	for i, category in ipairs(requests_categories) do
		local matchvals = {mw.ustring.match(items.pagename, category.regex)}
		if #matchvals > 0 then
			valid_category = true

			for key, value in pairs(category) do
				items[key] = value
			end
			for key, value in ipairs(matchvals) do
				items["" .. key] = value
			end
			break
		end
	end

	if not valid_category then
		for i, category in ipairs(requests_categories) do
			if items.pagename == category.umbrella then
				valid_category = true
				items.nolang = true
			end
		end
	end

	if not valid_category then
		return nil
	end

	if not items.nolang then
		items.language_name = items.language_name or "{{{1}}}"
		items.language_name = replace_template_refs(items.language_name)
		items.language_object = require("Module:languages").getByCanonicalName(items.language_name, true)
		items.language_code = items.language_object:getCode()
	end

	if items.template_name then
		items.template_sample_call = items.template_sample_call or "{{{{{template_name}}}|{{{language_code}}}}}"
		items.full_text_about_the_template = "To make this request, in this specific language, use this code in the entry (see also the documentation at [[Template:{{{template_name}}}]]):\n\n<pre>{{{template_sample_call}}}</pre>"

		if items.template_example_output then
			items.full_text_about_the_template = items.full_text_about_the_template .. " " .. items.template_example_output
		else
			items.template_actual_sample_call = items.template_actual_sample_call or items.template_sample_call
			items.full_text_about_the_template = items.full_text_about_the_template .. "\nIt results in the message below:\n\n{{{template_actual_sample_call}}}"
		end
		if items.additional_template_description then
			items.full_text_about_the_template = items.full_text_about_the_template .. "\n\n" .. items.additional_template_description
		end
	end

	local parents = items.parents
	local breadcrumb = items.breadcrumb and replace_template_refs(items.breadcrumb)

	if parents then
		for _, parent in ipairs(parents) do
			parent.name = replace_template_refs(parent.name)
			parent.sort = replace_template_refs(parent.sort)
		end
	else
		local umbrella_type = items.pagename:match("^Requests for (.+) by language$")
		if umbrella_type then
			breadcrumb = breadcrumb or umbrella_type
			parents = {{name = "Request subcategories by language", sort = umbrella_type}}
		elseif not items.language_name then
			error("Internal error: Don't know how to compute parents for non-language-specific category '" .. items.pagename .. "'")
		else
			local default_breadcrumb = items.pagename:match("^Requests for (.+) in .*$") or items.pagename:match("^Requests for (.+)$")
			breadcrumb = breadcrumb or default_breadcrumb
			parents = {{name = "Requests concerning " .. items.language_name, sort = default_breadcrumb}}
		end
	end

	if not items.nolang then
		table.insert(parents, {name = replace_template_refs(items.umbrella), sort = items.language_name})
	end

	local additional = replace_template_refs(items.full_text_about_the_template)
	if items.pagename:find(" by language$") then
		additional = "{{{umbrella_msg}}}" .. (additional and "\n\n" .. additional or "")
	end

	return {
		description = replace_template_refs(items.description) or items.pagename .. ".",
		lang = items.language_code,
		additional = additional,
		parents = parents,
		-- If no breadcrumb=, it will default to the category name
		breadcrumb = breadcrumb,
		catfix = replace_template_refs(items.catfix),
		toc_template = replace_template_refs(items.toc_template),
		toc_template_full = replace_template_refs(items.toc_template_full),
		hidden = not items.not_hidden_category,
		can_be_empty = true,
	}
end)


local recognized_taxtypes = require("Module:table/listToSet") {
  "ambiguous",
  "binomial",
  "branch",
  "clade",
  "cladus",
  "class",
  "cohort",
  "convariety",
  "cultivar group",
  "cultivar",
  "division",
  "empire",
  "epifamily",
  "epithet",
  "family",
  "form taxon",
  "form",
  "genus",
  "grade",
  "grandorder",
  "group",
  "hybrid",
  "informal group",
  "infraclass",
  "infracohort",
  "infrakingdom",
  "infraorder",
  "infraphylum",
  "infraspecies",
  "kingdom",
  "magnorder",
  "megacohort",
  "mirorder",
  "morph",
  "nothogenus",
  "nothospecies",
  "nothosubspecies",
  "nothovariety",
  "obsolete",
  "oofamily",
  "order",
  "parvclass",
  "parvorder",
  "phylum",
  "section",
  "series",
  "serovar",
  "species group",
  "species",
  "stem",
  "strain",
  "subclass",
  "subcohort",
  "subdivision",
  "subfamily",
  "subgenus",
  "subgroup",
  "subinfraorder",
  "subkingdom",
  "suborder",
  "subphylum",
  "subsection",
  "subspecies",
  "subterclass",
  "subtribe",
  "superclass",
  "supercohort",
  "superfamily",
  "supergroup",
  "superorder",
  "superphylum",
  "supertribe",
  "taxon",
  "tribe",
  "trinomial",
  "undescribed species",
  "unknown",
  "unranked group",
  "variety",
  "virus complex",
}

table.insert(raw_handlers, function(data)
	local taxtype = data.category:match("^Entries using missing taxonomic name %((.*)%)$")
	if taxtype and recognized_taxtypes[taxtype] then
		return {
			description = "Entries that link to wikispecies because there is no corresponding Wiktionary entry for the taxonomic name in the template {{temp|taxlink}}.",
			additional = "The missing name is one or more of those enclosed in {{temp|taxlink}}. The entries are sorted by the missing taxonomic name.",
			parents = {{name = "Entries using missing taxonomic names", sort = taxtype}},
			breadcrumb = taxtype,
			hidden = true,
		}
	end
end)

return {LABELS = labels, RAW_CATEGORIES = raw_categories, RAW_HANDLERS = raw_handlers}

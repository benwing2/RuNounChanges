local labels = {}
local raw_categories = {}
local handlers = {}
local raw_handlers = {}


-----------------------------------------------------------------------------
--                                                                         --
--                                  LABELS                                 --
--                                                                         --
-----------------------------------------------------------------------------


labels["entry maintenance"] = {
	description = "{{{langname}}} entries, or entries in other languages containing {{{langname}}} terms, that are being tracked for attention and improvement by editors.",
	parents = {{module = "langcatboiler", args = {code = "{{{langcode}}}"}}},
	fundamental = "Fundamental",
}

labels["entries without References header"] = {
	description = "{{{langname}}} entries without a References header.",
	parents = {"entry maintenance"},
	fundamental = "Entry maintenance subcategories by language",
	can_be_empty = true,
	hidden = true,
}

labels["entries without References or Further reading header"] = {
	description = "{{{langname}}} entries without a References or Further reading header.",
	parents = {"entry maintenance"},
	fundamental = "Entry maintenance subcategories by language",
	can_be_empty = true,
	hidden = true,
}

labels["entries that don't exist"] = {
	description = "{{{langname}}} terms that do not meet the [[Wiktionary:Criteria for inclusion|criteria for inclusion]] (CFD). They are added to the category with the template {{temp|no entry|{{{langcode}}}}}.",
	parents = {"entry maintenance"},
	fundamental = "Entry maintenance subcategories by language",
}

labels["term requests"] = {
	description = "Entries with [[Template:der]], [[Template:inh]], [[Template:m]] and similar templates lacking the parameter for linking to {{{langname}}} terms.",
	parents = {"entry maintenance"},
	fundamental = "Entry maintenance subcategories by language",
	can_be_empty = true,
	hidden = true,
}

labels["redlinks"] = {
	description = "Links to {{{langname}}} entries that have not been created yet.",
	parents = {"entry maintenance"},
	fundamental = "Entry maintenance subcategories by language",
	catfix_lang = false,
	can_be_empty = true,
	hidden = true,
}

labels["redlinks/l"] = {
	description = "Redlinks to {{{langname}}} entries using the template <code>{{[[Template:l|l]]}}</code>.",
	parents = {"redlinks"},
	fundamental = "Entry maintenance subcategories by language",
	catfix_lang = false,
	can_be_empty = true,
	hidden = true,
}

labels["redlinks/m"] = {
	description = "Redlinks to {{{langname}}} entries using the template <code>{{[[Template:m|m]]}}</code>.",
	parents = {"redlinks"},
	fundamental = "Entry maintenance subcategories by language",
	catfix_lang = false,
	can_be_empty = true,
	hidden = true,
}

labels["redlinks/t"] = {
	description = "Redlinks to {{{langname}}} entries using the template <code>{{[[Template:t|t]]}}</code>.",
	parents = {"redlinks"},
	fundamental = "Entry maintenance subcategories by language",
	catfix_lang = false,
	can_be_empty = true,
	hidden = true,
}

labels["redlinks/t+"] = {
	description = "Redlinks to {{{langname}}} entries using the template <code>{{[[Template:t+|t+]]}}</code>.",
	parents = {"redlinks"},
	fundamental = "Entry maintenance subcategories by language",
	catfix_lang = false,
	can_be_empty = true,
	hidden = true,
}

labels["terms with IPA pronunciation"] = {
	description = "{{{langname}}} terms that include the pronunciation in the form of IPA. For requests related to this category, see [[:Category:Requests for pronunciation in {{{langname}}} entries]].",
	parents = {"entry maintenance"},
	fundamental = "Entry maintenance subcategories by language",
}

labels["terms with audio links"] = {
	description = "{{{langname}}} terms that include the pronunciation in the form of an audio link.",
	parents = {"entry maintenance"},
	fundamental = "Entry maintenance subcategories by language",
}

labels["terms needing to be assigned to a sense"] = {
	description = "{{{langname}}} entries that have terms under headers such as \"Synonyms\" or \"Antonyms\" not assigned to a specific sense of the entry in which they appear. Use [[Template:syn]] or [[Template:ant]] to fix these.",
	parents = {"entry maintenance"},
	fundamental = "Entry maintenance subcategories by language",
	can_be_empty = true,
	hidden = true,
}

--[=[
labels["terms with inflection tables"] = {
	description = "{{{langname}}} entries that contain inflection tables. For requests related to this category, see [[:Category:Requests for inflections in {{{langname}}} entries]].",
	parents = {"entry maintenance"},
	fundamental = "Entry maintenance subcategories by language",
}
]=]

labels["terms with usage examples"] = {
	description = "{{{langname}}} entries that contain usage examples or quotes that were added using templates such as [[Template:ux]]. For requests related to this category, see [[:Category:Requests for example sentences in {{{langname}}}]]. See also [[:Category:Requests for quotations in {{{langname}}}]].",
	parents = {"entry maintenance"},
	fundamental = "Entry maintenance subcategories by language",
}

labels["terms with quotations"] = {
	description = "{{{langname}}} entries that contain quotes that were added using templates such as [[Template:quote]], [[Template:quote-book]] and [[Template:quote-journal]]. For requests related to this category, see [[:Category:Requests for quotations in {{{langname}}}]]. See also [[:Category:Requests for example sentences in {{{langname}}}]].",
	parents = {"entry maintenance"},
	fundamental = "Entry maintenance subcategories by language",
}



-----------------------------------------------------------------------------
--                                                                         --
--                              RAW CATEGORIES                             --
--                                                                         --
-----------------------------------------------------------------------------


raw_categories["Entry maintenance subcategories by language"] = {
	description = "Umbrella categories covering topics related to entry maintenance.\n\n{{{umbrella_meta_msg}}}",
	parents = {{name = "entry maintenance", is_label = true, sort = " "}},
	breadcrumb = "Subcategories by language",
}

raw_categories["Requests"] = {
	intro = "{{shortcut|WT:CR|WT:RQ}}",
	description = "A parent category for the various request categories.",
	parents = {"Wiktionary"},
}

raw_categories["Requests by language"] = {
	description = "Categories with requests in various specific languages.\n\n{{{umbrella_msg}}}",
	parents = {{name = "Requests", sort = " "}},
	breadcrumb = "By language",
}

raw_categories["Request subcategories by language"] = {
	description = "Umbrella categories covering topics related to requests.\n\n{{{umbrella_meta_msg}}}",
	parents = {{name = "entry maintenance", is_label = true, sort = " requests"}}, -- space in sort key is intentional
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



-----------------------------------------------------------------------------
--                                                                         --
--                                 HANDLERS                                --
--                                                                         --
-----------------------------------------------------------------------------


-- This array consists of category match specs. Each spec contains
-- one or more properties, whose values are strings that may contain
-- references to other properties using the {{{PROPERTY}}} syntax.
-- Each such spec should have a least a `regex` property that matches the
-- name of the category. Capturing groups in this regex can be referenced
-- in other properties using {{{1}}} for the first group, {{{2}}} for the
-- second group, etc. Property expansion happens recursively if needed
-- (i.e. a property can reference another property, which in turn
-- references a third property).
--
-- If there is a `language_name` propery, it specifies the language name
-- (and will typically be a reference to a capturing group from the `regex`
-- property); if not specified, it defaults to "{{{1}}}" unless the `nolang`
-- property is set, in which case there is no language name derivable from
-- the category name. The language name must be the canonical name of a
-- recognized language, or an error is thrown. Based on the language name,
-- the `language_code` and `language_object` properties are automatically
-- filled in. 
--
-- If the `regex` values of multiple category specs match, the first one
-- takes precedence.
--
-- Recognized or predefined properties:
--
-- `pagename`: Current pagename.
-- `regex`: See above.
-- `1`, `2`, `3`, ...: See above.
-- `language_name`, `language_code`, `language_object`: See above.
-- `nolang`: See above.
-- `template_name`: Name of template which generates this category.
-- `template_sample_call`: Syntax for calling the template. Defaults to
--    "{{{template_name}}}|{{{language_code}}}". Used to display
--    an example template call and the output of this call.
-- `template_actual_sample_call`: Syntax for calling the template. Takes
--    precedence over `template_sample_call` when generating example template
--    output (but not when displaying an example template call) and is
--    intended for a template call that uses the |nocat=1 parameter.
-- `template_example_output`: Override the text that displays example
--    template output (see `template_sample_call`).
-- `additional_template_description`: Extra text to be displayed after the example template output.
-- `parents`: Parent categories. Should be a list of elements, each of which is an object containing
--    at least a name= and sort= field (same format as parents= for regular labels, except that the
--    name= and sort= field will have {{{PROPERTY}}} references expanded).
-- `umbrella`: Parent all-language category. Sort key is based on the language name.
-- `not_hidden_category`: Don't hide the category.
-- `catfix_lang`: Language to use for generating a "catfix" on the page to ensure that entries on the page are
--    appropriately styled; see [[Module:utilities]] for more information. Defaults to `language_object`.
--
-- An actual template call can be inserted into a string using the syntax
-- <<{{TEMPLATE|ARG1|ARG2|...}}>>. Currently this is used internally
-- to display the example template output (see `template_sample_call` above).
local requests_categories = {
	{
		regex = "^Requests concerning (.+)$",
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
		regex = "^Requests for quotations in (.+)$",
		umbrella = "Requests for quotations by language",
		template_name = "rfquote",
	},
	{
		regex = "^Requests for translations into (.+)$",
		umbrella = "Requests for translations by language",
		template_name = "t-needed",
		catfix_lang = "en",
	},
	{
		regex = "^Requests for translations of (.+) usage examples$",
		umbrella = "Requests for translations of usage examples by language",
		breadcrumb = "Translations of usage examples",
		template_name = "t-needed",
		template_sample_call = "{{t-needed|{{{language_code}}}|usex=1}}",
		template_actual_sample_call = "{{t-needed|{{{language_code}}}|usex=1|nocat=1}}",
		additional_template_description = "\n\nThe {{temp|ux}}, {{temp|uxi}}, {{temp|quote}}, {{temp|Q}}, {{temp|ja-usex}} and {{temp|zh-x}} templates automatically add the page to this category if the example is in a foreign language and the translation is missing."
	},
	{
		regex = "^Requests for review of (.+) translations$",
		umbrella = "Requests for review of translations by language",
		breadcrumb = "Review of translations",
		template_name = "t-check",
		template_sample_call = "{{t-check|{{{language_code}}}|example}}",
		template_example_output = "",
		catfix_lang = "en",
	},
	{
		regex = "^Requests for transliteration of (.+) terms$",
		umbrella = "Requests for transliteration by language",
		template_name = "rftranslit",
	},
	{
		regex = "^Requests for native script for (.+) terms$",
		umbrella = "Requests for native script by language",
		template_name = "rfscript",
		template_actual_sample_call = "{{rfscript|{{{language_code}}}|nocat=1}}",
		catfix_lang = false,
		additional_template_description = "\n\nMany templates such as {{temp|l}}, {{temp|m}} and {{temp|t}} automatically place the page in this category when they are missing the term but have been provided with a transliteration."
	},
	{
		regex = "^Requests for native script in (.+) usage examples$",
		umbrella = "Requests for native script in usage examples by language",
		template_name = "rfscript",
		template_sample_call = "{{rfscript|{{{language_code}}}|usex=1}}",
		template_actual_sample_call = "{{rfscript|{{{language_code}}}|usex=1|nocat=1}}",
		catfix_lang = false,
		additional_template_description = "\n\nThe {{temp|ux}} and {{temp|uxi}} templates automatically add the page to this category if the example itself is missing but the translation is supplied."
	},
	{
		regex = "^Requests for (.+) script for (.+) terms$",
		language_name = "{{{2}}}",
		parents = {{name = "Requests for native script for {{{language_name}}} terms", sort = "{{{1}}} script"}},
		umbrella = "Requests for {{{1}}} script by language",
		breadcrumb = "{{{1}}} script",
		template_name = "rfscript",
		script_code = "{{#invoke:scripts/templates|getByCanonicalName|{{{1}}}}}",
		template_sample_call = "{{rfscript|{{{language_code}}}|sc={{{script_code}}}}}",
		template_actual_sample_call = "{{rfscript|{{{language_code}}}|sc={{{script_code}}}|nocat=1}}",
		catfix_lang = false,
		additional_template_description = "\n\nMany templates such as {{temp|l}}, {{temp|m}} and {{temp|t}} automatically place the page in this category when they are missing the term but have been provided with a transliteration."
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
		catfix_lang = false,
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

table.insert(raw_handlers, function(label)
	local items = {pagename = label}

	local function replace_template_refs(result)
		if not result then
			return nil
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
							error('The item "{{{' .. item .. '}}}" is a ' .. type(item) .. ' and can\'t be concatenated. (Pagename: ' .. items.pagename .. '.)')
						end
					else
						error('The item "' .. item .. '" was not found in the "items" table. (Pagename: ' .. items.pagename .. '.)')
					end
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
		items.language_object = require("Module:languages").getByCanonicalName(items.language_name) or error ('The category title contains an invalid language name, "' .. items.language_name .. '". Choose a canonical name from the data modules of Module:languages.')
		items.language_code = items.language_object:getCode()
	end

	if items.template_name then
		items.template_sample_call = items.template_sample_call or "{{{{{template_name}}}|{{{language_code}}}}}"
		items.full_text_about_the_template = "\n" .. "To make this request, in this specific language, use this code in the entry (see also the documentation at [[Template:{{{template_name}}}]]):\n\n<pre>{{{template_sample_call}}}</pre>"

		if items.template_example_output then
			items.full_text_about_the_template = items.full_text_about_the_template .. " " .. items.template_example_output
		else
			items.template_actual_sample_call = items.template_actual_sample_call or items.template_sample_call
			items.full_text_about_the_template = items.full_text_about_the_template .. "\nIt results in the message below:\n\n{{{template_actual_sample_call}}}"
		end
		if items.additional_template_description then
			items.full_text_about_the_template = items.full_text_about_the_template .. items.additional_template_description
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

	return {
		description = replace_template_refs(items.description) or items.pagename .. ".",
		lang = items.language_object,
		additional = replace_template_refs(items.full_text_about_the_template),
		parents = parents,
		-- If no breadcrumb=, it will default to the category name
		breadcrumb = breadcrumb,
		catfix_lang = items.catfix_lang,
		hidden = not items.not_hidden_category,
		can_be_empty = true,
	}
end)


return {LABELS = labels, RAW_CATEGORIES = raw_categories, HANDLERS = handlers, RAW_HANDLERS = raw_handlers}

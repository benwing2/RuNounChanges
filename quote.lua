--[=[
	This module contains functions to implement quote-* templates.

	Author: Benwing2; conversion into Lua of {{quote-meta/source}} template,
	written by Sgconlaw with some help from Erutuon and Benwing2.

	The main interface is quote_t(). Note that the source display is handled by source(), which reads both the
	arguments passed to it *and* the arguments passed to the parent template, with the former overriding the latter.
]=]

local export = {}

local test_new_code = false
local test_new_code_with_errors = false

-- Named constants for all modules used, to make it easier to swap out sandbox versions.
local check_isxn_module = "Module:check isxn"
local debug_track_module = "Module:debug/track"
local italics_module = "Module:italics"
local languages_module = "Module:languages"
local links_module = "Module:links"
local number_utilities_module = "Module:number-utilities"
local parameters_module = "Module:parameters"
local parse_utilities_module = "Module:parse utilities"
local roman_numerals_module = "Module:roman numerals"
local script_utilities_module = "Module:script utilities"
local scripts_module = "Module:scripts"
local table_module = "Module:table"
local time_module = "Module:time"
local usex_module = "Module:usex"
local usex_templates_module = "Module:usex/templates"
local utilities_module = "Module:utilities"
local yesno_module = "Module:yesno"

local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rfind = mw.ustring.find
local rsplit = mw.text.split
local ulen = mw.ustring.len

-- Use HTML entities here to avoid parsing issues (esp. with brackets)
local SEMICOLON_SPACE = "&#59; "
local SPACE_LBRAC = " &#91;"
local RBRAC = "&#93;"

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function maintenance_line(text)
	return "<span class=\"maintenance-line\" style=\"color: #777777;\">(" .. text .. ")</span>"
end

local function isbn(text)
	return "[[Special:BookSources/" .. text .. "|→ISBN]]" ..
		require(check_isxn_module).check_isbn(text, "&nbsp;<span class=\"error\" style=\"font-size:88%\">Invalid&nbsp;ISBN</span>[[Category:Pages with ISBN errors]]")
end

local function issn(text)
	return "[https://www.worldcat.org/issn/" .. text .. " →ISSN]" ..
		require(check_isxn_module).check_issn(text, "&nbsp;<span class=\"error\" style=\"font-size:88%\">Invalid&nbsp;ISSN</span>[[Category:Pages with ISSN errors]]")
end

local function lccn(text)
	local origtext = text
	text = rsub(text, " ", "")
	if rfind(text, "%-") then
		-- old-style LCCN; reformat per request by [[User:The Editor's Apprentice]]
		local prefix, part1, part2 = rmatch(text, "^(.-)([0-9]+)%-([0-9]+)$")
		if prefix then
			if ulen(part2) < 6 then
				part2 = ("0"):rep(6 - ulen(part2)) .. part2
			end
			text = prefix .. part1 .. part2
		end
	end
	return "[https://lccn.loc.gov/" .. mw.uri.encode(text) .. " →LCCN]"
end

local function format_date(text)
	return mw.getCurrentFrame():callParserFunction{name="#formatdate", args=text}
end

local function tag_nowiki(text)
	return mw.getCurrentFrame():callParserFunction{name="#tag", args={"nowiki", text}}
end

-- Convert a comma-separated list of language codes to a comma-separated list of language names. `paramname` is the
-- name of the parameter from which the list of language codes was fetched.
local function format_langs(langs, paramname)
	langs = rsplit(langs, ",")
	for i, langcode in ipairs(langs) do
		local lang = require(languages_module).getByCode(langcode, paramname)
		langs[i] = lang:getCanonicalName()
	end
	if #langs == 1 then
		return langs[1]
	else
		return require(table_module).serialCommaJoin(langs)
	end
end

local param_mods = {
	t = {
		-- <t:...> and <gloss:...> are aliases.
		item_dest = "gloss",
	},
	gloss = {},
	tr = {},
	ts = {},
	sc = {
		convert = function(arg, parse_err)
			return require(scripts_module).getByCode(arg, parse_err)
		end,
	}
}

-- Parse a text property that may be in a foreign language or script. `val` is the value of the parameter and
-- `paramname` is the name of the parameter from which the value was retrieved. `explicit_gloss`, if specified and
-- non-nil, overrides any gloss specified using the <t:...> or <gloss:...> inline modifier.
--
-- If `val` is nil, the return value of this function is nil. Otherwise it is parsed for a language prefix (e.g.
-- 'ar:مُؤَلِّف') and inline modifiers (e.g. 'ar:مُؤَلِّف<t:Author>'), and the return value is an object with the following
-- fields:
--   `text`: The text after stripping off any language prefix and inline modifiers.
--   `lang`: The language object corresponding to the language prefix, if specified, or nil if no language prefix is
--           given.
--   `sc`: The script object corresponding to the <sc:...> modifier, if given; otherwise nil.
--   `tr`: The transliteration corresponding to the <tr:...> modifier, if given; otherwise nil.
--   `ts`: The transcription corresponding to the <ts:...> modifier, if given; otherwise nil.
--   `gloss`: The gloss/translation corresponding to the `explicit_gloss` parameter (if given and non-nil), otherwise
--            the <t:...> or <gloss:...> modifiers if given, otherwise nil.
--
-- Note that as a special case, if `val` contains HTML tags at the top level (e.g. '<span class="Arab">...</span>', as
-- might be generated by specifying {{lang|ar|مُؤَلِّف}}), no language prefix or inline modifiers are parsed, and the return
-- value has the `noscript` field set to true, which tells format_text() not to try to identify the script of the text
-- and CSS-tag the text accordingly, but to leave the text untagged.
--
-- This object can be passed to format_text() to format a string displaying the text (appropriately script-tagged,
-- unless `noscript` is set, as described above) and modifiers.
local function parse_text_with_lang(val, paramname, explicit_gloss)
	if not val then
		return nil
	end
	-- Check for inline modifier, e.g. מרים<tr:Miryem>. But exclude HTML entry with <span ...>, <i ...>, <br/> or
	-- similar in it, caused by wrapping an argument in {{l|...}}, {{lang|...}} or similar. Basically, all tags of the
	-- sort we parse here should consist of a less-than sign, plus letters, plus a colon, e.g. <tr:...>, so if we see a
	-- tag on the outer level that isn't in this format, we don't try to parse it. The restriction to the outer level is
	-- to allow generated HTML inside of e.g. qualifier modifiers, such as foo<q:similar to {{m|fr|bar}}> (if we end up
	-- supporting such modifiers). If we find a parameter value with top-level HTML in it, add 'noscript = true' to
	-- indicate that we should not try to do script inference and tagging. (Otherwise, e.g. if you specify
	-- {{lang|ar|مُؤَلِّف}} as the author, you'll get an extra big font coming from the fact that {{lang|...}} wraps the
	-- Arabic text in CSS that increases the size from the default, and then we do script detection and again wrap the
	-- text in the same CSS, which increases the size even more.)
	if val:find("^[^<]*<[a-z]*[^a-z:]") then
		return {text = val, noscript = true}
	end

	local function generate_obj(text, parse_err_or_paramname)
		local obj = {}
		if text:find(":[^ ]") then
			local actual_text, textlang = require(parse_utilities_module).parse_term_with_lang(text, parse_err_or_paramname)
			obj.text = actual_text
			obj.lang = textlang
		else
			obj.text = text
		end
		return obj
	end

	local obj
	if val:find("<") then
		-- Check for inline modifier.
		obj = require(parse_utilities_module).parse_inline_modifiers(val, {
			paramname = paramname,
			param_mods = param_mods,
			generate_obj = generate_obj,
		})
	else
		obj = generate_obj(val)
	end

	if explicit_gloss then
		obj.gloss = explicit_gloss
	end

	return obj
end

-- Format a text property that may be in a foreign language or script, along with annotations. This is conceptually
-- similar to the full_link() function in [[Module:links]], but displays the annotations in a different format that is
-- more appropriate for bibliographic entries. The output looks like this:
--
-- TEXT [TRANSLIT /TRANSCRIPTION/, GLOSS]
--
-- `textobj` is as returned by `parse_text_with_lang`. `tag_text`, if supplied, is a function of one argument to further
-- wrap the text after it has been processed and CSS-tagged appropriately, directly before insertion. `tag_gloss` is a
-- similar function for the gloss.
local function format_text(textobj, tag_text, tag_gloss)
	if not textobj then
		return nil
	end
	local text = textobj.text
	local tr, ts, gloss = textobj.tr, textobj.ts, textobj.gloss

	-- See above for `noscript`, meaning HTML was found in the text value, probably generated using {{lang|...}}.
	-- {{lang}} already script-tags the text and processes embedded language links, so we don't want to do it again (in
	-- fact, the code below within the if-clause is similar to what {{lang}} does). In such a case, an explicit language
	-- won't be available and findBestScriptWithoutLang() may not be accurate, so we can't do automatic transliteration.
	if not textobj.noscript then
		local lang = textobj.lang
		-- As an optimization, don't do script detection on an argument that contains only ASCII.
		local sc = textobj.sc or lang and lang:findBestScript(text) or not text:find("^[ -~]$") and
			require(scripts_module).findBestScriptWithoutLang(text) or nil
		-- As an optimization, don't do any of the following if there's no language, script, translit or transcription,
		-- as will be the case with simple ASCII values.
		if lang or sc or tr or ts then
			lang = lang or require(languages_module).getByCode("und", true)
	
			if tr == "-" then
				tr = nil
			elseif not tr and sc and not sc:getCode():find("Latn") then -- Latn, Latnx or a lang-specific variant
				-- might return nil
				tr = (lang:transliterate(require(links_module).remove_links(text), sc))
			end
	
			text = require(links_module).embedded_language_links(
				{
					term = text,
					lang = lang,
					sc = sc
				},
				false
			)
			if lang:getCode() ~= "und" or sc:getCode() ~= "Latn" then
				text = require(script_utilities_module).tag_text(text, lang, sc)
			end
	
			if tr then
				-- Should we link to the transliteration of languages with lang:link_tr()? Probably not because `text` is not
				-- likely to be a term that has an entry.
				tr = require(script_utilities_module).tag_translit(tr, lang, "usex")
			end
			if ts then
				ts = require(script_utilities_module).tag_transcription(ts, lang, "usex")
			end
		end
	end

	text = require(italics_module).unitalicize_brackets(text)
	if tag_text then
		text = tag_text(text)
	end

	local parts = {}
	local function ins(txt)
		table.insert(parts, txt)
	end

	ins(text)

	if tr or ts or gloss then
		ins(SPACE_LBRAC)
		if tr then
			ins(tr)
		end
		if ts then
			if tr then
				ins(" ")
			end
			ins("/" .. ts .. "/")
		end
		if gloss then
			if tr or ts then
				ins(", ")
			end
			gloss = '<span class="e-translation">' .. gloss .. "</span>"
			gloss = require(italics_module).unitalicize_brackets(gloss)
			if tag_gloss then
				gloss = tag_gloss(gloss)
			end
			ins(gloss)
		end
		ins(RBRAC)
	end

	return table.concat(parts)
end


-- Fancy version of ine() (if-not-empty). Converts empty string to nil, but also strips leading/trailing space.
local function ine(arg)
	if not arg then return nil end
	arg = mw.text.trim(arg)
	if arg == "" then return nil end
	return arg
end

-- Clone and combine frame's and parent's args while also assigning nil to empty strings.
local function clone_args(direct_args, parent_args, include_direct, include_parent)
	local args = {}

	-- If both include_parent and include_direct are given, processing the former must come first so that direct args
	-- override parent args. Note that if a direct arg is specified but is blank, it will still override the parent
	-- arg (with nil).
	if include_parent then
		for pname, param in pairs(parent_args) do
			args[pname] = ine(param)
		end
	end
	if include_direct then
		for pname, param in pairs(direct_args) do
			args[pname] = ine(param)
		end
	end
	return args
end

local function check_url(param, value)
	if value and value:find(" ") and not value:find("%[") then
		error(("URL not allowed to contain a space, but saw %s=%s"):format(param, value))
	end
	return value
end

-- Display the source line of the quote, above the actual quote text. This contains the majority of the logic of this
-- module (formerly contained in {{quote-meta/source}}).
function export.source(args)
	local tracking_categories = {}

	local argslang = args.lang or args[1]
	if not argslang then
		-- For the moment, only trigger an error on mainspace pages and
		-- other pages that are not user pages or pages containing discussions.
		-- These are the same pages that appear in the appropriate tracking
		-- categories. User and discussion pages have not generally been
		-- fixed up to include a language code and so it's more helpful
		-- to use a maintenance line than signal an error.
		local FULLPAGENAME = mw.title.getCurrentTitle().fullText
		local NAMESPACE = mw.title.getCurrentTitle().nsText

		if NAMESPACE ~= "Template" and not require(usex_templates_module).page_should_be_ignored(FULLPAGENAME) then
			require(languages_module).err(nil, 1)
		end
	end

	if args.date and args.year then
		error("Only one of date= or year= should be specified")
	end

	local output = {}
	-- Add text to the output. The text goes into a list, and we concatenate
	-- all the list components together at the end.
	local function add(text)
		table.insert(output, text)
	end
	if args.brackets then
		add("[")
	end
	add(require(time_module).quote_impl(args))
	if args.origdate then
		add(" [" .. args.origdate .. "]")
	elseif args.origyear and args.origmonth then
		add(" [" .. args.origmonth .. " " .. args.origyear .. "]")
	elseif args.origyear then
		add(" [" .. args.origyear .. "]")
	end
	
	-- Return a function that generates the actual parameter name associated with a base param (e.g. "author", "last").
	-- The actual parameter name may have an index added (an empty string for the first set of params, e.g. author=,
	-- last=, or a numeric index for further sets of params, e.g. author2=, last2=, etc.).
	local function make_get_full_paramname(ind)
		return function(param)
			return param .. ind
		end
	end
	-- Function to fetch the actual parameter name associated with a base param (see make_get_full_paramname() above).
	-- Assigned at various times below by calling make_get_full_paramname(). We do it this way so that we can have
	-- wrapper functions that access params and define them only oncec.
	local get_full_paramname
	-- Fetch the value of a parameter given the base param name (which may have a numeric index added).
	local function a(param)
		return args[get_full_paramname(param)]
	end
	-- Return two values: the value of a parameter given the base param name (which may have a numeric index added),
	-- and the actual parameter name. The base parameter can be a list of such base params, which are checked in turn.
	local function a_with_name(param)
		if type(param) == "table" then
			for _, par in ipairs(param) do
				local val, name = a_with_name(par)
				if val then
					return val, name
				end
			end
			return nil
		end
		local fullname = get_full_paramname(param)
		return args[fullname], fullname
	end

	-- Convenience function to fetch a parameter that may be in a foreign language or text (and may consequently have
	-- a language prefix and/or inline modifiers), parse the modifiers and convert the result into a formatted string.
	-- This is the same as parse_and_format_text() below but also returns the param name as the second return value.
	local function parse_and_format_text_with_name(param, tag_text, tag_gloss)
		local paramval, paramname = a_with_name(param)
		local obj = parse_text_with_lang(paramval, paramname)
		return format_text(obj, tag_text, tag_gloss), paramname
	end

	-- Convenience function to fetch a parameter that may be in a foreign language or text (and may consequently have
	-- a language prefix and/or inline modifiers), parse the modifiers and convert the result into a formatted string.
	-- This is a wrapper around parse_text_with_lang() and format_text(). `param` is the base parameter name (see
	-- a_with_name()), `tag_text` is an optional function to tag the parameter text after all other processing (e.g.
	-- wrap in <cite>...</cite> tags), and `tag_gloss` is a similar function for the parameter translation/gloss.
	local function parse_and_format_text(param, tag_text, tag_gloss)
		return (parse_and_format_text_with_name(param, tag_text, tag_gloss))
	end

	if args.author or args.last or args.quotee then
		-- Find maximum indexed author or last name.
		local maxind = 0
		for arg, _ in pairs(args) do
			local argbase, argind = rmatch(arg, "^([a-z]+)([0-9]*)$")
			if argbase == "author" or argbase == "last" then
				argind = argind == "" and 1 or tonumber(argind)
				if argind > maxind then
					maxind = argind
				end
			end
		end

		for i = 1, maxind do
			local ind = i == 1 and "" or i
			get_full_paramname = make_get_full_paramname(ind)
			local author, author_param = a_with_name("author")
			local last = a("last")
			local first = a("first")
			if author or last then
				-- If first author, output a comma unless {{{nodate}}} used.
				if i == 1 and not args.nodate then
					add(", ")
				end
				-- If not first author, output a semicolon to separate from preceding authors.
				add(i == 1 and " " or SEMICOLON_SPACE)
				local function make_author_with_url(txt, authorlink)
					if authorlink then
						return "[[w:" .. authorlink .. "|" .. txt .. "]]"
					else
						return txt
					end
				end
				local authorlink = a("authorlink")
				local authorlink_gloss = a("trans-authorlink")
				if author then
					local authorobj = parse_text_with_lang(author, author_param, a("trans-author"))
					authorobj.text = make_author_with_url(authorobj.text, authorlink)
					if authorobj.gloss and authorlink_gloss then
						authorobj.gloss = make_author_with_url(authorobj.gloss, authorlink_gloss)
					end
					add(format_text(authorobj))
				else
					-- Author separated into last name, first name. We don't currently support non-Latin-script
					-- authors separated this way and probably never will.
					local first = a("first")
					if first then
						author = last .. ", " .. first
					else
						author = last
					end
					author = make_author_with_url(author, authorlink)
					local last_gloss = a("trans-last")
					local author_gloss
					if last_gloss then
						local first_gloss = a("trans-first")
						if first_gloss then
							author_gloss = last_gloss .. ", " .. first_gloss
						else
							author_gloss = last_gloss
						end
						author_gloss = make_author_with_url(author_gloss, authorlink_gloss)
					end
					add(author)
					if author_gloss then
						add(SPACE_LBRAC)
						add(author_gloss)
						add(RBRAC)
					end
				end
			end
		end
		if args.coauthors or args.quotee then
			-- Need to set this. It's accessed (indirectly) by parse_and_format_text(), and will have the wrong value
			-- as a result of the 1, maxind loop above.
			get_full_paramname = make_get_full_paramname("")
			if args.coauthors then
				add(SEMICOLON_SPACE .. parse_and_format_text("coauthors"))
			end
			if args.quotee then
				add(", quoting " .. parse_and_format_text("quotee"))
			end
		end
	elseif args.year or args.date or args.start_year or args.start_date then
		--If no author stated but date provided, add a comma.
		add(",")
	end
	if args.author or args.last or args.quotee then
		add(",")
	end
	add(" ")

	local function has_new_title_or_ancillary_author()
		return args.chapter2 or args.title2 or
			args.tlr2 or args.trans2 or args.translator2 or args.translators2 or
			args.mainauthor2 or args.editor2 or args.editors2
	end

	local function has_new_title_or_author()
		return args["2ndauthor"] or args["2ndlast"] or has_new_title_or_ancillary_author()
	end

	local function has_newversion()
		return args.newversion or args.location2 or has_new_title_or_author()
	end
	
	-- This handles everything after displaying the author, starting with the chapter and ending with page, column and
	-- then other=. It is currently called twice: Once to handle the main portion of the citation, and once to handle a
	-- "newversion" citation. `ind` is either "" for the main portion or a number (currently only 2) for a "newversion"
	-- citation. In a few places we conditionalize on `ind` to take actions depending on its value. `sep` is the
	-- separator to display before the first item we add; see add_with_sep() below.
	local function postauthor(ind, sep)
		get_full_paramname = make_get_full_paramname(ind)
		-- Identical to a(param) except that it verifies that no space is present. Should be used for URL's.
		local function aurl(param)
			return check_url(param, a(param))
		end

		local chapter_tlr = parse_and_format_text("chapter_tlr")
		if chapter_tlr then
			add(chapter_tlr .. ", transl., ")
		end
		
		local chap, chap_param = a_with_name("chapter")
		if chap then
			local cleaned_chap = chap:gsub("<sup>[^<>]*</sup>", ""):gsub("[*+#]", "")
			local chapterurl = aurl("chapterurl")
			local function make_chapter_with_url(chap)
				if chapterurl then
					return "[" .. chapterurl .. " " .. chap .. "]"
				else
					return chap
				end
			end

			if require(number_utilities_module).get_number(cleaned_chap) then
				-- Arabic chapter number
				add(" chapter ")
				add(make_chapter_with_url(chap))
			elseif rfind(cleaned_chap, "^[mdclxviMDCLXVI]+$") and require(roman_numerals_module).roman_to_arabic(cleaned_chap, true) then
				-- Roman chapter number
				add(" chapter ")
				add(make_chapter_with_url(mw.ustring.upper(chap)))
			else
				-- Must be a chapter name
				add(" “")
				local chapterobj = parse_text_with_lang(chap, chap_param, a("trans-chapter"))
				chapterobj.text = make_chapter_with_url(chapterobj.text)
				add(format_text(chapterobj))
				add("”")
			end
			if not a("notitle") then
				add(", in ")
			end
		end

		local tlr = parse_and_format_text({"tlr", "trans", "translator", "translators"})
		local editor, editorname = parse_and_format_text_with_name("editor")
		local editors, editorsname = parse_and_format_text_with_name("editors")
		if editor and editors then
			error(("Can't specify both %s= and %s="):format(editorname, editorsname))
		end
		if a("mainauthor") then
			add(parse_and_format_text("mainauthor") .. ((tlr or editor or editors) and SEMICOLON_SPACE or ","))
		end
		
		if tlr then
			add(tlr .. ", transl." .. ((editor or editors) and SEMICOLON_SPACE or ","))
		end
		
		if editor then
			add(editor .. ", editor,")
		elseif editors then
			add(editors .. ", editors,")
		end

		-- If we're in the "newversion" code (ind ~= ""), and there's no title and no URL, then the first time we add
		-- anything after the title, we don't want to add a separating comma because the preceding text will say
		-- "republished " or "republished as " or "translated as " or similar. In all other cases, we do want to add a
		-- separating comma. We handle this using a `sep` variable whose value will generally either be "" or ", ". The
		-- add_with_sep(text) function adds the `sep` variable and then `text`, and then resets `sep` to ", " so the
		-- next time around we do add a comma to separate `text` from the preceding piece of text.
		local function add_with_sep(text)
			add(sep .. text)
			sep = ", "
		end
		local function tag_with_cite(txt)
			return "<cite>" .. txt .. "</cite>"
		end
		local title, title_param = a_with_name("title")
		if title then
			local titleobj = parse_text_with_lang(title, title_param, a("trans-title"))
			add(" ")
			add(format_text(titleobj, tag_with_cite, tag_with_cite))
			local series = parse_and_format_text("series")
			if series then
				add(" (" .. series)
				if a("seriesvolume") then
					add(SEMICOLON_SPACE .. a("seriesvolume"))
				end
				add(")")
			end
			sep = ", "
		elseif ind == "" then
			sep = ", "
			if not a("notitle") then
				add(maintenance_line("Please provide the book title or journal name"))
			end
		end
		
		if aurl("archiveurl") or aurl("url") then
			add("&lrm;<sup>[" .. (aurl("archiveurl") or aurl("url")) .. "]</sup>")
			sep = ", "
		end

		if aurl("urls") then
			add("&lrm;<sup>" .. aurl("urls") .. "</sup>")
			sep = ", "
		end

		local edition = parse_and_format_text("edition")
		if edition then
			add_with_sep(edition .. " edition")
		end

		-- Display a numeric param such as page=, volume=, column=. For each `paramname`, four params are actually
		-- recognized, e.g. for paramname == "page", the params page=, pages=, page_plain= and pageurl= are recognized
		-- and checked (or the same with an index, e.g. page2=, pages2=, page_plain2= and pageurl2= respectively if
		-- ind == "2"). Only one of the first three can be specified; an error results if more than one are given.
		-- If none are given, the return value is nil; otherwise it is a string. The numeric spec is taken directly
		-- from e.g. page_plain= if given; otherwise if e.g. pages= is given, or if page= is given and looks like a
		-- combination of numbers (i.e. it has a hyphen or dash in it, a comma, or the word " and "), it is prefixed
		-- by `singular_desc` + "s" (e.g. "pages "), otherwise it is prefixed by just `singular_desc` (e.g. "page ").
		-- (As a special case, if either e.g. page=unnumbered or pages=unnumbered is given, the numeric spec is
		-- "unnumbered page".) The resulting spec is returned directly unless e.g. pageurl= is given, in which case
		-- it is linked to the specified URL. Note that any of the specs can be foreign text, e.g. foreign numbers
		-- (including with optional inline modifiers), and such text is handled appropriately.
		local function format_numeric_param(paramname, singular_desc)
			local sgval, sgname = parse_and_format_text_with_name(paramname)
			local plval, plname = parse_and_format_text_with_name(paramname .. "s")
			local plainval, plainname = parse_and_format_text_with_name(paramname .. "_plain")
			local howmany = (sgval and 1 or 0) + (plval and 1 or 0) + (plainval and 1 or 0)
			if howmany > 1 then
				error(("Can't specify more than one of %s"):format(require(table_module).sparseConcat({sgname, plname, plainname}, ", ")))
			end
			if howmany == 0 then
				return nil
			end
			-- Merge page= and pages= and treat alike because people often mix them up in both directions.
			local val = sgval or plval
			local numspec
			if plainval then
				numspec = plainval
			elseif val == "unnumbered" then
				numspec = "unnumbered " .. singular_desc
			else
				-- in case of negative page numbers (do they exist?), don't treat as multiple pages
				local check_val = val:gsub("^%-", "")
				-- Check for hyphen, en-dash, em-dash, comma, semicolon, and Arabic-script equivalents
				if rfind(check_val, "[-–—,;،؛]") or check_val:find(" and ") then
					numspec = singular_desc .. "s " .. val
				else
					numspec = singular_desc .. " " .. val
				end
			end
			local url = a(paramname .. "url")
			if url then
				return "[" .. url .. " " .. numspec .. "]"
			else
				return numspec
			end
		end

		local volume = format_numeric_param("volume", "volume")
		if volume then
			add_with_sep(volume)
		end
		
		local issue = format_numeric_param("issue", "number")
		if issue then
			add_with_sep(issue)
		end

		-- This function handles the display of annotations like "(in French)" or "(in German; quote in Nauruan)". It
		-- takes two params PRETEXT and POSTTEXT to display before and after the annotation, respectively. These are
		-- used to insert the surrounding parens, commas, etc. They are necessary because we don't always display the
		-- annotation (in fact it's usually not displayed), and when there's no annotation, no pre-text or post-text is
		-- displayed.
		local function langhandler(pretext, posttext)
			local argslang, argslang_param
			if ind == "" then
				argslang = args.lang or args[1]
				argslang_param = 1
			else
				argslang, argslang_param = a_with_name("lang")
			end
			local worklang, worklang_param = a_with_name("worklang")
			if worklang then
				return pretext .. "in " .. format_langs(worklang, worklang_param) .. posttext
			elseif argslang and a("termlang") and argslang ~= a("termlang") then
				return pretext .. "in " .. format_langs(argslang, argslang_param) .. posttext
			elseif not argslang and ind == "" then
				return pretext .. maintenance_line("Please specify the language of the quote") .. posttext
			end
			return ""
		end

		if a("genre") then
			add(" (" .. a("genre") .. (a("format") and ", " .. a("format") or "") .. langhandler(", ", "") .. ")")
			sep = ", "
		elseif a("format") then
			add(" (" .. a("format") .. langhandler(", ", "") .. ")")
			sep = ", "
		else
			local to_insert = langhandler(" (", ")")
			if to_insert ~= "" then
				sep = ", "
				add(to_insert)
			end
		end

		if a("others") then
			add_with_sep(parse_and_format_text("others"))
		end
		local quoted_in = parse_and_format_text("quoted_in", tag_with_cite, tag_with_cite)
		if quoted_in then
			add_with_sep("quoted in " .. quoted_in)
			table.insert(tracking_categories, "Quotations using quoted-in parameter")
		end

		local city_or_location = parse_and_format_text("city") or parse_and_format_text("location")
		if a("publisher") then
			if city_or_location then
				add_with_sep(city_or_location .. "&#58;") -- colon
				sep = " "
			end
			add_with_sep(parse_and_format_text("publisher"))
		elseif city_or_location then
			add_with_sep(city_or_location)
		end

		local original = parse_and_format_text("original", tag_with_cite, tag_with_cite)
		local by = parse_and_format_text("by")
		if original or by then
			add_with_sep((a("type") or "translation") .. " of " .. (original or "original") .. (by and " by " .. by or ""))
		end

		if a("year_published") then
			add_with_sep("published " .. a("year_published"))
		end

		if ind ~= "" and has_newversion() then
			add_with_sep(a("date") or a("year") or maintenance_line("Please provide a date or year"))
		end
		
		-- From here on out, there should always be a preceding item, so we
		-- can dispense with add_with_sep() and always insert the comma.
		
		if a("bibcode") then
			add(", <small>[https://adsabs.harvard.edu/abs/" .. mw.uri.encode(a("bibcode")) .. " →Bibcode]</small>")
		end
		if a("doi") then
			add(", <small><span class=\"neverexpand\">[https://doi.org/"
				.. mw.uri.encode(a("doi") or a("doilabel") or "") .. " →DOI]</span></small>")
		end
		if a("isbn") then
			add(", <small>" .. isbn(a("isbn")) .. "</small>")
		end
		if a("issn") then
			add(", <small>" .. issn(a("issn")) .. "</small>")
		end
		if a("jstor") then
			add(", <small>[https://www.jstor.org/stable/" .. mw.uri.encode(a("jstor")) .. " →JSTOR]</small>")
		end
		if a("lccn") then
			add(", <small>" .. lccn(a("lccn")) .. "</small>")
		end
		if a("oclc") then
			add(", <small>[https://www.worldcat.org/title/" .. mw.uri.encode(a("oclc")) .. " →OCLC]</small>")
		end
		if a("ol") then
			add(", <small>[https://openlibrary.org/works/OL" .. mw.uri.encode(a("ol")) .. "/ " .. "→OL]</small>")
		end
		if a("pmid") then
			add(", <small>[https://www.ncbi.nlm.nih.gov/pubmed/" .. mw.uri.encode(a("pmid")) .. " →PMID]</small>")
		end
		if a("ssrn") then
			add(", <small>[https://ssrn.com/abstract=" .. mw.uri.encode(a("ssrn")) .. " →SSRN]</small>")
		end
		if a("id") then
			add(", <small>" .. a("id") .. "</small>")
		end
		if aurl("archiveurl") then
			add(", archived from ")
			local url = aurl("url")
			if not url then
				-- attempt to infer original URL from archive URL; this works at
				-- least for Wayback Machine (web.archive.org) URL's
				url = rmatch(aurl("archiveurl"), "/(https?:.*)$")
				if not url then
					error("When archiveurl" .. ind .. "= is specified, url" .. ind .. "= must also be included")
				end
			end
			add("[" .. url .. " the original] on ")
			if a("archivedate") then
				add(format_date(a("archivedate")))
			elseif (string.sub(a("archiveurl"), 1, 28) == "https://web.archive.org/web/") then
				-- If the archive is from the Wayback Machine, then it already contains the date
				-- Get the date and format into ISO 8601
				local wayback_date = string.sub(a("archiveurl"), 29, 29+7)
				wayback_date = string.sub(wayback_date, 1, 4) .. "-" .. string.sub(wayback_date, 5, 6) .. "-" .. string.sub(wayback_date, 7, 8)
				add(format_date(wayback_date))
			else
				error("When archiveurl" .. ind .. "= is specified, archivedate" .. ind .. "= must also be included")
			end
		end
		if a("accessdate") then
			--Otherwise do not display here, as already used as a fallback for missing date= or year= earlier.
			if (a("date") or a("nodate") or a("year")) and not a("archivedate") then
				add(", retrieved " .. format_date(a("accessdate")))
			end
		end
		if a("laysummary") then
			add(", [" .. a("laysummary") .. " lay summary]")
			if a("laysource") then
				-- FIXME: What is laysource? Can it be foreign language text?
				add("&nbsp;–&nbsp;''" .. parse_and_format_text("laysource") .. "''")
			end
		end
		if a("laydate") then
			add(" (" .. format_date(a("laydate")) .. ")")
		end
		local section, section_param = a_with_name("section")
		if section then
			local sectionurl = aurl("sectionurl")
			local sectionobj = parse_text_with_lang(section, section_param)
			if sectionurl then
				sectionobj.text = "[" .. sectionurl .. " " .. sectionobj.text .. "]"
			end
			add(", " .. format_text(sectionobj))
		end

		-- Wrapper around format_numeric_param that inserts the formatted text with optional preceding text.
		local function handle_numeric_param(paramname, singular_desc, pretext)
			local numspec = format_numeric_param(paramname, singular_desc)
			if numspec then
				add((pretext or "") .. numspec)
			end
		end

		handle_numeric_param("line", "line", ", ")
		handle_numeric_param("page", "page", ", ")
		handle_numeric_param("column", "column", ", ")
		-- FIXME: Does this make sense? What is other=?
		local other = parse_and_format_text("other")
		if other then
			add(", " .. other)
		end
	end

	-- Display all the text that comes after the author, for the main portion.
	postauthor("", "")

	local sep
	
	-- If there's a "newversion" section, add the new-version text.
	if has_newversion() then
		--Test for new version of work.
		add(SEMICOLON_SPACE)
		if args.newversion then -- newversion= is intended for English text, e.g. "quoted in" or "republished as".
			add(args.newversion)
		elseif not args.edition2 then
			if has_new_title_or_author() then
				add("republished as")
			else
				add("republished")
			end
		end
		add(" ")
		sep = ""
	else
		sep = ", "
	end

	-- Add the author(s).
	if args["2ndauthor"] or args["2ndlast"] then
		add(" ")
		local authorlink = args["2ndauthorlink"]
		local function make_author_with_url(txt)
			if authorlink then
				return "[[w:" .. authorlink .. "|" .. txt .. "]]"
			else
				return txt
			end
		end
		local author = args["2ndauthor"]
		if author then
			local authorobj = parse_text_with_lang(author, "2ndauthor")
			authorobj.text = make_author_with_url(authorobj.text)
			add(format_text(authorobj))
		else
			local last = args["2ndlast"]
			local first = args["2ndfirst"]
			-- Author separated into last name, first name. We don't currently support non-Latin-script
			-- authors separated this way and probably never will.
			if first then
				author = last .. ", " .. first
			else
				author = last
			end
			author = make_author_with_url(author)
			add(author)
		end

		-- FIXME, we should use sep = ", " here too and fix up the handling
		-- of chapter/mainauthor/etc. in postauthor() to use add_with_sep().
		if has_new_title_or_ancillary_author() then
			add(", ")
			sep = ""
		else
			sep = ", "
		end
	end

	-- Display all the text that comes after the author, for the "newversion" section.
	postauthor(2, sep)

	add(":")

	-- Concatenate output portions to form output text.
	local output_text = table.concat(output)

	-- Remainder of code handles adding categories. We add one or more of the
	-- following categories:
	--
	-- 1. [[Category:LANG terms with quotations]], based on the first language
	--    code in termlang= or lang=. Not added to non-main-namespace pages
	--    except for Reconstruction: and Appendix:. Not added if lang= is
	--    missing or nocat= is given.
	-- 2. [[Category:Quotations with missing lang parameter]], if lang= isn't
	--    specified. Added to some non-main-namespace pages, but not talk pages,
	--    user pages, or Wiktionary discussion pages (e.g. Grease Pit, Tea Room,
	--    Beer Parlour).
	-- 3. [[Category:Quotations using nocat parameter]], if nocat= is given.
	--    Added to the same pages as for [[Category:Quotations with missing lang parameter]].
	
	local categories = {}

	local langcode = args.termlang or argslang or "und"
	langcode = rsplit(langcode, ",")[1]
	local lang = require(languages_module).getByCode(langcode, true)

	if args.nocat then
		table.insert(tracking_categories, "Quotations using nocat parameter")
	end
	if argslang then
		if lang and not args.nocat then
			table.insert(categories, lang:getCanonicalName() .. " terms with quotations")
		end
	else
		table.insert(tracking_categories, "Quotations with missing lang parameter")
	end

	local FULLPAGENAME = mw.title.getCurrentTitle().fullText
	return output_text .. (not lang and "" or
		require(utilities_module).format_categories(categories, lang) ..
		require(utilities_module).format_categories(tracking_categories, lang, nil, nil,
			not require(usex_templates_module).page_should_be_ignored(FULLPAGENAME)))
end


-- External interface, meant to be called from a template.
-- FIXME: Remove this in favor of using quote_t.
function export.source_t(frame)
	local parent_args = frame:getParent().args
	local args = clone_args(frame.args, parent_args, "include direct", "include parent")
	local newret = export.source(args)
	if test_new_code then
		local oldret = frame:expandTemplate{title="quote-meta/source", args=args}
		local function canon(text)
			text = rsub(rsub(text, "&#32;", " "), " ", "{SPACE}")
			text = rsub(rsub(text, "%[", "{LBRAC}"), "%]", "{RBRAC}")
			text = rsub(text, "`UNIQ%-%-nowiki%-[0-9A-F]+%-QINU`", "`UNIQ--nowiki-{REPLACED}-QINU`")
			return text
		end
		local canon_newret = canon(newret)
		local canon_oldret = canon(oldret)
		if canon_newret ~= canon_oldret then
			require(debug_track_module)("quote-source/diff")
			if test_new_code_with_errors then
				error("different: <<" .. canon_oldret .. ">> vs <<" .. canon_newret .. ">>")
			end
		else
			require(debug_track_module)("quote-source/same")
			if test_new_code_with_errors then
				error("same")
			end
		end
		return oldret
	end
	return newret
end


-- External interface, meant to be called from a template. Replaces {{quote-meta}} and meant to be the primary
-- interface for {{quote-*}} templates.
function export.quote_t(frame)
	local parent_args = frame:getParent().args
	local args = clone_args(frame.args, parent_args, "include direct", "include parent")
	local deprecated = args.lang

	local function yesno(val)
		if not val then
			return false
		end
		if val == "on" then
			return true
		end
		return require(yesno_module)(val)
	end

	args.nocat = yesno(args.nocat)
	args.brackets = yesno(args.brackets)

	local function process_fallback(val, fallback_params)
		if val then
			return val
		end
		if fallback_params then
			fallback_params = rsplit(fallback_params, ",")
			for _, fallback_param in ipairs(fallback_params) do
				-- If the param is a number, we need to convert to an integer before indexing.
				fallback_param = tonumber(fallback_param) or fallback_param
				if args[fallback_param] then
					return args[fallback_param]
				end
			end
		end
		return nil
	end

	local text = process_fallback(args.text or args.passage, args.text_fallback)
	local gloss = process_fallback(args.t or args.gloss or args.translation, args.t_fallback)

	local parts = {}
	local function ins(text)
		table.insert(parts, text)
	end

	local indent = args.i1 or args.indent
	if indent then
		ins(indent)
		ins(" ")
	end
	ins('<div class="citation-whole"><span class="cited-source">')
	ins(export.source(args))
	ins("</span><dl><dd>")
	-- If any quote-related args are present, display the actual quote; otherwise, display nothing.
	local tr = args.tr or args.transliteration
	local ts = args.ts or args.transcription
	local norm = args.norm or args.normalization
	local sc = args.sc and require(scripts_module).getByCode(args.sc, "sc") or nil
	local normsc = args.normsc == "auto" and args.normsc or args.normsc and require(scripts_module).getByCode(args.normsc, "normsc") or nil
	if text or gloss or tr or ts or norm then
		local langcodes = args[1] or args.lang
		local langcode = langcodes and rsplit(langcodes, ",")[1] or nil

		local usex_data = {
			-- Pass "und" here rather than cause an error; there will be an error on mainspace, Citations, etc. pages
			-- in any case in source() if the language is omitted.
			lang = require(languages_module).getByCode(langcode or "und", 1),
			usex = text,
			sc = sc,
			translation = gloss,
			normalization = norm,
			normsc = normsc,
			transliteration = tr,
			transcription = ts,
			brackets = args.brackets,
			substs = args.subst,
			lit = args.lit,
			footer = args.footer,
			-- pass true here because source() already adds 'LANG terms with quotations'
			nocat = true,
			quote = "quote-meta",
		}
		ins(require(usex_module).format_usex(usex_data))
	end
	ins("</dd></dl></div>")
	local retval = table.concat(parts)
	return deprecated and frame:expandTemplate{title = "check deprecated lang param usage", args = {retval, lang = args.lang}} or retval
end


-- External interface, meant to be called from a template.
function export.call_quote_template(frame)
	local iparams = {
		["template"] = {},
		["textparam"] = {},
		["pageparam"] = {},
		["allowparams"] = {list = true},
		["propagateparams"] = {list = true},
	}
	local iargs, other_direct_args = require(parameters_module).process(frame.args, iparams, "return unknown", "quote", "call_quote_template")
	local direct_args = {}
	for pname, param in pairs(other_direct_args) do
		direct_args[pname] = ine(param)
	end

	local function process_paramref(paramref)
		if not paramref then
			return {}
		end
		local params = rsplit(paramref, "%s*,%s*")
		for i, param in ipairs(params) do
			if rfind(param, "^[0-9]+$") then
				param = tonumber(param)
			end
			params[i] = param
		end
		return params
	end
	
	local function fetch_param(source, params)
		for _, param in ipairs(params) do
			if source[param] then
				return source[param]
			end
		end
		return nil
	end
	
	local params = {
		["text"] = {},
		["passage"] = {},
		["footer"] = {},
		["brackets"] = {},
	}
	local textparams = process_paramref(iargs.textparam)
	for _, param in ipairs(textparams) do
		params[param] = {}
	end
	local pageparams = process_paramref(iargs.pageparam)
	if #pageparams > 0 then
		params["page"] = {}
		params["pages"] = {}
		for _, param in ipairs(pageparams) do
			params[param] = {}
		end
	end

	local parent_args = frame:getParent().args
	local allow_all = false
	for _, allowspec in ipairs(iargs.allowparams) do
		for _, allow in ipairs(rsplit(allowspec, "%s*,%s*")) do
			local param = rmatch(allow, "^(.*):list$")
			if param then
				if rfind(param, "^[0-9]+$") then
					param = tonumber(param)
				end
				params[param] = {list = true}
			elseif allow == "*" then
				allow_all = true
			else
				if rfind(allow, "^[0-9]+$") then
					allow = tonumber(allow)
				end
				params[allow] = {}
			end
		end
	end

	local params_to_propagate = {}
	for _, propagate_spec in ipairs(iargs.propagateparams) do
		for _, param in ipairs(process_paramref(propagate_spec)) do
			table.insert(params_to_propagate, param)
			params[param] = {}
		end
	end

	local args = require(parameters_module).process(parent_args, params, allow_all, "quote", "call_quote_template")
	parent_args = require(table_module).shallowcopy(parent_args)

	if textparams[1] ~= "-" then
		other_direct_args.passage = args.text or args.passage or fetch_param(args, textparams)
	end
	if #pageparams > 0 and pageparams[1] ~= "-" then
		other_direct_args.page = fetch_param(args, pageparams) or args.page or nil
		other_direct_args.pages = args.pages
	end
	if args.footer then
		other_direct_args.footer = frame:expandTemplate { title = "small", args = {args.footer} }
	end
	other_direct_args.brackets = args.brackets
	if not other_direct_args.authorlink and not other_direct_args.author:find("[%[<]") then
		other_direct_args.authorlink = other_direct_args.author
	end
	for _, param in ipairs(params_to_propagate) do
		if args[param] then
			other_direct_args[param] = args[param]
		end
	end

	return frame:expandTemplate { title = iargs.template or "quote-book", args = other_direct_args }
end

local paramdoc_param_replacements = {
	passage = {
		param_with_synonym = '<<synonym>>, {{para|text}}, or {{para|passage}}',
		param_no_synonym = '{{para|text}} or {{para|passage}}',
		text = [=[
* <<params>> – the passage to be quoted.]=],
	},
	page = {
		param_with_synonym = '<<synonym>> or {{para|page}}, or {{para|pages}}',
		param_no_synonym = '{{para|page}} or {{para|pages}}',
		text = [=[
* <<params>> – '''mandatory in some cases''': the page number(s) quoted from. When quoting a range of pages, note the following:
** Separate the first and last pages of the range with an [[en dash]], like this: {{para|pages|10–11}}.
** You must also use {{para|pageref}} to indicate the page to be linked to (usually the page on which the Wiktionary entry appears).
: This parameter must be specified to have the template link to the online version of the work.]=]
	},
	page_with_roman_preface = {
		param_with_synonym = {"inherit", "page"},
		param_no_synonym = {"inherit", "page"},
		text = [=[
* <<params>> – '''mandatory in some cases''': the page number(s) quoted from. If quoting from the preface, specify the page number(s) in lowercase Roman numerals. When quoting a range of pages, note the following:
** Separate the first and last page number of the range with an [[en dash]], like this: {{para|pages|10–11}} or {{para|pages|iii–iv}}.
** You must also use {{para|pageref}} to indicate the page to be linked to (usually the page on which the Wiktionary entry appears).
: This parameter must be specified to have the template link to the online version of the work.]=]
	},
	chapter = {
		param_with_synonym = '<<synonym>> or {{para|chapter}}',
		param_no_synonym = '{{para|chapter}}',
		text = [=[
* <<params>> – the name of the chapter quoted from.]=],
	},
	roman_chapter = {
		param_with_synonym = {"inherit", "chapter"},
		param_no_synonym = {"inherit", "chapter"},
		text = [=[
* <<params>> – the chapter number quoted from in uppercase Roman numerals.]=],
	},
	arabic_chapter = {
		param_with_synonym = {"inherit", "chapter"},
		param_no_synonym = {"inherit", "chapter"},
		text = [=[
* <<params>> – the chapter number quoted from in Arabic numerals.]=],
	},
	trailing_params = {
		text = [=[
* {{para|footer}} – a comment on the passage quoted.
* {{para|brackets}} – use {{para|brackets|on}} to surround a quotation with [[bracket]]s. This indicates that the quotation either contains a mere mention of a term (for example, “some people find the word '''''manoeuvre''''' hard to spell”) rather than an actual use of it (for example, “we need to '''manoeuvre''' carefully to avoid causing upset”), or does not provide an actual instance of a term but provides information about related terms.]=],
	}
}

function export.paramdoc(frame)
	local params = {
		[1] = {},
	}

	local parargs = frame:getParent().args
	local args = require(parameters_module).process(parargs, params, nil, "quote", "paramdoc")

	local text = args[1]

	local function do_param_with_optional_synonym(param, text_to_sub, paramtext_synonym, paramtext_no_synonym)
		local function sub_param(synonym)
			local subbed_paramtext
			if synonym then
				subbed_paramtext = rsub(paramtext_synonym, "<<synonym>>", "{{para|" .. synonym .. "}}")
			else
				subbed_paramtext = paramtext_no_synonym
			end
			return frame:preprocess(rsub(text_to_sub, "<<params>>", subbed_paramtext))
		end
		text = rsub(text, "<<" .. param .. ">>", function() return sub_param() end)
		text = rsub(text, "<<" .. param .. ":(.-)>>", sub_param)
	end

	local function fetch_text(param_to_replace, key)
		local spec = paramdoc_param_replacements[param_to_replace]
		local val = spec[key]
		if type(val) == "string" then
			return val
		end
		if type(val) == "table" and val[1] == "inherit" then
			return fetch_text(val[2], key)
		end
		error("Internal error: Unrecognized value for param '" .. param_to_replace .. "', key '" .. key .. "': "
			.. mw.dumpObject(val))
	end

	for param_to_replace, spec in pairs(paramdoc_param_replacements) do
		local function fetch(key)
			return fetch_text(param_to_replace, key)
		end

		if not spec.param_no_synonym then
			-- Text to substitute directly.
			text = rsub(text, "<<" .. param_to_replace .. ">>", function() return frame:preprocess(fetch("text")) end)
		else
			do_param_with_optional_synonym(param_to_replace, fetch("text"), fetch("param_with_synonym"),
				fetch("param_no_synonym"))
		end
	end

	-- Remove final newline so template code can add a newline after invocation
	text = text:gsub("\n$", "")
	return text
end

return export

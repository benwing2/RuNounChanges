--[=[
	This module contains functions to implement quote-* templates.

	Author: Benwing2; conversion into Lua of {{quote-meta/source}} template,
	written by Sgconlaw with some help from Erutuon and Benwing2.

	You should replace a call to {{quote-meta/source|...}} with
	{{#invoke:quote-meta|quote_meta_source_t|...}}, except that you only
	need to pass in arguments that aren't direct pass-throughs. For example,
	{{quote-book}} invoked {{quote-meta/source}} like this:
	
	{{quote-meta/source
    | last           = {{{last|}}}
    | first          = {{{first|}}}
    | author         = {{{author|{{{2|}}}}}}
    | authorlink     = {{{authorlink|}}}
    | last2          = {{{last2|}}}
    | first2         = {{{first2|}}}
    | author2        = {{{author2|}}}
    | authorlink2    = {{{authorlink2|}}}
	...
    | author5        = {{{author5|}}}
    | authorlink5    = {{{authorlink5|}}}
    | coauthors      = {{{coauthors|}}}
    | quotee         = {{{quotee|}}}
    | quoted_in      = {{{quoted_in|}}}
    | chapter        = {{{chapter|{{{entry|}}}}}}
    | chapterurl     = {{{chapterurl|{{{entryurl|}}}}}}
    | trans-chapter  = {{{trans-chapter|{{{trans-entry|}}}}}}
    | translator     = {{{trans|{{{translator|{{{translators|}}}}}}}}}
    | editor         = {{{editor|}}}
    | editors        = {{{editors|}}}
    ...
    }}
    
    This can be reduced to a call to the module like this:
    
	{{#invoke:quote-meta|quote_meta_source_t
    | author         = {{{author|{{{2|}}}}}}
    | chapter        = {{{chapter|{{{entry|}}}}}}
    | chapterurl     = {{{chapterurl|{{{entryurl|}}}}}}
    | trans-chapter  = {{{trans-chapter|{{{trans-entry|}}}}}}
    | translator     = {{{trans|{{{translator|{{{translators|}}}}}}}}}
    ...
    }}

	None of the arguments that are simple passthroughs need to be passed in,
	because the quote_meta_source_t() function reads both the arguments
	passed to it *and* the arguments passed to the parent template, with the
	former overriding the latter.

	The module code should work like the template code, except that in a few
	situations I fixed apparent bugs in the template code in the process of
	porting.
]=]

local export = {}

local m_time = require("Module:time")
local m_italics = require("Module:italics")
local m_languages = require("Module:languages")
local m_utilities = require("Module:utilities")

local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split

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
		require("Module:check isxn").check_isbn(text, "&nbsp;<span class=\"error\" style=\"font-size:88%\">Invalid&nbsp;ISBN</span>[[Category:Pages with ISBN errors]]")
end

local function issn(text)
	return "[[w:International Standard Serial Number|ISSN]] [http://www.worldcat.org/issn/" .. text .. " " .. text .. "]" ..
		require("Module:check isxn").check_issn(text, "&nbsp;<span class=\"error\" style=\"font-size:88%\">Invalid&nbsp;ISSN</span>[[Category:Pages with ISSN errors]]")
end

local function format_date(text)
	return mw.getCurrentFrame():callParserFunction{name="#formatdate", args=text}
end

local function format_langs(langs)
	local langcodes = rsplit(langs, ",")
	local langnames = {}
	for _, langcode in ipairs(langcodes) do
		local lang = m_languages.getByCode(langcode) or m_languages.err(langcode, 1)
		table.insert(langnames, lang:getCanonicalName())
	end
	if #langnames == 1 then
		return langnames[1]
	elseif #langnames == 2 then
		return langnames[1] .. " and " .. langnames[2]
	else
		local retval = {}
		for i, langname in ipairs(langnames) do
			table.insert(retval, langname)
			if i <= #langnames - 2 then
				table.insert(retval, ", ")
			elseif i == #langnames - 1 then
				table.insert(retval, "<span class=\"serial-comma\">,</span><span class=\"serial-and\"> and</span> ")
			end
		end
		return table.concat(retval, "")
	end
end

-- Fancy version of ine() (if-not-empty). Converts empty string to nil,
-- but also strips leading/trailing space and then single or double quotes,
-- to allow for embedded spaces.
-- FIXME! Copied directly from ru-noun. Move to utility package.
local function ine(arg)
	if not arg then return nil end
	arg = rsub(arg, "^%s*(.-)%s*$", "%1")
	if arg == "" then return nil end
	local inside_quotes = rmatch(arg, '^"(.*)"$')
	if inside_quotes then
		return inside_quotes
	end
	inside_quotes = rmatch(arg, "^'(.*)'$")
	if inside_quotes then
		return inside_quotes
	end
	return arg
end

-- Clone frame's and parent's args while also assigning nil to empty strings.
local function clone_args(frame)
	local args = {}
	for pname, param in pairs(frame:getParent().args) do
		args[pname] = ine(param)
	end
	for pname, param in pairs(frame.args) do
		args[pname] = ine(param)
	end
	return args
end

-- Implementation of {{quote-meta/source}}.
function export.quote_meta_source(args)
	local output = {}
	-- Add text to the output. The text goes into a list, and we concatenate
	-- all the list components together at the end.
	local function add(text)
		table.insert(output, text)
	end
	if args.brackets == "on" then
		add("[")
	end
	add(m_time.quote_impl(args))
	if args.origdate then
		add(" [" .. args.origdate .. "]")
	elseif args.origyear and args.origmonth then
		add(" [" .. args.origmonth .. " " .. args.origyear .. "]")
	elseif args.origyear then
		add(" [" .. args.origyear .. "]")
	end
	
	if args.author or args.last then
		for i=1,5 do
			local suf = i == 1 and "" or i
			-- Return the argument named PARAM, possibly with a suffix added
			-- (e.g. 2 for author2, 3 for last3). The suffix is either ""
			-- (an empty string) for the first set of params (author, last,
			-- first, etc.) or a number for further sets of params (author2,
			-- last2, first2, etc.).
			local function a(param)
				return args[param .. suf]
			end
			if a("author") or a("last") then
				-- If first author, output a comma unless {{{nodate}}} used.
				if i == 1 and not args.nodate then
					add(", ")
				end
				-- If not first author, output a semicolon to separate from preceding authors.
				add(i == 1 and " " or "&#59; ") -- &#59; = semicolon
				if a("authorlink") then
					add("[[w:" .. a("authorlink") .. "|")
				end
				if a("author") then
					add(a("author"))
				elseif a("last") then
					add(a("last"))
					if a("first") then
						add(", " .. a("first"))
					end
				end
				if a("authorlink") then
					add("]]")
				end
			end
		end
		if args.coauthors then
			add("&#59; " .. args.coauthors)
		end
		if args.quotee then
			add(", quoting " .. args.quotee)
		end
	elseif args.year or args.date or args.start_year or args.start_date then
		--If no author stated but date provided, add a comma.
		add(",")
	end
	if args.author or args.last or args.quotee then
		add(",")
	end
	add(" ")

	local function has_newversion()
		return args.newversion or args.location2 or args["2ndauthor"] or args["2ndlast"] or
			args.translator2 or args.editor2
	end

	local function has_newtitleauthor()
		return args["2ndauthor"] or args["2ndlast"] or args.translator2 or args.editor2 or args.title2
	end

	-- This handles everything after displaying the author, starting with the
	-- chapter and ending with page, column and then other=. It is currently
	-- called twice: Once to handle the main portion of the citation, and once
	-- to handle a "newversion" citation. SUF is either "" for the main portion
	-- or a number (currently only 2) for a "newversion" citation. In a few
	-- places we conditionalize on SUF to take actions depending on its value.
	local function postauthor(suf)
		-- Return the argument named PARAM, possibly with a suffix added
		-- (e.g. 2 for chapter2). The suffix is either "" (an empty string)
		-- for the first set of params (chapter, title, translator, etc.)
		-- or a number for further sets of params (chapter2, title2,
		-- translator2, etc.).
		local function a(param)
			return args[param .. suf]
		end
		if a("chapter") then
			if require("Module:number-utilities").get_number(a("chapter")) then
				-- Arabic chapter number
				add(" chapter ")
				if a("chapterurl") then
					add("[" .. a("chapterurl") .. " " .. a("chapter") .. "]")
				else
					add(a("chapter"))
				end
			elseif require("Module:roman numerals").roman_to_arabic(a("chapter"), true) then
				-- Roman chapter number
				add(" chapter ")
				local uchapter = mw.ustring.upper(a("chapter"))
				if a("chapterurl") then
					add("[" .. a("chapterurl") .. " " .. uchapter .. "]")
				else
					add(uchapter)
				end
			else
				-- Must be a chapter name
				add(" “")
				local toinsert
				if a("chapterurl") then
					toinsert = "[" .. a("chapterurl") .. " " .. a("chapter") .. "]"
				else
					toinsert = a("chapter")
				end
				add(m_italics.unitalicize_brackets(toinsert))
				if a("trans-chapter") then
					add(" &#91;" .. m_italics.unitalicize_brackets(a("trans-chapter")) .. "&#93;")
				end
				add("”")
			end
			if not a("notitle") then
				add(", in ")
			end
		end
		
		if a("mainauthor") then
			add(a("mainauthor") .. ((a("translator") or a("editor") or a("editors")) and "&#59; " or ","))
		end
		
		if a("translator") then
			add(a("translator") .. ", transl." .. ((a("editor") or a("editors")) and "&#59; " or ","))
		end
		
		if a("editor") then
			add(a("editor") .. ", editor,")
		elseif a("editors") then
			add(a("editors") .. ", editors,")
		end

		if a("title") then
			add(" <cite>" .. m_italics.unitalicize_brackets(a("title")) .. "</cite>")
			if a("trans-title") then
				add(" [<cite>" .. m_italics.unitalicize_brackets(a("trans-title")) .. "</cite>]")
			end
			if a("series") then
				add(" " .. a("series"))
				if a("seriesvolume") then
					add("&#59; " .. a("seriesvolume"))
				end
			end
		elseif suf == "" and not a("notitle") then
			maintenance_line("Please provide the book title or journal name")
		end
		
		if a("url") then
			add("&lrm;<sup>[" .. (a("archiveurl") or a("url")) .. "]</sup>")
		end

		if a("volume") then
			add(", volume " .. a("volume"))
		elseif a("volume_plain") then
			add(", " .. a("volume_plain"))
		end
		
		if a("issue") then
			add(", number " .. a("issue"))
		end

		-- This function handles the display of annotations like "(in French)"
		-- or "(in German; quote in Nauruan)". It takes two params PRETEXT and
		-- POSTTEXT to display before and after the annotation, respectively.
		-- (These are used to insert the surrounding parens, commas, etc.
		-- They are necessary because e.g. if |lang=en and |worklang= is missing,
		-- no annotation and hence no pre-text or post-text is displayed.)
		local function langhandler(pretext, posttext)
			if a("worklang") then
				return pretext .. "in " .. format_langs(a("worklang")) .. (
					a("lang") and "&#59; quote in " .. format_langs(a("lang")) or "")
					.. posttext
			elseif a("lang") then
				if a("lang") ~= "en" then
					return pretext .. "in " .. format_langs(a("lang")) .. posttext
				end
			elseif suf == "" then
				return pretext .. maintenance_line("Please specify the language of the quote") .. posttext
			end
			return ""
		end

		if a("genre") then
			add(" (" .. a("genre") .. (a("format") and ", " .. a("format") or "") .. langhandler(", ", "") .. ")")
		elseif a("format") then
			add(" (" .. a("format") .. langhandler(", ", "") .. ")")
		else
			add(langhandler(" (", ")"))
		end

		if a("others") then
			add(", " .. a("others"))
		end
		if a("edition") then
			add(", " .. a("edition") .. " edition")
		end
		if a("quoted_in") then
			add(", quoted in " .. a("quoted_in"))
		end

		if a("publisher") then
			if a("city") or a("location") then
				add(", " .. (a("city") or a("location")) .. "&#58;") -- colon
			else
				add(",")
			end
			add(" " .. a("publisher"))
		elseif a("city") or a("location") then
			add(", " .. (a("city") or a("location")))
		end

		if a("original") then
			add(", " .. (a("type") or "translation") .. " of <cite>" .. a("original")
				.. "</cite>" .. (a("by") and " by " .. a("by") or ""))
		elseif a("by") then
			add(", " .. (a("type") or "translation") .. " of original by " .. a("by"))
		end

		if a("year_published") then
			add(", published " .. a("year_published"))
		end

		if suf ~= "" and has_newversion() then
			--Test for new version of work.
			if has_newtitleauthor() then
				add(", ")
			end
			add(a("date") or a("year") or maintenance_line("Please provide a date or year"))
		end
			
		if a("bibcode") then
			add(", <small>[[w:Bibcode|Bibcode]]:&nbsp;[http://adsabs.harvard.edu/abs/"
				.. mw.uri.encode(a("bibcode")) .. " " .. a("bibcode") .. "]</small>")
		end
		if a("doi") then
			add(", <small>[[w:Digital object identifier|DOI]]:<span class=\"neverexpand\">[https://doi.org/"
				.. mw.uri.encode(a("doi") or a("doilabel") or "")
				.. " <nowiki>" .. a("doi") .. "</nowiki>]</span></small>")
		end
		if a("isbn") then
			add(", <small>" .. isbn(a("isbn")) .. "</small>")
		end
		if a("issn") then
			add(", <small>" .. issn(a("issn")) .. "</small>")
		end
		if a("jstor") then
			add(", <small>[[w:JSTOR|JSTOR]] [http://www.jstor.org/stable/" ..
				mw.uri.encode(a("jstor")) .. " " .. a("jstor") .. "]</small>")
		end
		if a("lccn") then
			add(", <small>[[w:Library of Congress Control Number|LCCN]] [http://lccn.loc.gov/" ..
				mw.uri.encode(a("lccn")) .. " " .. a("lccn") .. "]</small>")
		end
		if a("oclc") then
			add(", <small>[[w:OCLC|OCLC]] [http://worldcat.org/oclc/" ..
				mw.uri.encode(a("oclc")) .. " " .. a("oclc") .. "]</small>")
		end
		if a("ol") then
			add(", <small>[[w:Open Library|OL]] [https://openlibrary.org/works/OL" ..
				mw.uri.encode(a("ol")) .. "/ " .. a("ol") .. "]</small>")
		end
		if a("pmid") then
			add(", <small>[[w:PubMed Identifier|PMID]] [http://www.ncbi.nlm.nih.gov/pubmed/" ..
				mw.uri.encode(a("pmid")) .. " " .. a("pmid") .. "]</small>")
		end
		if a("ssrn") then
			add(", <small>[[w:Social Science Research Network|SSRN]] [http://ssrn.com/abstract=" ..
				mw.uri.encode(a("ssrn")) .. " " .. a("ssrn") .. "]</small>")
		end
		if a("id") then
			add(", <small>" .. a("id") .. "</small>")
		end
		if a("archiveurl") then
			add(", archived from [" .. a("archiveurl") .. " the original] on ")
			if a("archivedate") then
				add(format_date(a("archivedate")))
			else
				add(maintenance_line("Please provide the date"))
			end
		end
		if a("accessdate") then
			--Otherwise do not display here, as already used as a fallback for missing date= or year= earlier.
			if a("date") or a("nodate") or a("year") then
				add(", retrieved " .. format_date(a("accessdate")))
			end
		end
		if a("laysummary") then
			add(", [" .. a("laysummary") .. " lay summary]")
			if a("laysource") then
				add("&nbsp;–&nbsp;''" .. a("laysource") .. "''")
			end
		end
		if a("laydate") then
			add(" (" .. format_date(a("laydate")) .. ")")
		end
		if a("section") then
			add(", " .. (a("sectionurl") and "[" .. a("sectionurl") .. " " .. a("section") .. "]" or a("section")))
		end
		if a("line") then
			add(", line " .. a("line"))
		elseif a("lines") then
			add(", lines " .. a("lines"))
		end
		if a("page") or a("pages") then
			local function page_or_pages()
				if a("pages") then
					return "pages " .. a("pages")
				else
					return "page " .. a("page")
				end
			end
			add(", " .. (a("pageurl") and "[" .. a("pageurl") .. " " .. page_or_pages() .. "]" or page_or_pages()))
		end
		if a("column") or a("columns") then
			local function column_or_columns()
				if a("columns") then
					return "columns " .. a("columns")
				else
					return "column " .. a("column")
				end
			end
			add(", " .. (a("columnurl") and "[" .. a("columnurl") .. " " .. column_or_columns() .. "]" or column_or_columns()))
		end
		if a("other") then
			add(", " .. a("other"))
		end
	end

	-- display all the text that comes after the author, for the main portion.
	postauthor("")

	-- If there's a "newversion" section, add the new-version text.
	if has_newversion() then
		--Test for new version of work.
		add("&#59; ") -- semicolon
		if args.newversion then
			add(args.newversion)
		elseif not args.edition2 then
			if has_newtitleauthor() then
				add("republished as ")
			else
				add("republished ")
			end
		end
	end

	-- Add the author(s).
	if args["2ndauthor"] or args["2ndlast"] then
		add(" ")
		if args["2ndauthorlink"] then
			add("[[w:" .. args["2ndauthorlink"] .. "|")
		end
		if args["2ndauthor"] then
			add(args["2ndauthor"])
		elseif args["2ndlast"] then
			add(args["2ndlast"])
			if args["2ndfirst"] then
				add(", " .. args["2ndfirst"])
			end
		end
		if args["2ndauthorlink"] then
			add("]]")
		end
		-- FIXME, we need a better way of handling commas.
		if args.chapter2 or args.mainauthor2 or args.translator2 or args.editor2 or args.editors2 or args.title2 then
			add(", ")
		end
	end

	-- display all the text that comes after the author, for the "newversion"
	-- section.
	postauthor(2)

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
	-- 4. [[Category:Quotations using archiveurl without archivedate]],
	--    if archiveurl= is specified but not archivedate=. Added to the same
	--    pages as for [[Category:Quotations with missing lang parameter]].
	-- 5. [[Category:Quotation templates using both date and year]], if both
	--    date= and year= are specified. Added to the same pages as for
	--    [[Category:Quotations with missing lang parameter]].
	
	local tracking_categories = {}
	local categories = {}
	local NAMESPACE = mw.title.getCurrentTitle().nsText

	local langcode = args.termlang or args.lang or "und"
	langcode = rsplit(langcode, ",")[1]
	local lang = m_languages.getByCode(langcode)
	if not lang and NAMESPACE ~= "Template" then
		error("The language code \"" .. langcode .. "\" is not valid.")
	end

	if args.nocat then
		table.insert(tracking_categories, "Quotations using nocat parameter")
	end
	if args.lang then
		if lang and not args.nocat then
			table.insert(categories, lang:getCanonicalName() .. " terms with quotations")
		end
	else
		table.insert(tracking_categories, "Quotations with missing lang parameter")
	end
	if args.archiveurl and not args.archivedate then
		table.insert(tracking_categories, "Quotations using archiveurl without archivedate")
	end
	if args.date and args.year then
		table.insert(tracking_categories, "Quotation templates using both date and year")
	end

	local FULLPAGENAME = mw.title.getCurrentTitle().fullText
	return output_text .. (not lang and "" or
		m_utilities.format_categories(categories, lang) ..
		m_utilities.format_categories(tracking_categories, lang, nil, nil,
			not require("Module:usex/templates").page_should_be_ignored(FULLPAGENAME)))
end

-- External interface, meant to be called from a template.
function export.quote_meta_source_t(frame)
	local args = clone_args(frame)
	return export.quote_meta_source(args)
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:

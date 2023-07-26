--[=[
	This module contains functions to implement quote-* templates.

	Author: Benwing2; conversion into Lua of {{quote-meta/source}} template,
	written by Sgconlaw with some help from Erutuon and Benwing2.

	The main interface is quote_t(). Note that the source display is handled by source(), which reads both the arguments passed to it *and*
	the arguments passed to the parent template, with the former overriding the latter.
]=]

local export = {}

local usex_module = "Module:usex"
local languages_module = "Module:languages"

local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rfind = mw.ustring.find
local rsplit = mw.text.split
local ulen = mw.ustring.len

local test_new_code = false
local test_new_code_with_errors = false

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
	return "[https://www.worldcat.org/issn/" .. text .. " →ISSN]" ..
		require("Module:check isxn").check_issn(text, "&nbsp;<span class=\"error\" style=\"font-size:88%\">Invalid&nbsp;ISSN</span>[[Category:Pages with ISSN errors]]")
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

local function format_langs(langs)
	local langcodes = rsplit(langs, ",")
	local langnames = {}
	for _, langcode in ipairs(langcodes) do
		local lang = require(languages_module).getByCode(langcode, 1)
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
-- to allow for embedded spaces. (NOTE: Commented out quote processing, in case they are needed in args.)
-- FIXME! Copied directly from ru-noun. Move to utility package.
local function ine(arg)
	if not arg then return nil end
	arg = rsub(arg, "^%s*(.-)%s*$", "%1")
	if arg == "" then return nil end
	--local inside_quotes = rmatch(arg, '^"(.*)"$')
	--if inside_quotes then
	--	return inside_quotes
	--end
	--inside_quotes = rmatch(arg, "^'(.*)'$")
	--if inside_quotes then
	--	return inside_quotes
	--end
	return arg
end

-- Clone frame's and parent's args while also assigning nil to empty strings.
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

-- Implementation of {{quote-meta/source}}.
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

		if NAMESPACE ~= "Template" and not require("Module:usex/templates").page_should_be_ignored(FULLPAGENAME) then
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
	if args.brackets == "on" then
		add("[")
	end
	add(require("Module:time").quote_impl(args))
	if args.origdate then
		add(" [" .. args.origdate .. "]")
	elseif args.origyear and args.origmonth then
		add(" [" .. args.origmonth .. " " .. args.origyear .. "]")
	elseif args.origyear then
		add(" [" .. args.origyear .. "]")
	end
	
	if args.author or args.last or args.quotee then
		for i=1,5 do
			local suf = i == 1 and "" or i
			-- Return the argument named PARAM, possibly with a suffix added (e.g. 2 for author2, 3 for last3). The suffix is
			-- either "" (an empty string) for the first set of params (author, last, first, etc.) or a number for further sets
			-- of params (author2, last2, first2, etc.).
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
				if a("trans-author") or a("trans-last") then
					add(" &#91;")
					if a("trans-authorlink") then
						add("[[w:" .. a("trans-authorlink") .. "|")
					end
					if a("trans-author") then
						add(a("trans-author"))
					elseif a("trans-last") then
						add(a("trans-last"))
						if a("trans-first") then
							add(", ")
							add(a("trans-first"))
						end
					end
					if a("trans-authorlink") then
						add("]]")
					end
					add("&#93;")
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

	local function has_new_title_or_ancillary_author()
		return args.chapter2 or args.title2 or
			args.trans2 or args.translator2 or args.translators2 or
			args.mainauthor2 or args.editor2 or args.editors2
	end

	local function has_new_title_or_author()
		return args["2ndauthor"] or args["2ndlast"] or has_new_title_or_ancillary_author()
	end

	local function has_newversion()
		return args.newversion or args.location2 or has_new_title_or_author()
	end
	
	local archivedate_error

	-- This handles everything after displaying the author, starting with the
	-- chapter and ending with page, column and then other=. It is currently
	-- called twice: Once to handle the main portion of the citation, and once
	-- to handle a "newversion" citation. `suf` is either "" for the main portion
	-- or a number (currently only 2) for a "newversion" citation. In a few
	-- places we conditionalize on `suf` to take actions depending on its value.
	-- `sep` is the separator to display before the first item we add; see
	-- add_with_sep() below.
	local function postauthor(suf, sep)
		-- Return the argument named PARAM, possibly with a suffix added (e.g. 2 for author2, 3 for last3). The suffix is
		-- either "" (an empty string) for the first set of params (chapter, title, translator, etc.) or a number for further
		-- sets of params (chapter2, title2, translator2, etc.).
		local function a(param)
			return args[param .. suf]
		end
		-- Identical to a(param) except that it verifies that no space is present. Should be used for URL's.
		local function aurl(param)
			return check_url(param, a(param))
		end
		local chap = a("chapter")
		if chap then
			local cleaned_chap = chap:gsub("<sup>[^<>]*</sup>", ""):gsub("[*+#]", "")
			if require("Module:number-utilities").get_number(cleaned_chap) then
				-- Arabic chapter number
				add(" chapter ")
				if aurl("chapterurl") then
					add("[" .. aurl("chapterurl") .. " " .. chap .. "]")
				else
					add(chap)
				end
			elseif rfind(cleaned_chap, "^[mdclxviMDCLXVI]+$") and require("Module:roman numerals").roman_to_arabic(cleaned_chap, true) then
				-- Roman chapter number
				add(" chapter ")
				local uchapter = mw.ustring.upper(chap)
				if aurl("chapterurl") then
					add("[" .. aurl("chapterurl") .. " " .. uchapter .. "]")
				else
					add(uchapter)
				end
			else
				-- Must be a chapter name
				add(" “")
				local toinsert
				if aurl("chapterurl") then
					toinsert = "[" .. aurl("chapterurl") .. " " .. chap .. "]"
				else
					toinsert = chap
				end
				add(require("Module:italics").unitalicize_brackets(toinsert))
				if a("trans-chapter") then
					add(" &#91;" .. require("Module:italics").unitalicize_brackets(a("trans-chapter")) .. "&#93;")
				end
				add("”")
			end
			if not a("notitle") then
				add(", in ")
			end
		end

		local translator = a("trans") or a("translator") or a("translators")
		if a("mainauthor") then
			add(a("mainauthor") .. ((translator or a("editor") or a("editors")) and "&#59; " or ","))
		end
		
		if translator then
			add(translator .. ", transl." .. ((a("editor") or a("editors")) and "&#59; " or ","))
		end
		
		if a("editor") then
			add(a("editor") .. ", editor,")
		elseif a("editors") then
			add(a("editors") .. ", editors,")
		end

		-- If we're in the "newversion" code (suf ~= ""), and there's no title
		-- and no URL, then the first time we add anything after the title,
		-- we don't want to add a separating comma because the preceding text
		-- will say "republished " or "republished as " or "translated as " or
		-- similar. In all other cases, we do want to add a separating comma.
		-- We handle this using a `sep` variable whose value will generally
		-- either be "" or ", ". The add_with_sep(text) function adds the `sep`
		-- variable and then `text`, and then resets `sep` to ", " so the next
		-- time around we do add a comma to separate `text` from the preceding
		-- piece of text.
		local function add_with_sep(text)
			add(sep .. text)
			sep = ", "
		end
		if a("title") then
			add(" <cite>" .. require("Module:italics").unitalicize_brackets(a("title")) .. "</cite>")
			if a("trans-title") then
				add(" &#91;<cite>" .. require("Module:italics").unitalicize_brackets(a("trans-title")) .. "</cite>&#93;")
			end
			if a("series") then
				add(" (" .. a("series"))
				if a("seriesvolume") then
					add("&#59; " .. a("seriesvolume"))
				end
				add(")")
			end
			sep = ", "
		elseif suf == "" then
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

		if a("edition") then
			add_with_sep(a("edition") .. " edition")
		end

		if a("volume") then
			add_with_sep("volume " .. a("volume"))
		elseif a("volume_plain") then
			add_with_sep(a("volume_plain"))
		end
		
		if a("issue") then
			add_with_sep("number " .. a("issue"))
		end

		-- This function handles the display of annotations like "(in French)"
		-- or "(in German; quote in Nauruan)". It takes two params PRETEXT and
		-- POSTTEXT to display before and after the annotation, respectively.
		-- These are used to insert the surrounding parens, commas, etc.
		-- They are necessary because we don't always display the annotation
		-- (in fact it's usually not displayed), and when there's no annotation,
		-- no pre-text or post-text is displayed.
		local function langhandler(pretext, posttext)
			local argslang
			if suf == "" then
				argslang = args.lang or args[1]
			else
				argslang = a("lang")
			end
			if a("worklang") then
				return pretext .. "in " .. format_langs(a("worklang")) .. posttext
			elseif argslang and a("termlang") and argslang ~= a("termlang") then
				return pretext .. "in " .. format_langs(argslang) .. posttext
			elseif not argslang and suf == "" then
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
			add_with_sep(a("others"))
		end
		if a("quoted_in") then
			table.insert(tracking_categories, "Quotations using quoted-in parameter")
			add_with_sep("quoted in " .. a("quoted_in"))
		end

		if a("publisher") then
			if a("city") or a("location") then
				add_with_sep((a("city") or a("location")) .. "&#58;") -- colon
				sep = " "
			end
			add_with_sep(a("publisher"))
		elseif a("city") or a("location") then
			add_with_sep(a("city") or a("location"))
		end

		if a("original") then
			add_with_sep((a("type") or "translation") .. " of <cite>" .. a("original")
				.. "</cite>" .. (a("by") and " by " .. a("by") or ""))
		elseif a("by") then
			add_with_sep((a("type") or "translation") .. " of original by " .. a("by"))
		end

		if a("year_published") then
			add_with_sep("published " .. a("year_published"))
		end

		if suf ~= "" and has_newversion() then
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
					error("When archiveurl" .. suf .. "= is specified, url" .. suf .. "= must also be included")
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
				error("When archiveurl" .. suf .. "= is specified, archivedate" .. suf .. "= must also be included")
				archivedate_error = true
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
				add("&nbsp;–&nbsp;''" .. a("laysource") .. "''")
			end
		end
		if a("laydate") then
			add(" (" .. format_date(a("laydate")) .. ")")
		end
		if a("section") then
			add(", " .. (aurl("sectionurl") and "[" .. aurl("sectionurl") .. " " .. a("section") .. "]" or a("section")))
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
				elseif a("page") == "unnumbered" then
					return "unnumbered page"
				else
					return "page " .. a("page")
				end
			end
			add(", " .. (aurl("pageurl") and "[" .. aurl("pageurl") .. " " .. page_or_pages() .. "]" or page_or_pages()))
		end
		if a("column") or a("columns") then
			local function column_or_columns()
				if a("columns") then
					return "columns " .. a("columns")
				else
					return "column " .. a("column")
				end
			end
			add(", " .. (aurl("columnurl") and "[" .. aurl("columnurl") .. " " .. column_or_columns() .. "]" or column_or_columns()))
		end
		if a("other") then
			add(", " .. a("other"))
		end
	end

	-- display all the text that comes after the author, for the main portion.
	postauthor("", "")

	local sep
	
	-- If there's a "newversion" section, add the new-version text.
	if has_newversion() then
		--Test for new version of work.
		add("&#59; ") -- semicolon
		if args.newversion then
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
		-- FIXME, we should use sep = ", " here too and fix up the handling
		-- of chapter/mainauthor/etc. in postauthor() to use add_with_sep().
		if has_new_title_or_ancillary_author() then
			add(", ")
			sep = ""
		else
			sep = ", "
		end
	end

	-- display all the text that comes after the author, for the "newversion"
	-- section.
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
	-- 4. [[Category:Quotations using archiveurl without archivedate]],
	--    if archivedate= is missing and cannot be inferred. Added to the same
	--    pages as for [[Category:Quotations with missing lang parameter]].
	-- 5. [[Category:Quotation templates using both date and year]], if both
	--    date= and year= are specified. Added to the same pages as for
	--    [[Category:Quotations with missing lang parameter]].
	
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
	if archivedate_error then
		table.insert(tracking_categories, "Quotations using archiveurl without archivedate")
	end
	if args.date and args.year then
		table.insert(tracking_categories, "Quotation templates using both date and year")
	end

	local FULLPAGENAME = mw.title.getCurrentTitle().fullText
	return output_text .. (not lang and "" or
		require("Module:utilities").format_categories(categories, lang) ..
		require("Module:utilities").format_categories(tracking_categories, lang, nil, nil,
			not require("Module:usex/templates").page_should_be_ignored(FULLPAGENAME)))
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
			require("Module:debug").track("quote-source/diff")
			if test_new_code_with_errors then
				error("different: <<" .. canon_oldret .. ">> vs <<" .. canon_newret .. ">>")
			end
		else
			require("Module:debug").track("quote-source/same")
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
	local iparams = {
		["text_fallback"] = {},
		["t_fallback"] = {},
	}
	local iargs, other_direct_args = require("Module:parameters").process(frame.args, iparams, "return unknown", "quote", "quote_t_direct")

	local params = {
		[1] = {required = true, default = "und"},
		["lang"] = {alias_of = 1},
		["indent"] = {},
		["i1"] = {alias_of = "indent"},
		["text"] = {},
		["passage"] = {alias_of = "text"},
		["t"] = {},
		["translation"] = {alias_of = "t"},
		["gloss"] = {alias_of = "t"},
		["norm"] = {},
		["normalization"] = {alias_of = "norm"},
		["tr"] = {},
		["transliteration"] = {alias_of = "tr"},
		["ts"] = {},
		["transcription"] = {alias_of = "ts"},
		["brackets"] = {type = "boolean"},
		["nocat"] = {type = "boolean"},
		["subst"] = {},
		["footer"] = {},
		["lit"] = {},
	}
	local parent_args = frame:getParent().args
	local deprecated = parent_args.lang
	local args, other_parent_args = require("Module:parameters").process(parent_args, params, "return unknown", "quote", "quote_t_parent")

	local source_args = clone_args(other_direct_args, other_parent_args, "include direct", "include parent")
	source_args[1] = args[1]
	source_args.nocat = args.nocat

	local function process_fallback(val, fallback_params)
		if val then
			return val
		end
		if fallback_params then
			fallback_params = rsplit(fallback_params, ",")
			for _, fallback_param in ipairs(fallback_params) do
				if args[fallback_param] then
					return args[fallback_param]
				end
			end
		end
		return nil
	end

	args.text = process_fallback(args.text, iargs.text_fallback)
	args.t = process_fallback(args.t, iargs.t_fallback)

	local parts = {}
	local function ins(text)
		table.insert(parts, text)
	end

	if args.indent then
		ins(args.indent)
		ins(" ")
	end
	ins('<div class="citation-whole"><span class="cited-source">')
	ins(export.source(source_args))
	ins("</span><dl><dd>")
	-- if any quote-related args are present, display the actual quote; otherwise, display nothing
	if args.text or args.t or args.tr or args.ts or args.norm then
		local langcodes = rsplit(args[1], ",")
		local usex_data = {
			lang = require(languages_module).getByCode(langcodes[1], 1),
			usex = args.text,
			translation = args.t,
			normalization = args.norm,
			transliteration = args.tr,
			transcription = args.ts,
			brackets = args.brackets,
			qualifiers = {},
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
	return deprecated and frame:expandTemplate{title = "check deprecated lang param usage", args = {retval, lang = args[1]}} or retval
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
	local iargs, other_direct_args = require("Module:parameters").process(frame.args, iparams, "return unknown", "quote", "call_quote_template")
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

	local args = require("Module:parameters").process(parent_args, params, allow_all, "quote", "call_quote_template")
	parent_args = require("Module:table").shallowcopy(parent_args)

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
	local args = require("Module:parameters").process(parargs, params, nil, "quote", "paramdoc")

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

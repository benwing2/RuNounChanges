local export = {}

local m_time = require("Module:time")
local m_italic = require("Module:italics")

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

local function format_date(frame, text)
	return text -- FIXME!
end

function export.quote_meta(args)
	local output = {}
	local function add(output, text)
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

	local function postauthor(suf)
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
			elseif require("Module:roman numbers").roman_to_arabic(a("chapter"), true) then
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

		local function langhandler(pretext, posttext)
			if a("worklang") then
				add(pretext .. "in " .. format_langs(a("worklang")))
				if a("lang") then
					add("&#59; quote in " .. format_langs(a("lang")))
				end
				add(posttext)
			elseif a("lang") then
				if a("lang") ~= "en" then
					add(pretext .. " in " .. format_langs(a("lang")) .. posttext)
				end
			elseif suf == "" then
				add(pretext .. maintenance_line("Please specify the language of the quote") .. posttext)
			end
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
			add(", archived from [" .. a("url") .. " the original] on ")
			if a("archivedate") then
				add(format_date(frame, a("archivedate")))
			else
				add(maintenance_line("Please provide the date"))
			end
		end
		if a("accessdate") then
			--Otherwise do not display here, as already used as a fallback for missing date= or year= earlier.
			if a("date") or a("nodate") or a("year") then
				add(", retrieved " .. format_date(frame, a("accessdate")))
			end
		end
		if a("laysummary") then
			add(", [" .. a("laysummary") .. " lay summary]")
			if a("laysource") then
				add("&nbsp;–&nbsp;''" .. a("laysource") .. "''")
			end
		end
		if a("laydate") then
			add(" (" .. format_date(frame, a("laydate")) .. ")")
		end
		if a("section") then
			add(", " .. (a("sectionurl") and "[" .. a("sectionurl") .. " " .. a("section") .. "]" or a("section"))
		end
		if a("line") then
			add(", line " .. a("line"))
		elseif a("lines") then
			add(", lines " .. a("lines"))
		end
		if a("page") or a("pages") then
			local function page_or_pages()
				if a("pages") then
					add("pages " .. a("pages"))
				else
					add("page " .. a("page"))
				end
			end
			add(", " .. (a("pageurl") and "[" .. a("pageurl") .. " " .. page_or_pages() .. "]" or page_or_pages()))
		end
		if a("column") or a("columns") then
			local function column_or_columns()
				if a("columns") then
					add("columns " .. a("columns"))
				else
					add("column " .. a("column"))
				end
			end
			add(", " .. (a("columnurl") and "[" .. a("columnurl") .. " " .. column_or_columns() .. "]" or column_or_columns()))
		end
		if a("other") then
			add(", " .. a("other"))
		end
	end

	postauthor("")

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
	end

	postauthor(2)

	add(":")

{{#if:{{{nocat|}}}||{{catlangname|{{#invoke:usex/templates|first_lang|{{#if:{{{termlang|}}}|{{{termlang|}}}|{{#if:{{{lang|}}}|{{{lang|}}}|und}}}}}}|terms with quotations}}
}}</includeonly><noinclude>{{documentation}}</noinclude>

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:

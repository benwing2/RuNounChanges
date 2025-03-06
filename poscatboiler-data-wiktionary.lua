local raw_categories = {}
local raw_handlers = {}

local concat = table.concat
local insert = table.insert

local string_utilities_module = "Module:string utilities"


-----------------------------------------------------------------------------
--                                                                         --
--                              RAW CATEGORIES                             --
--                                                                         --
-----------------------------------------------------------------------------


raw_categories["Wiktionary"] = {
	description = "High level category for material about Wiktionary and its operation.",
	parents = "Fundamental",
}

raw_categories["Wiktionary statistics"] = {
	description = "Categories and pages containing statistics about how Wiktionary is used.",
	parents = {"Wiktionary", sort = "Statistics"},
}

raw_categories["Wiktionary users"] = {
	description = "Pages listing Wiktionarians according to their user rights and categories listing Wiktionarians according to their linguistic and coding abilities.",
	breadcrumb = "Users",
	additional = "For an automatically generated list of all users, see [[Special:ListUsers]].",
	parents = {"Wiktionary", sort = "Users"},
}

raw_categories["Wikimedians banned by the WMF"] = {
	description = "Users who have received a [[m:Global bans|global ban]] imposed by the [[m:Wikimedia Foundation|Wikimedia Foundation]], in accordance with the [[m:WMF Global Ban Policy|WMF Global Ban Policy]].",
	breadcrumb = "Banned by the WMF",
	parents = "Wiktionary users",
}

raw_categories["User languages"] = {
	description = "Categories listing Wiktionarians according to their linguistic abilities.",
	parents = {
		"Wiktionary users",
		"Category:Wiktionary multilingual issues",
	},
}

raw_categories["User languages with invalid code"] = {
	description = "Categories listing Wiktionarians according to their linguistic abilities, where the language code is invalid for Wiktionary.",
	additional = "Most of these codes are valid ISO 639-3 codes but are invalid in Wiktionary for various reasons, " ..
	"typically due to different choices made regarding splitting and merging languages.",
	parents = {"User languages", sort = " "},
}

raw_categories["User scripts"] = {
	description = "Categories listing Wiktionarians according to their abilities to read a given script.",
	parents = {
		"Wiktionary users",
		"Category:Wiktionary multilingual issues",
	},
}

raw_categories["User coders"] = {
	description = "Categories listing Wiktionarians according to their coding abilities.",
	parents = "Wiktionary users",
}

raw_categories["Pages with entries"] = {
	description = "Pages which contain language entries.",
	additional = "The subcategories within this category are used to determine the total number of entries on the English Wiktionary.",
	parents = "Wiktionary",
	can_be_empty = true,
	hidden = true,
}

raw_categories["Redirects connected to a Wikidata item"] = {
	description = "Redirect pages which are connected to a [[d:|Wikidata]] item.",
	additional = "These are rarely needed, but are occasionally useful following a page merger, where other wikis may still separate the two.",
	parents = "Wiktionary statistics",
	can_be_empty = true,
	hidden = true,
}

raw_categories["Unsupported titles"] = {
	description = "Pages with titles that are not supported by the MediaWiki software.",
	additional = "For an explanation of the reasons why certain titles are not supported, see [[Appendix:Unsupported titles]].",
	parents = "Wiktionary",
	can_be_empty = true,
	hidden = true,
}

-- Tracked according to [[phab:T347324]].
for ext, data in pairs {
	["DynamicPageList"] = {"DynamicPageList (Wikimedia)", "T287380"},
	["EasyTimeline"] = {"EasyTimeline", "T137291"},
	["Graph"] = {"Graph", "T334940"},
	["Kartographer"] = {"Kartographer"},
	["Phonos"] = {"Phonos"},
	["Score"] = {"Score"},
	["WikiHiero"] = {"WikiHiero", "T344534"},
} do
	local link, phab = unpack(data)
	raw_categories["Pages using the " .. ext .. " extension"] = {
		description = ("Pages which make use of the [[mw:Extension:%s|%s]] extension."):format(link, ext),
		additional = phab and ("See [[phab:%s|%s]] on Phabricator for background information on why this extension is tracked."):format(phab, phab) or nil,
		breadcrumb = ("Using the %s extension"):format(ext),
		parents = "Wiktionary statistics",
		can_be_empty = true,
		hidden = true,
	}
end

-----------------------------------------------------------------------------
--                                                                         --
--                                RAW HANDLERS                             --
--                                                                         --
-----------------------------------------------------------------------------


local function get_level_params(data)
	local speak_verb = "speak"
	if data.typ == "lang" then
		local is_sign_language = data.obj and data.obj:getFamilyCode():find("^sgn") or data.name:find("Sign Language$")
		speak_verb = data.args.verb or is_sign_language and "communicate in" or "speak"
	end
	return {
		["-"] = {
			leftcolor = "#99B3FF",
			rightcolor = "#E0E8FF",
			lang = "These users " .. speak_verb .. " NAME.",
			script = "These users read NAME.",
			coder = "These users know how to code in NAME.",
		},
		["0"] = {
			leftcolor = "#FFB3B3",
			rightcolor = "#FFE0E8",
			lang = "These users do not understand NAME (or understand it with considerable difficulty).",
			script = "These users '''cannot''' read NAME.",
			coder = "These users know '''little''' about NAME and just mimic existing usage.",
		},
		["1"] = {
			leftcolor = "#C0C8FF",
			rightcolor = "#F0F8FF",
			lang = "These users " .. speak_verb .. " NAME at a '''basic''' level.",
			script = "These users can read NAME at a '''basic''' level.",
			coder = "These users know the '''basics''' of how to write NAME code and make minor tweaks.",
		},
		["2"] = {
			leftcolor = "#77E0E8",
			rightcolor = "#D0F8FF",
			lang = "These users " .. speak_verb .. " NAME at an '''intermediate''' level.",
			script = "These users can read NAME at an '''intermediate''' level.",
			coder = "These users have a '''fair command''' of NAME, and can understand some scripts written by others.",
		},
		["3"] = {
			leftcolor = "#99B3FF",
			rightcolor = "#E0E8FF",
			lang = "These users " .. speak_verb .. " NAME at an '''advanced''' level.",
			script = "These users can read NAME at an '''advanced''' level.",
			coder = "These users can write '''more complex''' NAME code, and can understand and modify most scripts written by others.",
		},
		["4"] = {
			leftcolor = "#CCCC00",
			rightcolor = "#FFFF99",
			lang = "These users " .. speak_verb .. " NAME at a '''near-native''' level.",
			script = "These users can read NAME at a '''near native''' level.",
			coder = "These users can write and understand '''very complex''' NAME code.",
		},
		["5"] = {
			leftcolor = "#D6A6F0",
			rightcolor = "#F3E4FA",
			lang = "These users " .. speak_verb .. " NAME at a '''professional''' level.",
			script = "These users can read NAME at a '''professional''' level.",
			coder = "These users can write and understand NAME code at a '''professional''' level.",
		},
		["N"] = {
			leftcolor = "#6EF7A7",
			rightcolor = "#C5FCDC",
			lang = "These users are '''native''' speakers of NAME.",
			script = "These users' '''native''' script is NAME.",
		},
	}
end


local coder_links = {
	Bash = "w:Bash (Unix shell)",
	C = "w:C (programming language)",
	["C++"] = "w:C++",
	["C Sharp"] = {link = "w:C Sharp (programming language)", name = "C&#035;"},
	CSS = "w:CSS",
	Go = "w:Go (programming language)",
	HTML = "w:HTML",
	Java = "w:Java (programming language)",
	JavaScript = "w:JavaScript",
	Julia = "w:Julia (programming language)",
	Lisp = "w:Lisp (programming language)",
	Lua = "Wiktionary:Scripting",
	Perl = "w:Perl",
	Python = "w:Python (programming language)",
	Ruby = "w:Ruby (programming language)",
	Scala = "w:Scala (programming language)",
	Scheme = "w:Scheme (programming language)",
	template = {link = "Wiktionary:Templates", name = "wiki templates"},
	VBScript = "w:VBScript",
}


-- Generic implementation of competency handler for (natural) languages, scripts, and "coders" (= programming languages).
local function competency_handler(data)
	local langtext = data.langtext
	local typ = data.typ
	local args = data.args
	local code = data.code
	local name = data.name
	local namecat = data.namecat
	local level = data.level
	local parents = data.parents
	local topright = data.topright
	local data_addl = data.additional

	local parts = {}
	local function ins(txt)
		insert(parts, txt)
	end
	local level_params = get_level_params(data)

	local params = level_params[level or "-"]
	if not params then
		error(("Internal error: No params for for code '%s', level %s"):format(code, level or "-"))
	end
	local function insert_text()
		if langtext then
			ins(langtext)
			ins("<hr />")
		end
		if not params[typ] then
			error(("No English text for code '%s', type '%s', level %s"):format(code, typ, level or "-"))
		end
		ins(params[typ]:gsub("NAME", ("'''" .. namecat .. "'''"):format(name)))
	end

	local additional
	if level then
		additional = ("To be included on this list, add {{tl|Babel|%s}} to your user page. Complete instructions are " ..
			"available at [[Wiktionary:Babel]]."):format(level == "N" and code or ("%s-%s"):format(code, level)) ..
			(data_addl and "\n\n" .. data_addl or "")
	else
		additional = ("To be included on this list, use {{tl|Babel}} on your user page. Complete instructions are " ..
			"available at [[Wiktionary:Babel]].") ..
			(data_addl and "\n\n" .. data_addl or "")
	end

	if level then
		ins(('<div style="float:left;border:solid %s 1px;margin:1px">'):format(params.leftcolor))
		ins(('<table cellspacing="0" style="width:238px;background:%s"><tr>'):format(params.rightcolor))
		ins(('<td style="width:45px;height:45px;background:%s;text-align:center;font-size:14pt">'):format(params.leftcolor))
		ins(("'''%s-%s'''</td>"):format(code, level))
		ins('<td style="font-size:8pt;padding:4pt;line-height:1.25em">')
		insert_text()
		ins('</td></tr></table></div><br clear="left">')

		return {
			description = concat(parts),
			additional = additional,
			breadcrumb = "Level " .. level,
			parents = parents,
		}, not not args
	else
		ins(('<div style="float:left;border:solid %s 1px;margin:1px;">\n'):format(params.leftcolor))
		ins(('{| cellspacing="0" style="width:260px;background:%s;"\n'):format(params.rightcolor))
		ins(('| style="width:45px;height:45px;background:%s;text-align:center;font-size:14pt;" | '):format(params.leftcolor))
		ins(("'''%s'''\n"):format(code))
		ins('| style="font-size:8pt;padding:4pt;line-height:1.25em;text-align:center;" | ')
		insert_text()
		ins('\n|}</div><br clear="left">')

		return {
			topright = topright,
			description = concat(parts),
			additional = additional,
			breadcrumb = name,
			parents = parents,
		}, not not args
	end
end


insert(raw_handlers, function(data)
	local code, level = data.category:match("^User ([a-z][a-z][a-z]?)%-([0-5N])$")
	if not code then
		code, level = data.category:match("^User ([a-z][a-z][a-z]?%-[a-zA-Z-]+)%-([0-5N])$")
	end
	if not code then
		code = data.category:match("^User ([a-z][a-z][a-z]?)$")
	end
	if not code then
		code = data.category:match("^User ([a-z][a-z][a-z]?%-[a-zA-Z-]+)$")
	end
	if not code then
		return
	end

	local args = require("Module:parameters").process(data.args, {
		text = true,
		verb = true,
		langname = true,
		commonscat = true,
	})
	
	local lang = require("Module:languages").getByCode(code, nil, "allow etym")
	local langname = args.langname
	
	if not lang then
		-- If unrecognized language and called from inside, we're handling the parents and breadcrumb for a
		-- higher-level category, so at least return something.
		if not level and data.called_from_inside then
			return {
				breadcrumb = {name = code, nocap = true}, -- FIXME, scrape langname= category?
				parents = {"User languages with invalid code", sort = code}
			}, true
		end
		
		if not langname then
			-- Check if the code matches a Wikimedia language (e.g. "ku" for Kurdish). If it does, treat
			-- its canonical name as though it had been given as langname=.
			local wm_lang = require("Module:wikimedia languages").getByCode(code)
			if not wm_lang then
				return
			end
			langname = wm_lang:getCanonicalName()
		end
	elseif not langname then
		langname = lang:getCanonicalName()
	end

	-- Insert text, appropriately script-tagged, unless already script-tagged (we check for '<span'), in which case we
	-- insert it directly. Also handle <<...>> in text and convert to bolded link to parent category.
	local function wrap(txt)
		if not txt then
			return
		end
		-- Substitute <<...>> (where ... is supposed to be the native rendering of the language) with a link to the
		-- top-level 'User CODE' category (e.g. [[:Category:User fr]] or [[:Category:User fr-CA]]) if we're in a
		-- sublevel category, or to the top-level language category (e.g. [[:Category:French language]] or
		-- [[:Category:Canadian English]]) if we're in a top-level 'User CODE' category.
		txt = txt:gsub("<<(.-)>>", function(inside)
			if level then
				return ("'''[[:Category:User %s|%s]]'''"):format(code, inside)
			elseif lang then
				return ("'''[[:Category:%s|%s]]'''"):format(lang:getCategoryName(), inside)
			else
				return ("'''%s'''"):format(inside)
			end
		end)
		if txt:find("<span") or not lang then
			return txt
		else
			return require("Module:script utilities").tag_text(txt, lang)
		end
	end

	local function insert_request_cats(parents)
		if args.text or code == "en" or code:find("^en%-") then
			return
		end
		local num_pages = mw.site.stats.pagesInCategory(data.category, "pages")
		local count_cat, count_sort
		if num_pages == 0 then
			count_cat = "Requests for translations in user-competency categories with 0 users"
			count_sort = "*" .. code
		elseif num_pages == 1 then
			count_cat = "Requests for translations in user-competency categories with 1 user"
			count_sort = "*" .. code
		else
			local lowernum, uppernum
			lowernum = 2
			while true do
				uppernum = lowernum * 2 - 1
				if num_pages <= uppernum then
					break
				end
				lowernum = lowernum * 2
			end
			count_cat = ("Requests for translations in user-competency categories with %s-%s users"):format(
				lowernum, uppernum)
			count_sort = "*" .. ("%0" .. #(tostring(uppernum)) .. "d"):format(num_pages)
		end

		insert(parents, {
			name = "Requests for translations in user-competency categories by language",
			sort = code,
		})
		insert(parents, {
			name = count_cat,
			sort = count_sort,
		})
	end

	local invalid_lang_warning
	if not lang then
		invalid_lang_warning = "'''WARNING''': The specified language code is invalid on Wiktionary. Please migrate all " ..
			"competency ratings to the closest valid code."
	end

	local parents
	if level then
		parents = {("User %s"):format(code), sort = level}
	elseif lang then
		parents = {}
		if lang:hasType("etymology-only") then
			local full_code = lang:getFullCode()
			local sort_key = code:gsub(("^%s%%-"):format(require(string_utilities_module).pattern_escape(full_code)), "")
			insert(parents,	{name = ("User %s"):format(full_code), sort = sort_key})
		else
			insert(parents, {name = "User languages", sort = code})
		end
		insert(parents, {name = lang:getCategoryName(), sort = "user"})
	else
		parents = {"User languages with invalid code", sort = code}
	end
	insert_request_cats(parents)

	local topright
	if args.commonscat then
		local commonscat = require("Module:yesno")(args.commonscat, "+")
		if commonscat == "+" or commonscat == true then
			commonscat = data.category
		end
		if commonscat then
			topright = ("{{commonscat|%s}}"):format(commonscat)
		end
	end

	local namecat
	if level then
		namecat = ("[[:Category:User %s|%%s]]"):format(code)
	elseif lang then
		namecat = ("[[:Category:%s|%%s]]"):format(lang:getCategoryName())
	else
		namecat = "[[%s]]"
	end

	local additional
	if level then
		additional = ("To be included on this list, add {{tl|Babel|%s}} to your user page. Complete instructions are " ..
			"available at [[Wiktionary:Babel]]."):format(level == "N" and code or ("%s-%s"):format(code, level)) ..
			(invalid_lang_warning and "\n\n" .. invalid_lang_warning or "")
	else
		additional = ("To be included on this list, use {{tl|Babel}} on your user page. Complete instructions are " ..
			"available at [[Wiktionary:Babel]].") ..
			(invalid_lang_warning and "\n\n" .. invalid_lang_warning or "")
	end
	return competency_handler {
		category = data.category,
		langtext = wrap(args.text),
		typ = "lang",
		args = args,
		obj = lang,
		code = code,
		name = langname,
		namecat = namecat,
		level = level,
		parents = parents,
		topright = topright,
		additional = invalid_lang_warning,
	}
end)


insert(raw_handlers, function(data)
	local code, level = data.category:match("^User ([A-Z][a-z][a-z][a-z][a-z]?)%-([0-5N])$")
	if not code then
		code = data.category:match("^User ([A-Z][a-z][a-z][a-z][a-z]?)$")
	end
	if not code then
		code, level = data.category:match("^User ([a-z][a-z][a-z]?%-[A-Z][a-z][a-z][a-z][a-z]?)%-([0-5N])$")
	end
	if not code then
		code = data.category:match("^User ([a-z][a-z][a-z]?%-[A-Z][a-z][a-z][a-z][a-z]?)$")
	end
	if not code then
		return
	end
	local sc = require("Module:scripts").getByCode(code)
	if not sc then
		return
	end

	local parents
	if level then
		parents = {("User %s"):format(code), sort = level}
	else
		parents = {
			{name = "User scripts", sort = code},
			{name = sc:getCategoryName(), sort = "user"},
		}
	end

	local namecat
	-- Better to display 'Foo script' than just 'Foo', as so many scripts are the same as language names.
	if level then
		namecat = ("[[:Category:User %s|%s]]"):format(code, sc:getCategoryName())
	else
		namecat = ("[[:Category:%s|%s]]"):format(sc:getCategoryName(), sc:getCategoryName())
	end

	return competency_handler {
		category = data.category,
		typ = "script",
		obj = sc,
		code = code,
		name = sc:getCanonicalName(),
		namecat = namecat,
		level = level,
		parents = parents,
	}
end)


insert(raw_handlers, function(data)
	local code, level
	if not code then
		code, level = data.category:match("^User ([A-Za-z+-]+) coder%-([0-5N])$")
	end
	if not code then
		code = data.category:match("^User ([A-Za-z+-]+) coder$")
	end
	if not code or not coder_links[code] then
		return
	end

	local parents
	if level then
		parents = {("User %s coder"):format(code), sort = level}
	else
		parents = {"User coders", sort = code}
	end

	local langdata = coder_links[code]
	if type(langdata) == "string" then
		langdata = {link = langdata}
	end

	local namecat = ("[[%s|%%s]]"):format(langdata.link)

	return competency_handler {
		category = data.category,
		typ = "coder",
		code = code,
		name = langdata.name or code,
		namecat = namecat,
		level = level,
		parents = parents,
	}
end)

insert(raw_handlers, function(data)
	local n, suffix = data.category:match("^Pages with (%d+) entr(.+)$")
	-- Only match if there are no leading zeroes and the suffix is correct.
	if not (n and not n:match("^0%d") and suffix == (n == "1" and "y" or "ies")) then
		return
	end
	return {
		breadcrumb = ("%d entr%s"):format(n, suffix),
		description = ("Pages which contain %s language entr%s."):format(n, suffix),
		additional = "This category, and others like it, are used to determine the total number of entries on the English Wiktionary",
		hidden = true,
		can_be_empty = true,
		parents = {
			{name = "Pages with entries", sort = require("Module:category tree").numeral_sortkey(n)},
			n == "0" and "Wiktionary maintenance" or nil, -- "Pages with 0 entries" only contains pages with something wrong.
		},
	}
end)


return {RAW_CATEGORIES = raw_categories, RAW_HANDLERS = raw_handlers}

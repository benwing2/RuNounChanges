local raw_categories = {}
local raw_handlers = {}


-----------------------------------------------------------------------------
--                                                                         --
--                              RAW CATEGORIES                             --
--                                                                         --
-----------------------------------------------------------------------------


raw_categories["Wiktionary"] = {
	description = "High level category for material about Wiktionary and its operation.",
	parents = {
		"Fundamental",
	},
}

raw_categories["Wiktionary users"] = {
	description = "Pages listing Wiktionarians according to their user rights and categories listing Wiktionarians according to their linguistic and coding abilities.",
	breadcrumb = "Users",
	additional = "For an automatically generated list of all users, see [[Special:ListUsers]].",
	parents = {
		{name = "Wiktionary", sort = "Users"},
	},
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
	parents = {
		{name = "User languages", sort = " "},
	},
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
	parents = {
		"Wiktionary users",
	},
}


-----------------------------------------------------------------------------
--                                                                         --
--                                RAW HANDLERS                             --
--                                                                         --
-----------------------------------------------------------------------------


-- Fancy version of ine() (if-not-empty). Converts empty string to nil, but also strips leading/trailing space.
local function ine(arg)
	if not arg then return nil end
	arg = mw.text.trim(arg)
	if arg == "" then return nil end
	return arg
end


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
			lang = "These users speak NAME at a '''near native''' level.",
			script = "These users can read NAME at a '''near native''' level.",
			coder = "These users can write and understand '''very complex''' NAME code.",
		},
		["5"] = {
			leftcolor = "#FF5E5E",
			rightcolor = "#FF8080",
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


local function competency_handler(data)
	local category = data.category
	local langtext = data.langtext
	local typ = data.typ
	local obj = data.obj
	local args = data.args
	local code = data.code
	local name = data.name
	local namecat = data.namecat
	local level = data.level
	local parents = data.parents
	local data_addl = data.additional

	local parts = {}
	local function ins(txt)
		table.insert(parts, txt)
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
			description = table.concat(parts),
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
		ins("\n|}")

		return {
			description = table.concat(parts),
			additional = additional,
			breadcrumb = name,
			parents = parents,
		}, not not args
	end
end


table.insert(raw_handlers, function(data)
	local code, level
	if not code then
		code, level = data.category:match("^User ([a-z][a-z][a-z]?)%-([0-5N])$")
	end
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
	local lang = require("Module:languages").getByCode(code, nil, "allow etym")
	if not lang then
		-- If unrecognized language and called from inside, we're handling the parents and breadcrumb for a
		-- higher-level category, so at least return something.
		if not level and data.called_from_inside then
			return {
				breadcrumb = {name = code, nocap = true}, -- FIXME, scrape langname= category?
				parents = {
					{name = "User languages with invalid code", sort = code},
				}
			}, true
		end
				
		if not ine(data.args.langname) then
			return
		end
	end

	local params = {
		text = {},
		verb = {},
		langname = {},
	}

	local args = require("Module:parameters").process(data.args, params)

	local langname = args.langname or lang:getCanonicalName()

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

		table.insert(parents, {
			name = "Requests for translations in user-competency categories by language",
			sort = code,
		})
		table.insert(parents, {
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
		parents = {
			{name = ("User %s"):format(code), sort = level},
		}
	elseif lang then
		parents = {
			{name = "User languages", sort = code},
			{name = lang:getCategoryName(), sort = "user"},
		}
		if lang:hasType("etymology-only") then
			table.insert(parents, {name = lang:getNonEtymological():getCategoryName(), sort = " " .. code})
		end
	else
		parents = {
			{name = "User languages with invalid code", sort = code},
		}
	end
	insert_request_cats(parents)

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
		additional = invalid_lang_warning,
	}
end)


table.insert(raw_handlers, function(data)
	local code, level
	if not code then
		code, level = data.category:match("^User ([A-Z][a-z][a-z][a-z][a-z]?)%-([0-5N])$")
	end
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
		parents = {
			{name = ("User %s"):format(code), sort = level},
		}
	else
		parents = {
			{name = "User scripts", sort = code},
			{name = lang:getCategoryName(), sort = "user"},
		}
	end

	local namecat
	if level then
		namecat = ("[[:Category:User %s|%%s]]"):format(code)
	else
		namecat = ("[[:Category:%s|%%s]]"):format(lang:getCategoryName())
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


table.insert(raw_handlers, function(data)
	local code, level
	if not code then
		code, level = data.category:match("^User ([A-Za-z+-]+ coder%-([0-5N])$")
	end
	if not code then
		code = data.category:match("^User ([A-Za-z+-]+ coder$")
	end
	if not code or not coder_links[code] then
		return
	end

	local parents
	if level then
		parents = {
			{name = ("User %s coder"):format(code), sort = level},
		}
	else
		parents = {
			{name = "User coders", sort = code},
		}
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


return {RAW_CATEGORIES = raw_categories, RAW_HANDLERS = raw_handlers}

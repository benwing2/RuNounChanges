local export = {}

local rsplit = mw.text.split
local rfind = mw.ustring.find

local keyword_to_module_type = {
	common = "Language-specific utility",
	utilities = "Language-specific utility",
	headword = "Headword-line",
	translit = "Transliteration",
	infl = "Inflection",
	inflection = "Inflection",
	decl = "Inflection",
	declension = "Inflection",
	adecl = "Inflection",
	conj = "Inflection",
	conjugation = "Inflection",
	noun = "Inflection",
	nouns = "Inflection",
	pronoun = "Inflection",
	pronouns = "Inflection",
	verb = "Inflection",
	verbs = "Inflection",
	adjective = "Inflection",
	adjectives = "Inflection",
	adj = "Inflection",
	nominal = "Inflection",
	nominals = "Inflection",
	pron = "Pronunciation",
	pronun = "Pronunciation",
	pronunc = "Pronunciation",
	pronunciation = "Pronunciation",
	IPA = "Pronunciation",
	entryname = "Entry name-generating",
	sortkey = "Sortkey-generating",
}

-- If a module type is here, we will generate a lang-specific module-type category such as
-- [[:Category:Pali inflection modules]].
local module_type_generates_lang_specific_cat = {
	["Inflection"] = true,
	["Data"] = true,
	["Testcase"] = true,
}

-- If a module type is here, we will generate a lang-specific module-type category such as
-- [[:Category:Pali inflection modules]]. The value is a module that returns a function that fetches all the
-- languages that use a given module for transliteration/entry-name generation/sortkey generation.
local languages_from_module_name = {
	["Transliteration"] = "Module:languages/byTranslitModule",
	["Transliteration testcase"] = "Module:languages/byTranslitModule",
	["Entry name-generating"] = "Module:languages/byEntryNameModule",
	["Sortkey-generating"] = "Module:languages/bySortkeyModule",
}

local module_type_patterns = {
	{"/data%f[-/%z]", "Data"},
	{"/testcases%f[-/%z]", function(typ)
		if typ == "Pronunciation" then
			return "Pronunciation testcase"
		elseif typ == "Transliteration" then
			return "Transliteration testcase"
		else
			return "Testcase"
		end
	end},
}

local function get_lang_or_script(code)
	return code == "-" and code or
		require("Module:languages").getByCode(code, nil, "allow etym") or
		require("Module:languages").getByCode(code .. "-pro", nil, "allow etym") or
		require("Module:scripts").getByCode(code)
end

local function obj_code(obj)
	if obj == "-" then
		return obj
	end
	return obj:getCode()
end

local function infer_lang_or_script_code(name)
	local hyphen_parts = rsplit(name, "%-")
	for i = #hyphen_parts - 1, 1, -1 do
		local code = table.concat(hyphen_parts, "-", 1, i)
		local obj = get_lang_or_script(code)
		if obj then
			local rest = table.concat(hyphen_parts, "-", i + 1)
			return obj, rest
		end
	end
	return nil, nil
end

local function infer_lang_and_script_codes(name)
	local objs = {}
	while true do
		local obj, rest = infer_lang_or_script_code(name)
		if not obj then
			return objs, name
		end
		if #objs > 0 and obj:getCode() == "to" then
			-- skip 'to' in e.g. [[Module:ks-Arab-to-Deva-translit]]; it's not Tongan
		else
			table.insert(objs, obj)
		end
		name = rest
	end
end

--[==[
Main entry point. Can be called from Lua or another module.

`return_raw` set to true makes function return a table of categories with {"[[Category:"} and {"]]"}
stripped away. It is used by [[Module:documentation]].
]==]
function export.categorize(frame, return_raw, noerror)
	local categories = {}

	local function insert_cat(cat, sortkey)
		for _, existing_cat in ipairs(categories) do
			if existing_cat.name == cat then
				return
			end
		end
		table.insert(categories, {name = cat, sort = sortkey})
	end

	local pagename

	if frame.args[1] then
		pagename = frame.args[1]
	end

	local args
	if frame.args.is_template then
		local params = {
			[1] = {}, -- comma-separated list of languages; by default, inferred from module name
			["type"] = {},
			[2] = {alias_of = "type"},
			["pagename"] = {}, -- for testing
			["return_cats"] = {type = "boolean"}, -- for testing
		}

		local parent_args = frame:getParent().args
		args = require("Module:parameters").process(parent_args, params)
	else
		args = {}
	end

	pagename = pagename or args.pagename
	local title
	if pagename then
		title = mw.title.new(pagename)
	else
		title = mw.title.getCurrentTitle()
		-- Fuckme, sometimes this function is called with a faked frame and a title with the namespace already chopped out,
		-- so this test cannot be done in that case.
		if title.nsText ~= "Module" then
			error(("This template should only be used in the Module namespace, not on page '%s'."):format(title.fullText))
		end
		pagename = title.fullText
	end
	
	local subpage = title.subpageText

	local null_return_value = return_raw and {} or ""

	-- To ensure no categories are added on documentation pages.
	if subpage == "documentation" then
		return null_return_value
	end

	local root_pagename
	if subpage ~= pagename then
		root_pagename = title.rootText
	else
		root_pagename = pagename
	end
	root_pagename = root_pagename:gsub("^Module:", "")

	-- Take the module type(s) from type= if given, or infer from the pagename.
	local module_types
	if args.type then
		module_types = rsplit(args.type, ",")
	else
		local module_type_keyword = root_pagename:match("[-%a]+[- ]([^/]+)%f[/%z]")
		if not module_type_keyword then
			if noerror then
				return null_return_value
			else
				error(("Could not extract module type from root pagename '%s'"):format(root_pagename))
			end
		end
		local module_type = keyword_to_module_type[module_type_keyword]
		if not module_type then
			if noerror then
				return null_return_value
			else
				error(("Did not recognize inferred module-type keyword '%s' from root pagename '%s'"):format(
					module_type_keyword, root_pagename))
			end
		end
		module_types = {module_type}
	end

	-- Look for additional module type(s) inferred by pattern.
	for _, pattern_spec in ipairs(module_type_patterns) do
		local pattern, inferred_type = unpack(pattern_spec)
		if rfind(pagename, pattern) then
			local insertIfNot = require("Module:table").insertIfNot
			if type(inferred_type) == "string" then
				insertIfNot(module_types, inferred_type)
			else
				local addl_types = {}
				for _, typ in ipairs(module_types) do
					table.insert(addl_types, inferred_type(typ))
				end
				for _, typ in ipairs(addl_types) do
					insertIfNot(module_types, typ)
				end
			end
		end
	end

	-- If 1= specified, take the languages/scripts directly from there. Otherwise, (a) try to extract one or more
	-- languages/scripts from the pagename (e.g. [[Module:uk-be-headword]] -> Ukrainian and Belarusian (languages);
	-- [[Module:bho-Kthi-translit]] -> Bhojpuri (language) and Kaithi (script); [[Module:Deva-Kthi-translit]] ->
	-- Devanagari and Kaithi (scripts)); and (b) if the specified or inferred module type(s) contain a type listed in
	-- languages_from_module_name[], use the function referenced there to extract additional languages (i.e. all the
	-- languages that use the module we are processing).
	local inferred_objs
	if args[1] then
		inferred_objs = {}
		for _, code in ipairs(rsplit(args[1], ",")) do
			-- We need to have an indicator of families because we allow bare family codes to stand for proto-languages.
			if code:find("^fam:") then
				code = code:gsub("^fam:", "")
				local family = require("Module:families").getByCode(code) or
					error(("Unrecognized family code '%s' in [[Module:module categorization]]"):format(code))
				local descendants = family:getDescendantCodes()
				for _, desc in ipairs(descendants) do
					local obj = get_lang_or_script(desc)
					if obj then
						-- make sure we skip families without proto-languages
						table.insert(inferred_objs, obj)
					end
				end
			else
				local obj = get_lang_or_script(code)
				if not obj then
					error(("Unrecognized language or script code '%s'"):format(code))
				end
				table.insert(inferred_objs, obj)
			end
		end
	else
		inferred_objs = infer_lang_and_script_codes(root_pagename)
		local function insert_obj_if_not(obj)
			local saw_obj = false
			for _, existing_obj in ipairs(inferred_objs) do
				if obj_code(obj) == obj_code(existing_obj) then
					saw_obj = true
					break
				end
			end
			if not saw_obj then
				table.insert(inferred_objs, obj)
			end
		end

		for _, module_type in ipairs(module_types) do
			local languages_extractor = languages_from_module_name[module_type]
			if languages_extractor then
				local langs = require(languages_extractor)(root_pagename)
				if langs then
					for _, obj in ipairs(langs) do
						insert_obj_if_not(obj)
					end
				end
			end
		end

		if #inferred_objs == 0 then
			if noerror then
				return null_return_value
			else
				error(("Could not infer any languages or scripts from root pagename '%s'"):format(root_pagename))
			end
		end
	end

	if pagename:find("^Module:User:") then
		insert_cat("User sandbox modules")
	elseif pagename:find("/sandbox") then
		insert_cat("Sandbox modules")
	else
		for _, module_type in ipairs(module_types) do
			for _, obj in ipairs(inferred_objs) do
				local function insert_overall_module_type_cat(module_type, sortkey)
					if module_type ~= "-" then
						insert_cat(module_type .. " modules", sortkey)
					end
				end

				if obj == "-" then
					insert_overall_module_type_cat(module_type)
				else
					if obj:hasType("script") then
						insert_cat(module_type .. " modules by script", obj:getCanonicalName())
					end
	
					local function construct_lang_or_sc_cat(obj, suffix)
						local prefix
						if obj:hasType("language") then
							prefix = obj:getNonEtymologicalName()
						else
							prefix = obj:getCategoryName()
						end
						return prefix .. " " .. suffix
					end

					insert_cat(construct_lang_or_sc_cat(obj, "modules"), module_type)
					insert_overall_module_type_cat(module_type, obj:getCanonicalName())
					if module_type_generates_lang_specific_cat[module_type] then
						insert_cat(construct_lang_or_sc_cat(obj, mw.getContentLanguage():lcfirst(module_type) .. " modules"))
					end
				end
			end
		end
	end

	for i, catspec in ipairs(categories) do
		if catspec.sort then
			categories[i] = ("%s|%s"):format(catspec.name, catspec.sort)
		else
			categories[i] = catspec.name
		end
	end

	if args.return_cats then
		return table.concat(categories, ",")
	elseif return_raw then
		return categories
	else
		for i, cat in ipairs(categories) do
			categories[i] = "[[Category:" .. cat .. "]]"
		end
		return table.concat(categories)
	end
end

--[==[Table used in the documentation to {{tl|module cat}}.]==]
function export.keyword_to_module_type_table()
	local parts = {}
	local function ins(text)
		table.insert(parts, text)
	end
	ins('{|class="wikitable"')
	ins("! Keyword !! Inferred module type")
	local keywords = {}
	for k, v in pairs(keyword_to_module_type) do
		table.insert(keywords, k)
	end
	table.sort(keywords)
	for _, keyword in ipairs(keywords) do
		ins("|-")
		ins(("| <code>%s</code> || <code>%s</code>"):format(keyword, keyword_to_module_type[keyword]))
	end
	ins("|}")
	return table.concat(parts, "\n")
end

return export

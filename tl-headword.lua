-- This module contains code for Tagalog headword templates.
-- Templates covered are:
-- * {{tl-noun}}, {{tl-proper noun}};
-- * {{tl-verb}};
-- * {{tl-adj}};
-- * {{tl-adv}};
-- * {{tl-num}};
-- * {{tl-pron}};
-- * {{tl-prep}};
-- * {{tl-head}}.

local export = {}
local pos_functions = {}

local force_cat = false -- for testing; if true, categories appear in non-mainspace pages

local lang = require("Module:languages").getByCode("tl")
local langname = lang:getCanonicalName()

local rmatch = mw.ustring.match
local rsplit = mw.text.split

local function track(page)
	require("Module:debug/track")("tl-headword/" .. page)
	return true
end

local function ine(val)
	if val == "" then return nil else return val end
end

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local parargs = frame:getParent().args
	local poscat = frame.args[1]
	local headarg
	if poscat then
		headarg = 1
	else
		headarg = 2
		poscat = ine(parargs[1]) or error("Part of speech must be specified in 1=")
		poscat = require("Module:string utilities").pluralize(poscat)
	end

	local params = {
		[headarg] = {list = "head", disallow_holes = true},
		["tr"] = {list = true, allow_holes = true},
		["id"] = {},
		["b"] = {list = true},
		["nolink"] = {type = "boolean"},
		["nolinkhead"] = {type = "boolean", alias_of = "nolink"},
		["suffix"] = {type = "boolean"},
		["nosuffix"] = {type = "boolean"},
		["addlpos"] = {},
		["json"] = {type = "boolean"},
		["pagename"] = {}, -- for testing
	}
	if headarg == 2 then
		params[1] = {required = true} -- required but ignored as already processed above
	end

	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end

	local args = require("Module:parameters").process(parargs, params)

	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText

	if args.tr.maxindex > #args[headarg] then
		error("Too many translits specified; use '+' to indicate a default head")
	end

	local user_specified_heads = args[headarg]
	local heads = user_specified_heads
	if args.nolink then
		if #heads == 0 then
			heads = {pagename}
		end
	end

	for i, head in ipairs(heads) do
		if head == "+" then
			head = nil
		end
		heads[i] = {
			term = head,
			tr = args.tr[i],
		}
	end

	local data = {
		lang = lang,
		pos_category = poscat,
		categories = {},
		heads = heads,
		user_specified_heads = user_specified_heads,
		no_redundant_head_cat = #user_specified_heads == 0,
		inflections = {},
		pagename = pagename,
		id = args.id,
		force_cat_output = force_cat,
	}

	data.is_suffix = false
	if args.suffix or (
		not args.nosuffix and pagename:find("^%-") and poscat ~= "suffixes" and poscat ~= "suffix forms"
	) then
		data.is_suffix = true
		data.pos_category = "suffixes"
		local singular_poscat = require("Module:string utilities").singularize(poscat)
		table.insert(data.categories, langname .. " " .. singular_poscat .. "-forming suffixes")
		table.insert(data.inflections, {label = singular_poscat .. "-forming suffix"})
		if args.addlpos then
			for _, addlpos in ipairs(rsplit(args.addlpos, "%s*,%s*")) do
				table.insert(data.categories, langname .. " " .. addlpos .. "-forming suffixes")
				table.insert(data.inflections, {label = addlpos .. "-forming suffix"})
			end
		end
	end

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data)
	end
	
	local script = lang:findBestScript(pagename) -- Latn or Tglg
	-- Disable Baybayin spelling parameter if entry is already in Baybayin
	if script:getCode() == "Tglg" then
		args.b = {}
	end

	for i, bay in ipairs(args.b) do
		if bay == "+" then
			bay = pagename
		end
		local baysc = lang:findBestScript(bay)
		if baysc:getCode() == "Latn" then
			bay = frame:expandTemplate { title = "tl-baybayin script", args = { bay }}
		end
		args.b[i] = {term = bay, sc = require("Module:scripts").getByCode("Tglg") }

		-- See if we need to add a tracking category for missing Baybayin script entry
		local script_entry_present
		local title = mw.title.new(bay)
		if title then
			local bay_content = title:getContent()
			if bay_content and bay_content:find("==" .. langname .. "==") and
				rmatch(bay_content, "{{tl%-bay|[^}]*" .. pagename .. "[^}]*}}") then
				script_entry_present = true
			end
		end
		if not script_entry_present then
			table.insert(data.categories, ("%s terms with missing Baybayin script entries"):format(langname))
		end
	end
	if #args.b > 0 then
		args.b.label = "Baybayin spelling"
		table.insert(data.inflections, args.b)
	end

	if script:getCode() == "Latn" then
		table.insert(data.categories,
			("%s terms %s Baybayin script"):format(langname, #args.b > 0 and "with" or "without"))
	elseif script:getCode() == "Tglg" then
		table.insert(data.categories, ("%s terms in Baybayin script"):format(langname))
	end

	if script:getCode() == "Latn" then
		-- See if we need to add a tracking category for missing {{tl-pr}}
		local tl_pr_present
		local this_title = mw.title.new(pagename)
		if this_title then
			local content = this_title:getContent()
			if content and (rmatch(content, "{{tl%-pr}}") or rmatch(content, "{{tl%-pr[|][^}]*}}")) then
				tl_pr_present = true
			end
		end
		if not tl_pr_present then
			table.insert(data.categories, ("%s terms without tl-pr template"):format(langname))
		end
		
			-- See if we need to add a tracking category for missing {{tl-IPA}}
		local tl_IPA_present
		if this_title then
			local content = this_title:getContent()
			if content and rmatch(content, "{{tl%-IPA[^}]*") then
				tl_IPA_present = true
			end
		end
		if not tl_IPA_present and not tl_pr_present then
			table.insert(data.categories, ("%s terms without tl-IPA template"):format(langname))
		end
	end

	if args.json then
		return require("Module:JSON").toJSON(data)
	end

	return require("Module:headword").full_headword(data)
end


local function do_inflection(data, forms, label, accel)
	if #forms > 0 then
		forms.label = label
		if accel then
			forms.accel = accel
		end
		table.insert(data.inflections, forms)
	end
end

pos_functions["adjectives"] = {
    params = {
		["f"] = {list = true},
		["m"] = {list = true},
		["pl"] = {list = true},
		["sup"] = {list = true},
	},
	func = function(args, data)
		do_inflection(data, args.f, "feminine")
		do_inflection(data, args.m, "masculine")
		do_inflection(data, args.pl, "plural", {form = "plural"})
		do_inflection(data, args.sup, "superlative")
	end,
}


pos_functions["nouns"] = {
    params = {
		["f"] = {list = true},
		["m"] = {list = true},
		["pl"] = {list = true},
	},
	func = function(args, data)
		do_inflection(data, args.f, "feminine")
		do_inflection(data, args.m, "masculine")
		do_inflection(data, args.pl, "plural", {form = "plural"})
	end,
}

pos_functions["proper nouns"] = pos_functions["nouns"]


pos_functions["pronouns"] = {
    params = {
		["pl"] = {list = true},
	},
	func = function(args, data)
		do_inflection(data, args.pl, "plural", {form = "plural"})
	end,
}

pos_functions["prepositions"] = pos_functions["pronouns"]


local conj_type_data = {
	["actor"] = 5,
	["actor indirect"] = 0,
	["actor 2nd indirect"] = 4,
	["object"] = 11,
	["locative"] = 2,
	["benefactive"] = 3,
	["instrument"] = 2,
	["reason"] = {4, {1,2,3}},
	["directional"] = 6,
	["reference"] = 0,
	["reciprocal"] = 2
}
local conjugation_types = {}

for key, value in pairs(conj_type_data) do
	local type_count = 0
	local alternates = {}
	if type(value) == "number" then
		type_count = value
	else
		type_count = value[1]
		alternates = value[2]
	end

	local roman_numeral
	if type_count == 0 then
		local trigger = {key, "trigger"}
		if key == "actor indirect" then
			trigger[1] = "indirect actor"
		end
		local trigger_display = table.concat(trigger, " ")
			conjugation_types[key] = {
			trigger_display, lang:getCanonicalName() .. " " .. trigger_display .. " " .. "verbs"
		}
	else
		for i=1, type_count do
			roman_numeral = require('Module:roman numerals').arabic_to_roman(tostring(i))
			local trigger = {require('Module:ordinal')._ordinal(tostring(i)), key, "trigger"}
			
			--These could be typos but putting back in to stay consistent
			if key == "actor 2nd indirect" then
				trigger[2] = "secondary indirect actor"
			end
			
			local trigger_display = table.concat(trigger, " ")
			conjugation_types[key .. " " .. roman_numeral] = {
				trigger_display, lang:getCanonicalName() .. " " .. trigger_display .. " " .. "verbs"
			}
			
			if require("Module:table").contains(alternates, i) then
				roman_numeral = roman_numeral .. "A"
				trigger[1] = "alternate " .. trigger[1]
				local trigger_display = table.concat(trigger, " ")
				conjugation_types[key .. " " .. roman_numeral] = {
					trigger_display, lang:getCanonicalName() .. " " .. trigger_display .. " " .. "verbs"
				}
			end
		end
	end
end

pos_functions["verbs"] = {
    params = {
		[2] = {alias_of = "comp"},
		[3] = {alias_of = "prog"},
		[4] = {alias_of = "cont"},
		[5] = {alias_of = "vnoun"},
		comp = {list = true},
		prog = {list = true},
		cont = {list = true},
		vnoun = {list = true},
		type = {list = true},
	},
	func = function(args, data)
		do_inflection(data, args.comp, "complete", {form = "comp"})
		do_inflection(data, args.prog, "progressive", {form = "prog"})
		do_inflection(data, args.cont, "contemplative", {form = "cont"})
		do_inflection(data, args.vnoun, "verbal noun", {form = "vnoun"})

		--Tagging verb trigger
		for i, typ in ipairs(args.type) do
			if not conjugation_types[typ] then
				error(("Unrecognized Tagalog verb conjugation type '%s'"):format(typ))
			end
			table.insert(data.inflections, {label = conjugation_types[typ][1]})
			table.insert(data.categories, conjugation_types[typ][2])
		end
	end,
}

return export

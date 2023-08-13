local lang = require("Module:languages").getByCode("fa")
local m_headword = require("Module:headword")

local export = {}
local pos_functions = {}

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub

local A = u(0x064E) -- fatḥa
local AN = u(0x064B) -- fatḥatān (fatḥa tanwīn)
local U = u(0x064F) -- ḍamma
local I = u(0x0650) -- kasra
local SK = u(0x0652) -- sukūn = no vowel
local SH = u(0x0651) -- šadda = gemination of consonants
local ZWNJ = u(0x200C) -- ZERO WIDTH NON-JOINER

-----------------------------------------------------------------------------------------
--                                     Utility functions                               --
-----------------------------------------------------------------------------------------

-- version of mw.ustring.gsub() that discards all but the first return value
function rsub(term, foo, bar)
    local retval = rsubn(term, foo, bar)
    return retval
end

function track(page)
	require("Module:debug/track")("fa-headword/" .. page)
	return true
end

function export.ZWNJ(word)
    if rfind(word, "[بپتثجچحخسشصضطظعغفقکگلمنهی]", -1) then
        return ZWNJ
    end
    return "" -- empty string
end


-----------------------------------------------------------------------------------------
--                                    Main entry point                                 --
-----------------------------------------------------------------------------------------

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local poscat = frame.args[1] or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local params = {
		["head"] = {list = true, allow_holes = true},
		[1] = {alias_of = "head"},
		["tr"] = {list = true, allow_holes = true},
		["id"] = {},
		["suff"] = {type = "boolean"},
		["nolinkhead"] = {type = "boolean"},
		["json"] = {type = "boolean"},
		["pagename"] = {}, -- for testing
	}
	
	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText

	local user_specified_heads = args.head

	local head_objects = {}
	local maxhead = math.max(args.head.maxindex, args.tr.maxindex, 1)
	for i = 1,maxhead do
		local head = args.head[i]
		local tr = args.tr[i]
		if not head then
			head = pagename
			if not args.nolinkhead and m_headword.head_is_multiword(head) then
				head = m_headword.add_multiword_links(head)
			end
		end
		tr = tr or (lang:transliterate(require("Module:links").remove_links(head)))
		table.insert(head_objects, {term = head, tr = tr})
	end

	local data = {
		lang = lang,
		pos_category = poscat,
		categories = {},
		heads = head_objects,
		user_specified_heads = user_specified_heads,
		no_redundant_head_cat = #user_specified_heads == 0,
		inflections = {},
		pagename = pagename,
		id = args.id,
		force_cat_output = force_cat,
	}

	local is_suffix = false
	if args.suff then
		is_suffix = true
		data.pos_category = "suffixes"
		local singular_poscat = require("Module:string utilities").singularize(poscat)
		table.insert(data.categories, langname .. " " .. singular_poscat .. "-forming suffixes")
		table.insert(data.inflections, {label = singular_poscat .. "-forming suffix"})
	end

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data, is_suffix)
	end

	if args.json then
		return require("Module:JSON").toJSON(data)
	end

	return require("Module:headword").full_headword(data)
end

local function handle_infl(args, data, argpref, label)
	local infls = {}
	local forms = args[argpref]
	local trs = args[argpref .. "tr"]
	for i, form in ipairs(forms) do
		table.insert(infls, {term = form, translit = trs[i]})
	end
	infls.label = label
	if #infls > 0 then
		table.insert(data.inflections, infls)
	end
end


-----------------------------------------------------------------------------------------
--                                          Verbs                                      --
-----------------------------------------------------------------------------------------

pos_functions["verbs"] = {
	params = {
		["prstem"] = {list = true, disallow_holes = true},
		["prstem=tr"] = {list = true, allow_holes = true},
	},
	func = function(args, data)
		handle_infl(args, data, "prstem", "present stem")
	end
}


-----------------------------------------------------------------------------------------
--                                       Adjectives                                    --
-----------------------------------------------------------------------------------------

pos_functions["adjectives"] = {
	params = {
		["comp"] = {list = true, disallow_holes = true},
		-- FIXME, convert existing uses and remove this
		["c"] = {alias_of = "comp", list = true, disallow_holes = true},
		["comp=tr"] = {list = true, allow_holes = true},
		["sup"] = {list = true, disallow_holes = true},
		["sup=tr"] = {list = true, allow_holes = true},
	},
	func = function(args, data)
		local infls = {}
		for i, form in ipairs(args.comp) do
			if form == "+" then
				for _, headobj in ipairs(data.heads) do
					local term = headobj.term .. export.ZWNJ(headobj.term) .. "ت" .. A .. "ر"
					local tr = 
					translit = data.tr and data.tr .. "-tar" or nil,
					accel = {form = "compararative"},

				table.ins

			table.insert(infls, {term = form, translit = args.comptr[i]})
		end
		infls.label = label
		if #infls > 0 then
			table.insert(data.inflections, infls)
		end
		handle_infl(args, data, "prstem", "present stem")
	end
}


-- Adjectives and adverbs share an inflection spec.
local function get_adj_adv_inflection_spec()
	return {
		{
			prefix = "c", label = "comparative",
			-- We need translits generated if not explicitly given.
			expand_tr_in_generate = true,
			generate_default_from_head = function(data)
				return {
					term = data.term .. export.ZWNJ(data.term) .. "ت" .. A .. "ر",
					translit = data.tr and data.tr .. "-tar" or nil,
					accel = {form = "compararative"},
				}
			end,
		},
		{
			prefix = "s", label = "superlative",
			default = function(data)
				-- There's a default superlative if any comparatives were given.
				-- The default spec is normally "+" so we don't have to specify it explicitly.
				if #data.args.c > 0 then
					return "+"
				end
			end,
			-- We need translits generated if not explicitly given.
			expand_tr_in_generate = true,
			generate_default_from_head = function(data)
				return {
					term = data.term .. export.ZWNJ(data.term) .. "ت" .. A .. "رین",
					translit = data.tr and data.tr .. "-tarin" or nil,
					accel = {form = "superlative"},
				}
			end,
		},
	}
end

pos_functions["verb"] = {
	params = {
		["prstem"] = {list = true, disallow_holes = true},
		["prstem=tr"] = {list = true, allow_holes = true},
	},
	func = function(args, data)
		handle_infl(args, data, "prstem", "present stem")
	end
}

pos_functions["adjectives"] = {
	func = function(args, data)
		data.pos_category = "adjectives"
		if ine(args["c"]) and args["c"] == "+" then
			local word = data.heads[1]
			local word_tr = args["tr"]

			table.insert(data.inflections, {
				label = "comparative",
				accel = {form = "comparative", translit = word_tr .. "-tar"},
				{
					term = word .. export.ZWNJ(word) .. "ت" .. A .. "ر",
					translit = word_tr .. "-tar"
				}
			})

			table.insert(data.inflections, {
				label = "superlative",
				accel = {form = "superlative", translit = word_tr .. "-tarin"},
				{
					term = word .. export.ZWNJ(word) .. "ت" .. A .. "رین",
					translit = word_tr .. "-tarin"
				}
			})
		end
	end
}
return export

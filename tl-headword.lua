local export = {}
local pos_functions = {}

local PAGENAME = mw.title.getCurrentTitle().text
local lang = require("Module:languages").getByCode("tl")
local script = lang:findBestScript(PAGENAME) -- Latn or Tglg

local function track(page)
	require("Module:debug/track")("tl-headword/" .. page)
	return true
end

function export.show(frame)
	local tracking_categories = {}
	local args = frame:getParent().args
	
	-- Check for headword aliases and then pluralize if the POS term does not have an invariable plural.
	local headword_data = mw.loadData("Module:headword/data")
	args.pos = headword_data.pos_aliases[args.pos] or args.pos
	local poscat = frame.args[1] or require("Module:string utilities").pluralize(args.pos) or error("Part of speech has not been specified. Please pass parameter to the module invocation.")
	local head = {} -- supports multiple headword
	
	-- Process head/translit/transcription
	-- Get maximum number of head data
	local max_key = 0
	local head_count = 0
	for key, value in pairs(args) do
		if type(key) == "number" then
			max_key = math.max(max_key, key)
		else
			for idx, argkey in pairs({'head', 'tr', 'ts'}) do
				if key:find("^" .. argkey) then
					local key_number = key:match("^" .. argkey .. "([0-9]*)$")
					if key_number == "" then
						key_number = 1
					elseif tonumber(key_number) then
						if argkey == "head" then
							head_count = head_count + 1
						end
						max_key = math.max(max_key, key_number)
					end
				end
			end
		end
	end
	
	local blanked = false
	-- This is bullshit, clean this up!
	local function insert_head(head_arg, tr_arg, ts_arg)
		if script:getCode() == "Latn" then
			tr_arg = nil
			ts_arg = nil
		end
		if head_arg == "" then
			-- In Tagalog, heads are purposely left blank if it has an alternate pronunciation
			if head_count == 1 or blanked then
				track("blank-head")
			end
			head_arg = PAGENAME
			blanked = true
		end
		if head_arg then
			table.insert(head, {
				term = head_arg,
				tr = tr_arg,
				ts = ts_arg
			})
		end
	end

	for i=1, max_key do
		local arg_i = i > 1 and i or ''
		if arg_i ~= "" and #head == 0 and (args["head" .. arg_i] or args[i])  then
			insert_head("", args["tr" .. arg_i], args["ts".. arg_i])	
		end
		insert_head(args["head" .. arg_i] or args[i], args["tr" .. arg_i], args["ts".. arg_i])	
	end

	local data = {lang = lang, sc = script, pos_category = poscat, categories = {}, heads = head, inflections = { enable_auto_translit = args["autotrinfl"] }}
	
	if args["cat2"] then
		table.insert(data.categories, data.lang:getCanonicalName() .. " " .. args["cat2"])
	end
	
	if args["cat3"] then
		table.insert(data.categories, data.lang:getCanonicalName() .. " " .. args["cat3"])
	end
	
	if args["cat4"] then
		table.insert(data.categories, data.lang:getCanonicalName() .. " " .. args["cat4"])
	end
	
	-- Inflections --
	local sc_name = "Baybayin" or script:getCanonicalName()
	local sc_spelling = {label = sc_name .. " spelling"}
	local sc_cat = {lang:getCanonicalName(), "terms", "without", sc_name, "script"}
	local sc_cat_missing = {lang:getCanonicalName(), "terms with missing", sc_name, "script entries"}
	local inflections = {
		{"f", 'feminine'}, 
		{"m", 'masculine'}, 
		"plural",
		"collective"
	}	

	-- Get Baybayin arguments
	for key, value in require("Module:table").sortedPairs(args) do
		if type(key) ~= "number" then
			if key:match("^b([0-9]*)$") then
				table.insert(sc_spelling, { term = value, sc = require("Module:scripts").getByCode("Tglg") })
				local bay_content = mw.title.new(value):getContent()
				if not (bay_content and bay_content:find("==" .. lang:getCanonicalName() .. "==") and mw.ustring.match(bay_content, "{{tl%-bay|[^}]*" .. PAGENAME .. "[^}]*}}")) then
					table.insert(data.categories, table.concat(sc_cat_missing, " "))
				end
			end
		end
	end
	if script:getCode() == "Latn" and #sc_spelling > 0 then
		--Categorize words with Baybayin
		sc_cat[3] = "with"
		table.insert(data.inflections, sc_spelling)
	elseif script:getCode() == "Tglg" then
		sc_cat[3] = "in"
	end
	table.insert(data.categories, table.concat(sc_cat, " "))

	for i=1, #inflections do
		local param_inflect = inflections[i]
		if type(param_inflect) ~= "table" then
			param_inflect = {param_inflect, param_inflect}
		end
		if args[param_inflect[1]] then
			local inflect_insert = { label = param_inflect[2]}
			if inflect_insert.label == "plural" then
				inflect_insert.accel = {form = inflect_insert.label}
			end
			table.insert(inflect_insert, { term = args[param_inflect[1]]} )
			table.insert(data.inflections, inflect_insert)
		end
	end

	if pos_functions[poscat] then
		pos_functions[poscat](args, data)
	end

	local content = mw.title.new(PAGENAME):getContent()
	local code = content and mw.ustring.match(content, "{{tl%-IPA[^}]*}}")

    --Categorize words without [[Template:tl-IPA]]
	if script:getCode() == "Latn" and not code then
		table.insert(tracking_categories, lang:getCanonicalName() .. " terms without tl-IPA template")
	end
	return require("Module:headword").full_headword(data) .. require("Module:utilities").format_categories(tracking_categories, lang)
end

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

pos_functions["verbs"] = function(args, data)
    params = {
		[1] = {alias_of = 'head'},
		[2] = {alias_of = 'comp'},
		[3] = {alias_of = 'prog'},
		[4] = {alias_of = 'cont'},
		[5] = {alias_of = 'vnoun'},
		head = {list = true},
		head2= {},
		head3= {},
		comp = {list = true},
		prog = {list = true},
		cont = {list = true},
		vnoun = {list = true},
		type = {},
        type2 = {},
        type3 = {},
		b= {},
		b2= {},
		b3= {},
		tr= {}
	}

	local args = require("Module:parameters").process(args,params)
	data.heads = args.head
	data.id = args.id
	local pattern = args.pattern
	local aspects = {
		{"comp", "complete"},
		{"prog", "progressive"},
		{"cont", "contemplative"},
		{"vnoun", "verbal noun"}
	}
	
	for idx, value in pairs(aspects) do
		if #args[value[1]] > 0 then
			args[value[1]].label = value[2]
			args[value[1]].accel = {form = value[1]}
			table.insert(data.inflections, args[value[1]])
		end
	end

    --Tagging verb trigger
	for i=1, 3 do
		local conjtype = args["type" .. (i > 1 and i or '')] or nil
	    if conjtype and conjugation_types[conjtype] then
			table.insert(data.inflections, {label = conjugation_types[conjtype][1]})
			table.insert(data.categories, conjugation_types[conjtype][2])
	    end
	end
end

return export

local export = {}
local m_scripts = require("Module:scripts")
local m_hi_pa_headword = require("Module:hi-pa-headword")

local lang = require("Module:languages").getByCode("hi")
local langname = "Hindi"
local ur_lang = require("Module:languages").getByCode("ur")
local ur_sc = require("Module:scripts").getByCode("ur-Arab")

local function track(page)
	require("Module:debug").track("hi-headword/" .. page)
end

local function process_urdus(urdus)
	local inflection = {}
	for _, urdu in ipairs(urdus) do
		table.insert(inflection, {term = urdu, lang = ur_lang, sc = ur_sc})
	end
	inflection.label = "Urdu spelling"
	return inflection
end

function export.show(frame)
	local poscat = frame.args[1] or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")
	
	local params = {
		["head"] = {list = true},
		["tr"] = {list = true, allow_holes = true},
		["sort"] = {},
		["ur"] = {list = true},
		["splithyphen"] = {type = "boolean"},
	}

	local PAGENAME = mw.loadData("Module:headword/data").pagename

	if PAGENAME:find(" ") then
		track("space")
	end

	if m_hi_pa_headword.pos_functions[poscat] then
		for key, val in pairs(m_hi_pa_headword.pos_functions[poscat].params) do
			params[key] = val
		end
	end

	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)

	local data = {
		lang = lang,
		langname = langname,
		pos_category = poscat,
		heads = args["head"],
		translits = args["tr"],
		categories = {},
		genders = {},
		inflections = {},
		sort_key = args["sort"],
	}

	if #data.translits > 0 then
		track("manual-translit/" .. poscat)
	end

	local heads = data.heads
	local auto_linked_head = require("Module:headword utilities").add_links_to_multiword_term(
		PAGENAME, {split_hyphen_when_space = args.splithyphen})
	if #heads == 0 then
		data.heads = {auto_linked_head}
		data.no_redundant_head_cat = true
	else
		for _, head in ipairs(heads) do
			if head == auto_linked_head then
				track("redundant-head")
			end
		end
	end

	if m_hi_pa_headword.pos_functions[poscat] then
		m_hi_pa_headword.pos_functions[poscat].func(args, data)
	end

	if #args["ur"] > 0 then
		table.insert(data.inflections, process_urdus(args["ur"]))
	end

	return require("Module:headword").full_headword(data)
end

function export.common_params_doc(frame)
	local params = {
		["includeg"] = {type = "boolean"},
		["addltext"] = {},
	}

	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)

	local text = [=[
;{{para|head}}, {{para|head2}}, {{para|head3}}, ...
: Explicitly specified headword(s), for introducing links in multiword expressions. Note that by default each word of a multiword lemma is linked, so you only need to use this when the default links don't suffice (e.g. the multiword expression consists of non-lemma forms, which need to be linked to their lemmas).
;{{para|tr}}, {{para|tr2}}, {{para|tr3}}, ...
: Manual transliteration(s), in case the automatic transliteration is incorrect.
;{{para|ur}}, {{para|ur2}}, {{para|ur3}}, ...
: Urdu equivalent(s).
;{{para|sort}}
: Sort key. Rarely needs to be given.
]=]

	local g_text = [=[
;{{para|g}}, {{para|g2}}, {{para|g3}}, ...
: Gender(s). Possible values are <code>m</code>, <code>f</code>, <code>m-p</code>, <code>f-p</code>, <code>mf</code> (can be either masculine or feminine), <code>mf-p</code> (plural-only, can be either masculine or feminine), <code>mfbysense</code> (can be either masculine or feminine, depending on the natural gender of the person or animal being referred to), <code>mfbysense-p</code> (plural-only, can be either masculine or feminine, depending on the natural gender of the person or animal being referred to).
]=]

	if args.addltext then
		text = args.addltext .. "\n" .. text
	end
	if args.includeg then
		text = g_text .. text
	end
	-- Remove final newline so template code can add a newline after invocation
	text = text:gsub("\n$", "")
	return mw.getCurrentFrame():preprocess(text)
end

return export

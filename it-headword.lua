-- This module contains code for Italian headword templates.
-- Templates covered are {{it-adj}}, {{it-noun}}, {{it-proper noun}}, {{it-verb}}.
-- See [[Module:it-conj]] for Italian conjugation templates.
local export = {}
local pos_functions = {}

local m_links = require("Module:links")

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulower = mw.ustring.lower
local uupper = mw.ustring.upper
local usub = mw.ustring.sub
local ulen = mw.ustring.len
local unfd = mw.ustring.toNFD
local unfc = mw.ustring.toNFC

local lang = require("Module:languages").getByCode("it")
local langname = "Italian"

local GR = u(0x0300)
local TEMP_QU = u(0xFFF1)
local TEMP_GU = u(0xFFF2)
local TEMP_U_IN_AU = u(0xFFF3)
local V = "[aeiou]"
local NV = "[^aeiou]"
local AV = "[àèéìòóù]"

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end

local function check_all_missing(forms, plpos, tracking_categories)
	for _, form in ipairs(forms) do
		if type(form) == "table" then
			form = form.term
		end
		if form then
			local title = mw.title.new(form)
			if title and not title.exists then
				table.insert(tracking_categories, langname .. " " .. plpos .. " with red links in their headword lines")
			end
		end
	end
end

local suffix_categories = {
	["adjectives"] = true,
	["adverbs"] = true,
	["nouns"] = true,
	["verbs"] = true,
}

local prepositions = {
	-- a, da + optional article
	"d?al? ",
	"d?all[oae] ",
	"d?all'",
	"d?ai ",
	"d?agli ",
	-- di, in + optional article
	"di ",
	"in ",
	"[dn]el ",
	"[dn]ell[oae] ",
	"[dn]ell'",
	"[dn]ei ",
	"[dn]egli ",
	-- su + optional article
	"su ",
	"sul ",
	"sull[oae] ",
	"sull'",
	"sui ",
	"sugli ",
	-- others
	"come ",
	"con ",
	"per ",
	"tra ",
	"fra ",
}

-- The main entry point.
-- FIXME: Convert itadj, itnoun, itprop to go through this.
function export.show(frame)
	local tracking_categories = {}

	local poscat = frame.args[1]
		or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local params = {
		["head"] = {list = true},
		["suff"] = {type = "boolean"},
		["id"] = {},
		["sort"] = {},
	}

	local parargs = frame:getParent().args

	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end

	local args = require("Module:parameters").process(parargs, params)
	local data = {
		lang = lang,
		pos_category = poscat,
		categories = {},
		heads = args["head"],
		genders = {},
		inflections = {},
		id = args["id"],
		sort_key = args["sort"],
	}

	if args["suff"] then
		data.pos_category = "suffixes"

		if suffix_categories[poscat] then
			local singular_poscat = poscat:gsub("s$", "")
			table.insert(data.categories, langname .. " " .. singular_poscat .. "-forming suffixes")
		else
			error("No category exists for suffixes forming " .. poscat .. ".")
		end
	end

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data, tracking_categories, frame)
	end

	if args["json"] then
		return require("Module:JSON").toJSON(data)
	end

	return require("Module:headword").full_headword(data)
		.. require("Module:utilities").format_categories(tracking_categories, lang)
end

-- Generate a default plural form, which is correct for most regular nouns and adjectives.
local function make_plural(form, gender, new_algorithm, special)
	if new_algorithm then
		local retval = require("Module:User:Benwing2/romance utilities").handle_multiword(form, special,
			function(form) return make_plural(form, gender, is_adj) end, prepositions)
		if retval then
			if #retval ~= 1 then
				error("Internal error: Should have one return value for make_plural: " .. table.concat(retval, ","))
			end
			return retval[1]
		end
	end

	-- If there are spaces in the term, then we can't reliably form the plural.
	-- Return nothing instead.
	if not new_algorithm and form:find(" ") then
		return nil
	elseif form:find("io$") then
		form = form:gsub("io$", "i")
	elseif form:find("ologo$") then
		form = form:gsub("o$", "i")
	-- FIXME, correct everything to always use new algorithm.
	elseif new_algorithm and form:find("[ia]co$") then
		form = form:gsub("o$", "i")
	-- Of adjectives in -co but not in -aco or -ico, there are several in -esco that take -eschi, and various
	-- others that take -chi: [[adunco]], [[anficerco]], [[azteco]], [[bacucco]], [[barocco]], [[basco]],
	-- [[bergamasco]], [[berlusco]], [[bianco]], [[bieco]], [[bisiacco]], [[bislacco]], [[bisulco]], [[brigasco]],
	-- [[brusco]], [[bustocco]], [[caduco]], [[ceco]], [[cecoslovacco]], [[cerco]], [[chiavennasco]], [[cieco]],
	-- [[ciucco]], [[comasco]], [[cosacco]], [[cremasco]], [[crucco]], [[dificerco]], [[dolco]], [[eterocerco]],
	-- [[etrusco]], [[falisco]], [[farlocco]], [[fiacco]], [[fioco]], [[fosco]], [[franco]], [[fuggiasco]], [[giucco]],
	-- [[glauco]], [[gnocco]], [[gnucco]], [[guatemalteco]], [[ipsiconco]], [[lasco]], [[livignasco]], [[losco]], 
	-- [[manco]], [[monco]], [[monegasco]], [[neobarocco]], [[olmeco]], [[parco]], [[pitocco]], [[pluriconco]], 
	-- [[poco]], [[polacco]], [[potamotoco]], [[prebarocco]], [[prisco]], [[protobarocco]], [[rauco]], [[ricco]], 
	-- [[risecco]], [[rivierasco]], [[roco]], [[roiasco]], [[sbieco]], [[sbilenco]], [[sciocco]], [[secco]],
	-- [[semisecco]], [[slovacco]], [[somasco]], [[sordocieco]], [[sporco]], [[stanco]], [[stracco]], [[staricco]],
	-- [[taggiasco]], [[tocco]], [[tosco]], [[triconco]], [[trisulco]], [[tronco]], [[turco]], [[usbeco]], [[uscocco]],
	-- [[uto-azteco]], [[uzbeco]], [[valacco]], [[vigliacco]], [[zapoteco]].
	--
	-- Only the following take -ci: [[biunivoco]], [[dieco]], [[equivoco]], [[estrinseco]], [[greco]], [[inequivoco]],
	-- [[intrinseco]], [[italigreco]], [[magnogreco]], [[meteco]], [[neogreco]], [[osco]] (either -ci or -chi),
	-- [[petulco]] (either -chi or -ci), [[plurivoco]], [[porco]], [[pregreco]], [[reciproco]], [[stenoeco]],
	-- [[tagicco]], [[univoco]], [[volsco]].
	elseif form:find("[cg]o$") then
		form = form:gsub("o$", "hi")
	elseif form:find("o$") then
		form = form:gsub("o$", "i")
	elseif form:find("[cg]a$") then
		form = form:gsub("a$", (gender == "m" and "hi" or "he"))
	elseif form:find("[cg]ia$") then
		form = form:gsub("ia$", "e")
	elseif form:find("a$") then
		form = form:gsub("a$", (gender == "m" and "i" or "e"))
	elseif form:find("e$") then
		form = form:gsub("e$", "i")
	elseif new_algorithm then
		return nil
	end
	return form
end

-- Generate a default feminine form.
local function make_feminine(form, special)
	local retval = require("Module:User:Benwing2/romance utilities").handle_multiword(form, special, make_feminine, prepositions)
	if retval then
		if #retval ~= 1 then
			error("Internal error: Should have one return value for make_feminine: " .. table.concat(retval, ","))
		end
		return retval[1]
	end

	-- Don't directly return gsub() because then there will be multiple return values.
	if form:find("o$") then
		form = form:gsub("o$", "a")
	elseif form:find("tore$") then
		form = form:gsub("tore$", "trice")
	elseif form:find("one$") then
		form = form:gsub("one$", "ona")
	end

	return form
end

function export.itadj(frame)
	local params = {
		[1] = {},
		[2] = {},
		[3] = {},
		[4] = {},
		[5] = {},
		
		["head"] = {},
		["sort"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local data = {lang = lang, pos_category = "adjectives", categories = {}, sort_key = args["sort"], heads = {args["head"]}, genders = {}, inflections = {}}
	
	local stem = args[1]
	local end1 = args[2]
	
	if not stem then -- all specified
		data.heads = args[2]
		data.inflections = {
			{label = "feminine singular", args[3]},
			{label = "masculine plural", args[4]},
			{label = "feminine plural", args[5]}
		}
	elseif not end1 then -- no ending vowel parameters - generate default
		data.inflections = {
			{label = "feminine singular", stem .. "a"},
			{label = "masculine plural", make_plural(stem .. "o", "m")},
			{label = "feminine plural", make_plural(stem .. "a", "f")}
		}
	else
		local end2 = args[3] or error("Either 0, 2 or 4 vowel endings should be supplied!")
		local end3 = args[4]
		
		if not end3 then -- 2 ending vowel parameters - m and f are identical
			data.inflections = {
				{label = "masculine and feminine plural", stem .. end2}
			}
		else -- 4 ending vowel parameters - specify exactly
			local end4 = args[5] or error("Either 0, 2 or 4 vowel endings should be supplied!")
			data.inflections = {
				{label = "feminine singular", stem .. end2},
				{label = "masculine plural", stem .. end3},
				{label = "feminine plural", stem .. end4}
			}
		end
	end
	
	return require("Module:headword").full_headword(data)
end

local allowed_genders = require("Module:table").listToSet(
	{"m", "f", "mf", "mfbysense", "m-p", "f-p", "mf-p", "mfbysense-p", "?", "?-p"}
)

function export.itnoun(frame)
	local PAGENAME = mw.title.getCurrentTitle().text
	
	local params = {
		[1] = {list = "g", default = "?"},
		[2] = {list = "pl"},
		
		["head"] = {list = true},
		["m"] = {list = true},
		["mpl"] = {list = true},
		["f"] = {list = true},
		["fpl"] = {list = true},
		["sort"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local data = {
		lang = lang, pos_category = "nouns", categories = {}, sort_key = args["sort"],
		heads = args["head"], genders = args[1], inflections = {}
	}

	local is_plurale_tantum = false

	for _, g in ipairs(args[1]) do
		if not allowed_genders[g] then
			error("Unrecognized gender: " .. g)
		end
		if g:find("-p$") then
			is_plurale_tantum = true
		end
	end

	local head = data.heads[1] and require("Module:links").remove_links(data.heads[1]) or PAGENAME
	-- Plural
	if is_plurale_tantum then
		if #args[2] > 0 then
			error("Can't specify plurals of plurale tantum noun")
		end
		table.insert(data.inflections, {label = glossary_link("plural only")})
	else
		local plural = args[2][1]
		
		if not plural and #args["mpl"] == 0 and #args["fpl"] == 0 then
			args[2][1] = make_plural(head, data.genders[1])
		end
		
		if plural == "~" then
			table.insert(data.inflections, {label = glossary_link("uncountable")})
			table.insert(data.categories, "Italian uncountable nouns")
		else
			table.insert(data.categories, "Italian countable nouns")
		end
		
		if plural == "-" then
			table.insert(data.inflections, {label = glossary_link("invariable")})
		end
		
		if plural ~= "-" and plural ~= "~" and #args[2] > 0 then
			args[2].label = "plural"
			args[2].accel = {form = "p"}
			table.insert(data.inflections, args[2])
		end
	end
	
	-- Other gender
	if #args["f"] > 0 then
		args["f"].label = "feminine"
		table.insert(data.inflections, args["f"])
	end
	
	if #args["m"] > 0  then
		args["m"].label = "masculine"
		table.insert(data.inflections, args["m"])
	end
	
	if #args["mpl"] > 0 then
		args["mpl"].label = "masculine plural"
		table.insert(data.inflections, args["mpl"])
	end

	if #args["fpl"] > 0 then
		args["fpl"].label = "feminine plural"
		table.insert(data.inflections, args["fpl"])
	end

	-- Category
	if head:find("o$") and data.genders[1] == "f" then
		table.insert(data.categories, "Italian nouns with irregular gender")
	end
	
	if head:find("a$") and data.genders[1] == "m" then
		table.insert(data.categories, "Italian nouns with irregular gender")
	end
	
	return require("Module:headword").full_headword(data)
end

function export.itprop(frame)
	local params = {
		[1] = {list = "g", default = "?"},

		["head"] = {list = true},
		["m"] = {list = true},
		["f"] = {list = true},
		["sort"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local data = {
		lang = lang, pos_category = "proper nouns", categories = {}, sort_key = args["sort"],
		heads = args["head"], genders = args[1], inflections = {}
	}

	local is_plurale_tantum = false

	for _, g in ipairs(args[1]) do
		if not allowed_genders[g] then
			error("Unrecognized gender: " .. g)
		end
		if g:find("-p$") then
			is_plurale_tantum = true
		end
	end

	if is_plurale_tantum then
		table.insert(data.inflections, {label = glossary_link("plural only")})
	end

	-- Other gender
	if #args["f"] > 0 then
		args["f"].label = "feminine"
		table.insert(data.inflections, args["f"])
	end
	
	if #args["m"] > 0  then
		args["m"].label = "masculine"
		table.insert(data.inflections, args["m"])
	end
	
	return require("Module:headword").full_headword(data)
end


local function do_adjective(args, data, tracking_categories, is_superlative)
	local feminines = {}
	local masculine_plurals = {}
	local feminine_plurals = {}

	if args.sp and not allowed_special_indicators[args.sp] then
		local indicators = {}
		for indic, _ in pairs(allowed_special_indicators) do
			table.insert(indicators, "'" .. indic .. "'")
		end
		table.sort(indicators)
		error("Special inflection indicator beginning can only be " ..
			require("Module:table").serialCommaJoin(indicators, {dontTag = true}) .. ": " .. args.sp)
	end

	local PAGENAME = mw.title.getCurrentTitle().text
	local pagename = args.pagename or PAGENAME
	local lemma = m_links.remove_links(data.heads[1] or pagename)

	if args.inv then
		-- invariable adjective
		table.insert(data.inflections, {label = "invariable"})
		table.insert(data.categories, langname .. " indeclinable adjectives")
		if args.sp or #args.f > 0 or #args.pl > 0 or #args.mpl > 0 or #args.fpl > 0 then
			error("Can't specify inflections with an invariable adjective")
		end
	elseif args.fonly then
		-- feminine-only
		if args.f > 0 then
			error("Can't specify explicit feminines with feminine-only adjective")
		end
		if args.pl > 0 then
			error("Can't specify explicit plurals with feminine-only adjective, use fpl=")
		end
		if args.mpl > 0 then
			error("Can't specify explicit masculine plurals with feminine-only adjective")
		end
		local argsfpl = args.fpl
		if #argsfpl == 0 then
			argsfpl = {"+"}
		end
		for _, fpl in ipairs(argsfpl) do
			if fpl == "+" then
				local defpl = make_plural(lemma, "f", "new algorithm", args.sp)
				if not defpl then
					error("Unable to generate default plural of '" .. lemma .. "'")
				end
				table.insert(feminine_plurals, defpl)
			elseif fpl == "#" then
				table.insert(feminine_plurals, lemma)
			else
				table.insert(feminine_plurals, fpl)
			end
		end

		check_all_missing(feminine_plurals, "adjectives", tracking_categories)

		table.insert(data.inflections, {label = "feminine-only"})
		if #feminine_plurals > 0 then
			feminine_plurals.label = "feminine plural"
			feminine_plurals.accel = {form = "f|p"}
			table.insert(data.inflections, feminine_plurals)
		end
	else
		-- Gather feminines.
		local argsf = args.f
		if #argsf == 0 then
			argsf = {"+"}
		end
		for _, f in ipairs(argsf) do
			if f == "+" then
				-- Generate default feminine.
				f = make_feminine(lemma, args.sp)
			elseif f == "#" then
				f = lemma
			end
			table.insert(feminines, f)
		end

		local argsmpl = args.mpl
		local argsfpl = args.fpl
		if #args.pl > 0 then
			if #argsmpl > 0 or #argsfpl > 0 then
				error("Can't specify both pl= and mpl=/fpl=")
			end
			argsmpl = args.pl
			argsfpl = args.pl
		end
		if #argsmpl == 0 then
			argsmpl = {"+"}
		end
		if #argsfpl == 0 then
			argsfpl = {"+"}
		end

		for _, mpl in ipairs(argsmpl) do
			if mpl == "+" then
				-- Generate default masculine plural.
				local defpl = make_plural(lemma, "m", "new algorithm", args.sp)
				if not defpl then
					error("Unable to generate default plural of '" .. lemma .. "'")
				end
				table.insert(masculine_plurals, defpl)
			elseif mpl == "#" then
				table.insert(masculine_plurals, lemma)
			else
				table.insert(masculine_plurals, mpl)
			end
		end

		for _, fpl in ipairs(argsfpl) do
			if fpl == "+" then
				for _, f in ipairs(feminines) do
					-- Generate default feminine plural.
					local defpl = make_plural(f, "f", "new algorithm", args.sp)
					if not defpl then
						error("Unable to generate default plural of '" .. f .. "'")
					end
					table.insert(feminine_plurals, defpl)
				end
			elseif fpl == "#" then
				table.insert(feminine_plurals, lemma)
			else
				table.insert(feminine_plurals, fpl)
			end
		end

		check_all_missing(feminines, "adjectives", tracking_categories)
		check_all_missing(masculine_plurals, "adjectives", tracking_categories)
		check_all_missing(feminine_plurals, "adjectives", tracking_categories)

		-- Make sure there are feminines given and not same as lemma.
		if #feminines > 0 and not (#feminines == 1 and feminines[1] == lemma) then
			feminines.label = "feminine"
			feminines.accel = {form = "f|s"}
			table.insert(data.inflections, feminines)
		end

		if #masculine_plurals > 0 and #feminine_plurals > 0 and
			require("Module:table").deepEqualsList(masculine_plurals, feminine_plurals) then
			masculine_plurals.label = "plural"
			masculine_plurals.accel = {form = "p"}
			table.insert(data.inflections, masculine_plurals)
		else
			if #masculine_plurals > 0 then
				masculine_plurals.label = "masculine plural"
				masculine_plurals.accel = {form = "m|p"}
				table.insert(data.inflections, masculine_plurals)
			end

			if #feminine_plurals > 0 then
				feminine_plurals.label = "feminine plural"
				feminine_plurals.accel = {form = "f|p"}
				table.insert(data.inflections, feminine_plurals)
			end
		end
	end

	if args.comp and #args.comp > 0 then
		check_all_missing(args.comp, "adjectives", tracking_categories)
		args.comp.label = "comparative"
		table.insert(data.inflections, args.comp)
	end

	if args.sup and #args.sup > 0 then
		check_all_missing(args.sup, "adjectives", tracking_categories)
		args.sup.label = "superlative"
		table.insert(data.inflections, args.sup)
	end

	if args.irreg and is_superlative then
		table.insert(data.categories, langname .. " irregular superlative adjectives")
	end
	
	if #data.heads == 0 and args.pagename then
		table.insert(data.heads, args.pagename)
	end
end


pos_functions["adjectives"] = {
	params = {
		["inv"] = {type = "boolean"}, --invariable
		["sp"] = {}, -- special indicator: "first", "first-last", etc.
		["f"] = {list = true}, --feminine form(s)
		["pl"] = {list = true}, --plural override(s)
		["fpl"] = {list = true}, --feminine plural override(s)
		["mpl"] = {list = true}, --masculine plural override(s)
		["comp"] = {list = true}, --comparative(s)
		["sup"] = {list = true}, --comparative(s)
		["fonly"] = {type = "boolean"}, -- feminine only
		["pagename"] = {}, -- for testing
	},
	func = function(args, data, tracking_categories)
		return do_adjective(args, data, tracking_categories, false)
	end
}

pos_functions["comparative adjectives"] = {
	params = {
		["inv"] = {type = "boolean"}, --invariable
		["sp"] = {}, -- special indicator: "first", "first-last", etc.
		["f"] = {list = true}, --feminine form(s)
		["pl"] = {list = true}, --plural override(s)
		["fpl"] = {list = true}, --feminine plural override(s)
		["mpl"] = {list = true}, --masculine plural override(s)
		["pagename"] = {}, -- for testing
	},
	func = function(args, data, tracking_categories)
		return do_adjective(args, data, tracking_categories)
	end
}

pos_functions["superlative adjectives"] = {
	params = {
		["inv"] = {type = "boolean"}, --invariable
		["sp"] = {}, -- special indicator: "first", "first-last", etc.
		["f"] = {list = true}, --feminine form(s)
		["pl"] = {list = true}, --plural override(s)
		["fpl"] = {list = true}, --feminine plural override(s)
		["mpl"] = {list = true}, --masculine plural override(s)
		["irreg"] = {type = "boolean"},
		["pagename"] = {}, -- for testing
	},
	func = function(args, data, tracking_categories)
		return do_adjective(args, data, tracking_categories, true)
	end
}


local function analyze_verb(lemma)
	local is_pronominal = false
	local is_reflexive = false
	-- The particles that can go after a verb are:
	-- * la, le
	-- * ne
	-- * ci, vi (sometimes in the form ce, ve)
	-- * si (sometimes in the form se)
	-- Observed combinations:
	--   * ce + la: [[avercela]] "to be angry (at someone)", [[farcela]] "to make it, to succeed",
	--              [[mettercela tutta]] "to put everything (into something)"
	--   * se + la: [[sbrigarsela]] "to deal with", [[bersela]] "to naively believe in",
	--              [[sentirsela]] "to have the courage to face (a difficult situation)",
	--              [[spassarsela]] "to live it up", [[svignarsela]] "to scurry away",
	--              [[squagliarsela]] "to vamoose, to clear off", [[cercarsela]] "to be looking for (trouble etc.)",
	--              [[contarsela]] "to have a distortedly positive self-image; to chat at length",
	--              [[dormirsela]] "to be fast asleep", [[filarsela]] "to slip away, to scram",
	--              [[giostrarsela]] "to get away with; to turn a situation to one's advantage",
	--              [[cavarsela]] "to get away with; to get out of (trouble); to make the best of; to manage (to do); to be good at",
	--              [[meritarsela]] "to get one's comeuppance", [[passarsela]] "to fare (well, badly)",
	--              [[rifarsela]] "to take revenge", [[sbirbarsela]] "to slide by (in life)",
	--              [[farsela]]/[[intendersela]] "to have a secret affair or relationship with",
	--              [[farsela addosso]] "to shit oneself", [[prendersela]] "to take offense at; to blame",
	--              [[prendersela comoda]] "to take one's time", [[sbrigarsela]] "to finish up; to get out of (a difficult situation)",
	--              [[tirarsela]] "to lord it over", [[godersela]] "to enjoy", [[vedersela]] "to see (something) through",
	--              [[vedersela brutta]] "to have a hard time with; to be in a bad situation",
	--              [[aversela]] "to pick on (someone)", [[battersela]] "to run away, to sneak away",
	--              [[darsela a gambe]] "to run away", [[fumarsela]] "to sneak away",
	--              [[giocarsela]] "to behave (a certain way); to strategize; to play"
	--   * se + ne: [[andarsene]] "to take leave", [[approfittarsene]] "to take advantage of",
	--              [[fottersene]]/[[strafottersene]] "to not give a fuck",
	--              [[fregarsene]]/[[strafregarsene]] "to not give a damn",
	--              [[guardarsene]] "to beware; to think twice", [[impiparsene]] "to not give a damn",
	--              [[morirsene]] "to fade away; to die a lingering death", [[ridersene]] "to laugh at; to not give a damn",
	--              [[ritornarsene]] "to return to", [[sbattersene]]/[[strabattersene]] "to not give a damn",
	--              [[infischiarsene]] "to not give a damn", [[stropicciarsene]] "to not give a damn",
	--              [[sbarazzarsene]] "to get rid of, to bump off", [[andarsene in acqua]] "to be diluted; to decay",
	--              [[nutrirsene]] "to feed oneself", [[curarsene]] "to take care of",
	--              [[intendersene]] "to be an expert (in)", [[tornarsene]] "to return, to go back",
	--              [[starsene]] "to stay", [[farsene]] "to matter; to (not) consider; to use",
	--              [[farsene una ragione]] "to resign; to give up; to come to terms with; to settle (a dispute)",
	--              [[riuscirsene]] "to repeat (something annoying)", [[venirsene]] "to arrive slowly; to leave"
	--   * ci + si: [[trovarcisi]] "to find oneself in a happy situation",
	--              [[vedercisi]] "to imagine oneself (in a situation)", [[sentircisi]] "to feel at ease"
	--   * vi + si: [[recarvisi]] "to go there"
	--
	local ret = {}
	local linked_suf, finite_pref, finite_pref_ho
	local clitic_to_finite = {ce = "ce", ve = "ve", se = "me"}
	local verb, clitic, clitic2 = rmatch(lemma, "^(.-)([cvs]e)(l[ae])$")
	if verb then
		linked_suf = "[[" .. clitic .. "]][[" .. clitic2 .. "]]"
		finite_pref = "[[" .. clitic_to_finite[clitic] .. "]] [[" .. clitic2 .. "]] "
		finite_pref_ho = "[[" .. clitic_to_finite[clitic] .. "]] [[l']]"
		is_pronominal = true
		is_reflexive = clitic == "se"
	end
	if not verb then
		verb, clitic = rmatch(lemma, "^(.-)([cvs]e)ne$")
		if verb then
			linked_suf = "[[" .. clitic .. "]][[ne]]"
			finite_pref = "[[" .. clitic_to_finite[clitic] .. "]] [[ne]] "
			finite_pref_ho = "[[" .. clitic_to_finite[clitic] .. "]] [[n']]"
			is_pronominal = true
			is_reflexive = clitic == "se"
		end
	end
	if not verb then
		verb, clitic = rmatch(lemma, "^(.-)([cv]i)si$")
		if verb then
			linked_suf = "[[" .. clitic .. "]][[si]]"
			finite_pref = "[[mi]] [[" .. clitic .. "]] "
			if clitic == "vi" then
				finite_pref_ho = "[[mi]] [[v']]"
			else
				finite_pref_ho = "[[mi]] [[ci]] "
			end
			is_pronominal = true
			is_reflexive = true
		end
	end
	if not verb then
		verb, clitic = rmatch(lemma, "^(.-)([cv]i)$")
		if verb then
			linked_suf = "[[" .. clitic .. "]]"
			finite_pref = "[[" .. clitic .. "]] "
			if clitic == "vi" then
				finite_pref_ho = "[[v']]"
			else
				finite_pref_ho = "[[ci]] "
			end
			is_pronominal = true
		end
	end
	if not verb then
		verb = rmatch(lemma, "^(.-)si$")
		if verb then
			linked_suf = "[[si]]"
			finite_pref = "[[mi]] "
			finite_pref_ho = "[[m']]"
			-- not pronominal
			is_reflexive = true
		end
	end
	if not verb then
		verb = rmatch(lemma, "^(.-)ne$")
		if verb then
			linked_suf = "[[ne]]"
			finite_pref = "[[ne]] "
			finite_pref_ho = "[[n']]"
			is_pronominal = true
		end
	end
	if not verb then
		verb, clitic = rmatch(lemma, "^(.-)(l[ae])$")
		if verb then
			linked_suf = "[[" .. clitic .. "]]"
			finite_pref = "[[" .. clitic .. "]] "
			finite_pref_ho = "[[l']]"
			is_pronominal = true
		end
	end
	if not verb then
		verb = lemma
		linked_suf = ""
		finite_pref = ""
		finite_pref_ho = ""
		-- not pronominal
	end

	ret.raw_verb = verb
	ret.linked_suf = linked_suf
	ret.finite_pref = finite_pref
	ret.finite_pref_ho = finite_pref_ho
	ret.is_pronominal = is_pronominal
	ret.is_reflexive = is_reflexive
	return ret
end

local function add_default_verb_forms(base)
	local ret = base.verb
	local raw_verb = ret.raw_verb
	local stem, conj_vowel = rmatch(raw_verb, "^(.-)([aeiour])re?$")
	if not stem then
		error("Unrecognized verb '" .. raw_verb .. "', doesn't end in -are, -ere, -ire, -rre, -ar, -er, -ir, -or or -ur")
	end
	if rfind(raw_verb, "r$") then
		if rfind(raw_verb, "[ou]r$") or base.rre then
			ret.verb = raw_verb .. "re"
		else
			ret.verb = raw_verb .. "e"
		end
	else
		ret.verb = raw_verb
	end

	if not rfind(conj_vowel, "^[aei]$") then
		-- Can't generate defaults for verbs in -rre
		return
	end

	if base.third then
		ret.pres = conj_vowel == "a" and stem .. "a" or stem .. "e"
	else
		ret.pres = stem .. "o"
	end
	if conj_vowel == "i" then
		ret.isc_pres = stem .. "ìsco"
	end
	if conj_vowel == "a" then
		ret.past = stem .. (base.third and "ò" or "ài")
	elseif conj_vowel == "e" then
		ret.past = {stem .. (base.third and "é" or "éi"), stem .. (base.third and "ètte" or "ètti")}
	else
		ret.past = stem .. (base.third and "ì" or "ìi")
	end
	if conj_vowel == "a" then
		ret.pp = stem .. "àto"
	elseif conj_vowel == "e" then
		ret.pp = rfind(stem, "[cg]$") and stem .. "iùto" or stem .. "ùto"
	else
		ret.pp = stem .. "ìto"
	end
end

-- Add links around words. If multiword_only, do it only in multiword forms.
local function add_links(form, multiword_only)
	if form == "" or form == " " then
		return form
	end
	if not form:find("%[%[") then
		if rfind(form, "[%s%p]") then --optimization to avoid loading [[Module:headword]] on single-word forms
			local m_headword = require("Module:headword")
			if m_headword.head_is_multiword(form) then
				form = m_headword.add_multiword_links(form)
			end
		end
		if not multiword_only and not form:find("%[%[") then
			form = "[[" .. form .. "]]"
		end
	end
	return form
end

local function strip_spaces(text)
	return text:gsub("^%s*(.-)%s*", "%1")
end

local function check_not_null(base, form)
	if form == nil then
		error("Default forms cannot be derived from '" .. base.lemma .. "'")
	end
end

-- Given an unaccented stem, pull out the last two vowels as well as the in-between stuff, and return
-- before, v1, between, v2, after as 5 return values. You must undo the TEMP_QU, TEMP_GU and TEMP_U_IN_AU
-- substitutions made in before/between/after if you want to use them. `unaccented` is the full verb and
-- `unaccented_desc` a description of where the verb came from; used only in error messages.
local function analyze_stem_for_last_two_vowels(unaccented_stem, unaccented, unaccented_desc)
	unaccented_stem = rsub(unaccented_stem, "qu", TEMP_QU)
	unaccented_stem = rsub(unaccented_stem, "gu(" .. V .. ")", TEMP_GU .. "%1")
	unaccented_stem = rsub(unaccented_stem, "au(" .. NV .. "*" .. V .. NV .. "*)$", "a" .. TEMP_U_IN_AU .. "%1")
	local before, v1, between, v2, after = rmatch(unaccented_stem, "^(.*)(" .. V .. ")(" .. NV .. "*)(" .. V .. ")(" .. NV .. "*)$")
	if not before then
		before, v1 = "", ""
		between, v2, after = rmatch(unaccented_stem, "^(.*)(" .. V .. ")(" .. NV .. "*)$")
	end
	if not between then
		error("No vowel in " .. unaccented_desc .. " '" .. unaccented .. "' to match")
	end
	return before, v1, between, v2, after
end

-- Apply a single-vowel spec in `form`, e.g. é+, to `unaccented_stem`. `unaccented` is the full verb and
-- `unaccented_desc` a description of where the verb came from; used only in error messages.
local function apply_vowel_spec(unaccented_stem, unaccented, unaccented_desc, form)
	local before, v1, between, v2, after = analyze_stem_for_last_two_vowels(unaccented_stem, unaccented, unaccented_desc)
	if v1 == v2 then
		local form_vowel, first_second = rmatch(form, "^(.)([+-])$")
		if not form_vowel then
			error("Last two stem vowels of " .. unaccented_desc .. " '" .. unaccented ..
				"' are the same; you must specify + (second vowel) or - (first vowel) after the vowel spec '" ..
				form .. "'")
		end
		local raw_form_vowel = usub(unfd(form_vowel), 1, 1)
		if raw_form_vowel ~= v1 then
			error("Vowel spec '" .. form .. "' doesn't match vowel of " .. unaccented_desc .. " '" .. unaccented .. "'")
		end
		if first_second == "-" then
			form = before .. form_vowel .. between .. v2 .. after
		else
			form = before .. v1 .. between .. form_vowel .. after
		end
	else
		if rfind(form, "[+-]$") then
			error("Last two stem vowels of " .. unaccented_desc .. " '" .. unaccented ..
				"' are different; specify just an accented vowel, without a following + or -: '" .. form .. "'")
		end
		local raw_form_vowel = usub(unfd(form), 1, 1)
		if raw_form_vowel == v1 then
			form = before .. form .. between .. v2 .. after
		elseif raw_form_vowel == v2 then
			form = before .. v1 .. between .. form .. after
		elseif before == "" then
			error("Vowel spec '" .. form .. "' doesn't match vowel of " .. unaccented_desc .. " '" .. unaccented .. "'")
		else
			error("Vowel spec '" .. form .. "' doesn't match either of the last two vowels of " .. unaccented_desc ..
				" '" .. unaccented .. "'")
		end
	end
	form = rsub(form, TEMP_QU, "qu")
	form = rsub(form, TEMP_GU, "gu")
	form = rsub(form, TEMP_U_IN_AU, "u")
	return form
end

local function do_ending_stressed_inf(iut, base)
	if rfind(base.verb.verb, "rre$") then
		error("Use \\ not / with -rre verbs")
	end
	-- Add acute accent to -ere, grave accent to -are/-ire.
	local accented = rsub(base.verb.verb, "ere$", "ére")
	accented = unfc(rsub(accented, "([ai])re$", "%1" .. GR .. "re"))
	-- If there is a clitic suffix like -la or -sene, truncate final -e.
	if base.verb.linked_suf ~= "" then
		accented = rsub(accented, "e$", "")
	end
	local linked = "[[" .. base.verb.verb .. "|" .. accented .. "]]" .. base.verb.linked_suf
	iut.insert_form(base.forms, "lemma_linked", {form = linked})
end

local function do_root_stressed_inf(iut, base, specs)
	for _, spec in ipairs(specs) do
		if spec.form == "-" then
			error("Spec '-' not allowed as root-stressed infinitive spec")
		end
		local this_specs
		if spec.form == "+" then
			-- do_root_stressed_inf is used for verbs in -ere and -rre. If the root-stressed vowel isn't explicitly
			-- given and the verb ends in -arre, -irre or -urre, derive it from the infinitive since there's only
			-- one possibility.. If the verb ends in -erre or -orre, this won't work because we have both
			-- scérre (= [[scegliere]]) and disvèrre (= [[disvellere]]), as well as pórre and tòrre (= [[togliere]]).
			local rre_vowel = rmatch(base.verb.verb, "([aiu])rre$")
			if rre_vowel then
				local before, v1, between, v2, after = analyze_stem_for_last_two_vowels(
					rsub(base.verb.verb, "re$", ""), base.verb.verb, "root-stressed infinitive")
				local vowel_spec = unfc(rre_vowel .. GR)
				if v1 == v2 then
					vowel_spec = vowel_spec .. "+"
				end
				this_specs = {{form = vowel_spec}}
			else
				-- Combine current footnotes into present-tense footnotes.
				this_specs = iut.convert_to_general_list_form(base.pres, spec.footnotes)
				for _, this_spec in ipairs(this_specs) do
					if not rfind(this_spec.form, "^" .. AV .. "[+-]?$") then
						error("When defaulting root-stressed infinitive vowel to present, present spec must be a single-vowel spec, but saw '"
							.. this_spec.form .. "'")
					end
				end
			end
		else
			this_specs = {spec}
		end
		local verb_stem, verb_suffix = rmatch(base.verb.verb, "^(.-)([er]re)$")
		if not verb_stem then
			error("Verb '" .. base.verb.verb .. "' must end in -ere or -rre to use \\ notation")
		end
		-- If there is a clitic suffix like -la or -sene, truncate final -(r)e.
		if base.verb.linked_suf ~= "" then
			verb_suffix = verb_suffix == "ere" and "er" or "r"
		end
		for _, this_spec in ipairs(this_specs) do
			if not rfind(this_spec.form, "^" .. AV .. "[+-]?$") then
				error("Explicit root-stressed infinitive spec '" .. this_spec.form .. "' should be a single-vowel spec")
			end

			local expanded = apply_vowel_spec(verb_stem, base.verb.verb, "root-stressed infinitive", this_spec.form) ..
				verb_suffix
			local linked = "[[" .. base.verb.verb .. "|" .. expanded .. "]]" .. base.verb.linked_suf
			iut.insert_form(base.forms, "lemma_linked", {form = linked, footnotes = this_spec.footnotes})
		end
	end
end

local function pres_special_case(base, form)
	if form == "+" then
		check_not_null(base, base.verb.pres)
		return base.verb.pres
	elseif form == "+isc" then
		check_not_null(base, base.verb.isc_pres)
		return base.verb.isc_pres
	elseif form == "-" then
		return form
	elseif rfind(form, "^" .. AV .. "[+-]?$") then
		check_not_null(base, base.verb.pres)
		local pres, final_vowel = rmatch(base.verb.pres, "^(.*)([oae])$")
		if not pres then
			error("Internal error: Default present '" .. base.verb.pres .. "' doesn't end in -o, -a or -e")
		end
		return apply_vowel_spec(pres, base.verb.pres, "default present", form) .. final_vowel
	elseif not base.third and not rfind(form, "[oò]$") then
		error("Present first-person singular form '" .. form .. "' should end in -o")
	elseif base.third and not rfind(form, "[aàeè]") then
		error("Present third-person singular form '" .. form .. "' should end in -a or -e")
	else
		return form
	end
end

local function past_special_case(base, form)
	if form == "+" then
		check_not_null(base, base.verb.past)
		return base.verb.past
	elseif form ~= "-" and not base.third and not rfind(form, "i$") then
		error("Past historic form '" .. form .. "' should end in -i")
	else
		return form
	end
end

local function pp_special_case(base, form)
	if form == "+" then
		check_not_null(base, base.verb.pp)
		return base.verb.pp
	elseif form ~= "-" and not rfind(form, "o$") then
		error("Past participle form '" .. form .. "' should end in -o")
	else
		return form
	end
end

local irreg_forms = { "imperf", "fut", "sub", "impsub", "imp" }

pos_functions["verbs"] = {
	params = {
		[1] = {},
		["pagename"] = {}, -- for testing
		["noautolinktext"] = {type = "boolean"},
		["noautolinkverb"] = {type = "boolean"},
	},
	func = function(args, data, tracking_categories, frame)
		local PAGENAME = mw.title.getCurrentTitle().text
		local pagename = args.pagename or PAGENAME

		if args[1] then
			local arg1 = args[1]
			if not arg1:find("<.*>") then
				arg1 = "<" .. arg1 .. ">"
			end

			local iut = require("Module:inflection utilities")

			-- (1) Parse the indicator specs inside of angle brackets.

			local function parse_indicator_spec(angle_bracket_spec, lemma)
				local base = {forms = {}, irreg_forms = {}}
				local function parse_err(msg)
					error(msg .. ": " .. angle_bracket_spec)
				end

				local function fetch_qualifiers(separated_group)
					local qualifiers
					for j = 2, #separated_group - 1, 2 do
						if separated_group[j + 1] ~= "" then
							parse_err("Extraneous text after bracketed qualifiers: '" .. table.concat(separated_group) .. "'")
						end
						if not qualifiers then
							qualifiers = {}
						end
						table.insert(qualifiers, separated_group[j])
					end
					return qualifiers
				end

				local function fetch_specs(comma_separated_group, allow_blank)
					local colon_separated_groups = iut.split_alternating_runs(comma_separated_group, ":")
					if allow_blank and #colon_separated_groups == 1 and #colon_separated_groups[1] == 1 and
						colon_separated_groups[1][1] == "" then
						return nil
					end
					local specs = {}
					for _, colon_separated_group in ipairs(colon_separated_groups) do
						local form = colon_separated_group[1]
						if form == "" then
							parse_err("Blank form not allowed here, but saw '" ..
								table.concat(comma_separated_group) .. "'")
						end
						table.insert(specs, {form = form, footnotes = fetch_qualifiers(colon_separated_group)})
					end
					return specs
				end

				if lemma == "" then
					lemma = pagename
				end
				base.lemma = m_links.remove_links(lemma)
				base.verb = analyze_verb(lemma)

				local inside = angle_bracket_spec:match("^<(.*)>$")
				assert(inside)

				local segments = iut.parse_balanced_segment_run(inside, "[", "]")
				local dot_separated_groups = iut.split_alternating_runs(segments, "%s*%.%s*")
				for i, dot_separated_group in ipairs(dot_separated_groups) do
					local first_element = dot_separated_group[1]
					if first_element == "only3s" or first_element == "only3sp" or first_element == "rre" then
						if #dot_separated_group > 1 then
							parse_err("No footnotes allowed with '" .. first_element .. "' spec")
						end
						base[first_element] = true
					else
						local saw_irreg = false
						for _, irreg_form in ipairs(irreg_forms) do
							local first_element_minus_prefix = rmatch(first_element, "^" .. irreg_form .. ":(.*)$")
							if first_element_minus_prefix then
								dot_separated_group[1] = first_element_minus_prefix
								base.irreg_forms[irreg_form] = fetch_specs(dot_separated_group)
								saw_irreg = true
								break
							end
						end
						if not saw_irreg then
							local comma_separated_groups = iut.split_alternating_runs(dot_separated_group, "%s*[,\\/]%s*", "preserve splitchar")
							local presind = 1
							local first_separator = #comma_separated_groups > 1 and
								strip_spaces(comma_separated_groups[2][1])
							if base.verb.is_reflexive then
								if #comma_separated_groups > 1 and first_separator ~= "," then
									presind = 3
									-- Auxiliary present (if non-reflexive), or root-stressed infinitive spec (if reflexive).
									-- Fetch root-stressed infinitive, if given.
									local specs = fetch_specs(comma_separated_groups[1], "allow blank")
									if first_separator == "\\" then
										-- For verbs like [[scegliersi]] and [[proporsi]], allow either 'é\scélgo' or '\é\scélgo'
										-- and similarly either 'ó+\propóngo' or '\ó+\propóngo'.
										if specs == nil then
											if #comma_separated_groups > 3 and strip_spaces(comma_separated_groups[4][1]) == "\\" then
												base.root_stressed_inf = fetch_specs(comma_separated_groups[3])
												presind = 5
											else
												base.root_stressed_inf = {{form = "+"}}
											end
										else
											base.root_stressed_inf = specs
										end
									elseif specs ~= nil then
										parse_err("With reflexive verb, can't specify anything before initial slash, but saw '"
											.. table.concat(comma_separated_groups[1]))
									end
								end
							else -- non-reflexive
								if #comma_separated_groups == 1 or first_separator == "," then
									parse_err("With non-reflexive verb, use a spec like AUX/PRES, AUX\\PRES, AUX/PRES,PAST,PP or similar")
								end
								presind = 3
								-- Fetch auxiliary or auxiliaries.
								local colon_separated_groups = iut.split_alternating_runs(comma_separated_groups[1], ":")
								for _, colon_separated_group in ipairs(colon_separated_groups) do
									local aux = colon_separated_group[1]
									if aux == "a" then
										aux = "avere"
									elseif aux == "e" then
										aux = "essere"
									elseif aux == "-" then
										if #colon_separated_group > 1 then
											parse_err("No footnotes allowed with '-' spec for auxiliary")
										end
										aux = nil
									else
										parse_err("Unrecognized auxiliary '" .. aux ..
											"', should be 'a' (for [[avere]]), 'e' (for [[essere]]), or '-' if no past participle")
									end
									if aux then
										if base.aux then
											for _, existing_aux in ipairs(base.aux) do
												if existing_aux.form == aux then
													parse_err("Auxiliary '" .. aux .. "' specified twice")
												end
											end
										else
											base.aux = {}
										end
										table.insert(base.aux, {form = aux, footnotes = fetch_qualifiers(colon_separated_group)})
									end
								end

								-- Fetch root-stressed infinitive, if given.
								if first_separator == "\\" then
									if #comma_separated_groups > 3 and strip_spaces(comma_separated_groups[4][1]) == "\\" then
										base.root_stressed_inf = fetch_specs(comma_separated_groups[3])
										presind = 5
									else
										base.root_stressed_inf = {{form = "+"}}
									end
								end
							end

							-- Parse present
							base.pres = fetch_specs(comma_separated_groups[presind])

							-- Parse past historic
							if #comma_separated_groups > presind then
								if strip_spaces(comma_separated_groups[presind + 1][1]) ~= "," then
									parse_err("Use a comma not slash to separate present from past historic")
								end
								base.past = fetch_specs(comma_separated_groups[presind + 2])
							end

							-- Parse past participle
							if #comma_separated_groups > presind + 2 then
								if strip_spaces(comma_separated_groups[presind + 3][1]) ~= "," then
									parse_err("Use a comma not slash to separate past historic from past participle")
								end
								base.pp = fetch_specs(comma_separated_groups[presind + 4])
							end

							if #comma_separated_groups > presind + 4 then
								parse_err("Extraneous text after past participle")
							end
						end
					end
				end
				return base
			end

			local parse_props = {
				parse_indicator_spec = parse_indicator_spec,
				allow_blank_lemma = true,
			}
			local alternant_multiword_spec = iut.parse_inflected_text(arg1, parse_props)

			-- (2) Add links to all before and after text.

			if not args.noautolinktext then
				alternant_multiword_spec.post_text = add_links(alternant_multiword_spec.post_text)
				for _, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
					alternant_or_word_spec.before_text = add_links(alternant_or_word_spec.before_text)
					if alternant_or_word_spec.alternants then
						for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
							multiword_spec.post_text = add_links(multiword_spec.post_text)
							for _, word_spec in ipairs(multiword_spec.word_specs) do
								word_spec.before_text = add_links(word_spec.before_text)
							end
						end
					end
				end
			end

			-- (3) Do any global checks.

			iut.map_word_specs(alternant_multiword_spec, function(base)
				-- Handling of only3s and only3p.
				if base.only3s and base.only3sp then
					error("'only3s' and 'only3sp' cannot both be specified")
				end
				base.third = base.only3s or base.only3sp
				if alternant_multiword_spec.only3s == nil then
					alternant_multiword_spec.only3s = base.only3s
				elseif alternant_multiword_spec.only3s ~= base.only3s then
					error("If some alternants specify 'only3s', all must")
				end
				if alternant_multiword_spec.only3sp == nil then
					alternant_multiword_spec.only3sp = base.only3sp
				elseif alternant_multiword_spec.only3sp ~= base.only3sp then
					error("If some alternants specify 'only3sp', all must")
				end
				
				-- Check for missing past participle == missing auxiliary.
				if not base.verb.is_reflexive then
					local pp_is_missing = base.pp and #base.pp == 1 and base.pp[1].form == "-"
					local aux_is_missing = not base.aux
					if (aux_is_missing or nil) ~= (pp_is_missing or nil) then
						error("If auxiliary given as '-', past participle must be explicitly specified as '-', and vice-versa")
					end
				end
			end)
			alternant_multiword_spec.third = alternant_multiword_spec.only3s or alternant_multiword_spec.only3sp

			-- (4) Conjugate the verbs according to the indicator specs parsed above.

			local sing_accel = alternant_multiword_spec.third and "3|s" or "1|s"
			local sing_label = alternant_multiword_spec.third and "third-person singular" or "first-person singular"
			local all_verb_slots = {
				lemma = "infinitive",
				lemma_linked = "infinitive",
				pres_form = sing_accel .. "|pres|ind",
				past_form = sing_accel .. "|phis",
				pp_form = "m|s|past|part",
				imperf_form = sing_accel .. "|impf|ind",
				fut_form = sing_accel .. "|fut|ind",
				sub_form = sing_accel .. "|pres|sub",
				impsub_form = sing_accel .. "|impf|sub",
				imp_form = "2|s|imp",
				-- aux should not be here. It doesn't have an accelerator and isn't "conjugated" normally.
			}
			local all_verb_slot_labels = {
				lemma = "infinitive",
				lemma_linked = "infinitive",
				pres_form = sing_label .. " present",
				past_form = sing_label .. " past historic",
				pp_form = "past participle",
				imperf_form = sing_label .. " imperfect",
				fut_form = sing_label .. " future",
				sub_form = sing_label .. " present subjunctive",
				impsub_form = sing_label .. " imperfect subjunctive",
				imp_form = "second-person singular imperative",
				aux = "auxiliary",
			}

			local function conjugate_verb(base)
				add_default_verb_forms(base)
				if base.verb.is_pronominal then
					alternant_multiword_spec.is_pronominal = true
				end

				local function process_specs(slot, specs, is_finite, special_case)
					specs = specs or {{form = "+"}}
					for _, spec in ipairs(specs) do
						local decorated_form = spec.form
						local preserve_monosyllabic_accent, form, syntactic_gemination =
							rmatch(decorated_form, "^(%*?)(.-)(%**)$")
						local forms = special_case(base, form)
						forms = iut.convert_to_general_list_form(forms, spec.footnotes)
						for _, formobj in ipairs(forms) do
							local qualifiers = formobj.footnotes
							local form = formobj.form
							-- If the form is -, insert it directly, unlinked; we handle this specially
							-- below, turning it into special labels like "no past participle".
							if form ~= "-" then
								local unaccented_form
								if rfind(form, "^.*" .. V .. ".*" .. AV .. "$") then
									-- final accented vowel with preceding vowel; keep accent
									unaccented_form = form
								elseif rfind(form, AV .. "$") and preserve_monosyllabic_accent == "*" then
									unaccented_form = form
									qualifiers = iut.combine_footnotes(qualifiers, {"[with written accent]"})
								else
									unaccented_form = rsub(form, AV, function(v) return usub(unfd(v), 1, 1) end)
								end
								if syntactic_gemination == "*" then
									qualifiers = iut.combine_footnotes(qualifiers, {"[with following syntactic gemination]"})
								elseif syntactic_gemination == "**" then
									qualifiers = iut.combine_footnotes(qualifiers, {"[with optional following syntactic gemination]"})
								elseif syntactic_gemination ~= "" then
									error("Decorated form '" .. decorated_form .. "' has too many asterisks after it, use '*' for syntactic gemination and '**' for optional syntactic gemination")
								end
								form = "[[" .. unaccented_form .. "|" .. form .. "]]"
								if is_finite then
									if unaccented_form == "ho" then
										form = base.verb.finite_pref_ho .. form
									else
										form = base.verb.finite_pref .. form
									end
								end
							end
							iut.insert_form(base.forms, slot, {form = form, footnotes = qualifiers})
						end
					end
				end

				process_specs("pres_form", base.pres, "finite", pres_special_case)
				process_specs("past_form", base.past, "finite", past_special_case)
				process_specs("pp_form", base.pp, false, pp_special_case)

				local function irreg_special_case(base, form, def)
					return form
				end

				for _, irreg_form in ipairs(irreg_forms) do
					if base.irreg_forms[irreg_form] then
						process_specs(irreg_form .. "_form", base.irreg_forms[irreg_form], irreg_form ~= "imp",
							irreg_special_case)
					end
				end

				iut.insert_form(base.forms, "lemma", {form = base.lemma})
				-- Add linked version of lemma for use in head=.
				if base.root_stressed_inf then
					do_root_stressed_inf(iut, base, base.root_stressed_inf)
				else
					do_ending_stressed_inf(iut, base)
				end
			end

			local inflect_props = {
				slot_table = all_verb_slots,
				inflect_word_spec = conjugate_verb,
				-- We add links around the generated verbal forms rather than allow the entire multiword
				-- expression to be a link, so ensure that user-specified links get included as well.
				include_user_specified_links = true,
			}
			iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)

			-- Set the overall auxiliary or auxiliaries. We can't do this using the normal inflection
			-- code as it will produce e.g. '[[avere]] e [[avere]]' for conjoined verbs.
			iut.map_word_specs(alternant_multiword_spec, function(base)
				iut.insert_forms(alternant_multiword_spec.forms, "aux", base.aux)
			end)

			-- (5) Fetch the forms and put the conjugated lemmas in data.heads if not explicitly given.

			local function strip_brackets(qualifiers)
				if not qualifiers then
					return nil
				end
				local stripped_qualifiers = {}
				for _, qualifier in ipairs(qualifiers) do
					local stripped_qualifier = qualifier:match("^%[(.*)%]$")
					if not stripped_qualifier then
						error("Internal error: Qualifier should be surrounded by brackets at this stage: " .. qualifier)
					end
					table.insert(stripped_qualifiers, stripped_qualifier)
				end
				return stripped_qualifiers
			end

			local function do_verb_form(slot, label)
				local forms = alternant_multiword_spec.forms[slot]
				if not forms or #forms == 0 then
					-- This will happen with unspecified irregular forms.
					return
				end

				-- Disable accelerators for now because we don't want the added accents going into the headwords.
				-- FIXME: Add support to [[Module:accel]] so we can add the accelerators back with a param to
				-- avoid the accents.
				local accel_form = nil -- all_verb_slots[slot]
				local label = all_verb_slot_labels[slot]
				local retval
				if forms[1].form == "-" then
					retval = {label = "no " .. label}
				else
					retval = {label = label, accel = accel_form and {form = accel_form} or nil}
					for _, form in ipairs(forms) do
						local qualifiers = strip_brackets(form.footnotes)
						table.insert(retval, {term = form.form, qualifiers = qualifiers})
					end
				end
				table.insert(data.inflections, retval)
			end

			if alternant_multiword_spec.is_pronominal then
				table.insert(data.inflections, {label = glossary_link("pronominal")})
			end
			if alternant_multiword_spec.only3s then
				table.insert(data.inflections, {label = glossary_link("impersonal")})
			end
			if alternant_multiword_spec.only3sp then
				table.insert(data.inflections, {label = "third-person only"})
			end
			
			do_verb_form("pres_form")
			do_verb_form("past_form")
			do_verb_form("pp_form")
			for _, irreg_form in ipairs(irreg_forms) do
				do_verb_form(irreg_form .. "_form")
			end
			do_verb_form("aux")

			-- Add categories.
			if alternant_multiword_spec.forms.aux then
				for _, form in ipairs(alternant_multiword_spec.forms.aux) do
					table.insert(data.categories, "Italian verbs taking " .. form.form .. " as auxiliary")
				end
			end
			if alternant_multiword_spec.is_pronominal then
				table.insert(data.categories, "Italian pronominal verbs")
			end

			-- Use the "linked" form of the lemma as the head if no head= explicitly given.
			if #data.heads == 0 then
				for _, lemma_obj in ipairs(alternant_multiword_spec.forms.lemma_linked) do
					local lemma = lemma_obj.form
					-- FIXME, can't yet specify qualifiers for heads
					table.insert(data.heads, lemma_obj.form)
					-- table.insert(data.heads, {term = lemma_obj.form, qualifiers = strip_brackets(lemma_obj.footnotes)})
				end
			end
		end
	end
}

return export

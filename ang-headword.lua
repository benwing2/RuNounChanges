local export = {}
local pos_functions = {}

local lang = require("Module:languages").getByCode("ang")

local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function track(page)
	require("Module:debug").track("ang-headword/" .. page)
	return true
end

local function format(array, concatenater)
	if #array == 0 then
		return ""
	else
		local concatenated = table.concat(array, concatenater)
		if concatenated == "" then
			return ""
		elseif rfind(concatenated, "'$") then
			concatenated = concatenated .. " "
		end
		return "; ''" .. concatenated .. "''"
	end
end

local function glossary_link(anchor, text)
	text = text or anchor
	return "[[Appendix:Glossary#" .. anchor .. "|" .. text .. "]]"
end

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local NAMESPACE = mw.title.getCurrentTitle().nsText
	local PAGENAME = mw.title.getCurrentTitle().text

	local iparams = {
		[1] = {required = true},
		["def"] = {},
		["suff_type"] = {},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)
	local args = frame:getParent().args
	local poscat = iargs[1]
	local def = iargs.def
	local suff_type = iargs.suff_type
	local postype = nil
	if suff_type then
		postype = poscat .. '-' .. suff_type
	else
		postype = poscat
	end

	local data = {lang = lang, categories = {}, heads = {}, genders = {}, inflections = {}}
	local infl_classes = {}
	local appendix = {}
	local postscript = {}

	if poscat == "suffixes" then
		table.insert(data.categories, "Old English " .. suff_type .. "-forming suffixes")
	end

	if pos_functions[postype] then
		local new_poscat = pos_functions[postype](def, args, data, infl_classes, appendix, postscript)
		if new_poscat then
			poscat = new_poscat
		end
	end

	data.pos_category = (NAMESPACE == "Reconstruction" and "reconstructed " or "") .. poscat
	
	postscript = table.concat(postscript, ", ")
	
	return
		require("Module:headword").full_headword(data)
		.. format(infl_classes, "/")
		.. format(appendix, ", ")
		.. (postscript ~= "" and " (" .. postscript .. ")" or "")
end

pos_functions["verbs"] = function(def, args, data, infl_classes, appendix)
	local params = {
		[1] = {alias_of = 'head'},
		["head"] = {list = true},
		["id"] = {},
	}

	local args = require("Module:parameters").process(args, params)
	data.heads = args.head
	data.id = args.id
end

local function adjectives(pos, def, args, data, infl_classes, appendix)
	local NAMESPACE = mw.title.getCurrentTitle().nsText
	local params = {
		[1] = {alias_of = "head"},
		["head"] = {list = true},
		["comp"] = {list = true},
		[2] = {alias_of = "comp"},
		["sup"] = {list = true},
		[3] = {alias_of = "sup"},
		["adv"] = {list = true},
		["indecl"] = {type = boolean},
		["id"] = {},
	}
	local args = require("Module:parameters").process(args, params)
	data.heads = args.head
	data.id = args.id

	if args.indecl then
		table.insert(data.inflections, {label = glossary_link("indeclinable")})
	end
	local comp = args.comp
	if #comp > 0 then
		comp.label = "comparative"
		table.insert(data.inflections, comp)
	end
	local sup = args.sup
	if #sup > 0 then
		sup.label = "superlative"
		table.insert(data.inflections, sup)
	end
	if #args.adv > 0 then
		args.adv.label = "adverb"
		table.insert(data.inflections, args.adv)
	end
end

local function adjectives_comp(pos, def, args, data, infl_classes, appendix)
	if args.is_lemma then
		-- Track so we can remove uses
		track("islemma")
	end
	local params = {
		[1] = {alias_of = 'head'},
		[2] = {alias_of = 'pos'},
		["head"] = {list = true, default = mw.title.getCurrentTitle().text},
		["pos"] = {list = true},
		["sup"] = {list = true},
		["islemma"] = {type = "boolean"},
		["is_lemma"] = {type = "boolean", alias_of = "islemma"},
		["indecl"] = {type = boolean},
		["id"] = {},
	}
	local args = require("Module:parameters").process(args, params)
	data.heads = args.head
	data.id = args.id
	if args.islemma then
		-- See below. This happens automatically by virtue of the default POS
		-- unless we overrride it, which we do when islemma.
		table.insert(data.categories, "Old English comparative " .. pos)
	end

	if args.indecl then
		table.insert(data.inflections, {label = glossary_link("indeclinable")})
	end
	if #args.pos > 0 then
		args.pos.label = "positive"
		table.insert(data.inflections, args.pos)
	elseif args.islemma then
		table.insert(data.inflections, {label = "no positive form"})
	end

	if #args.sup > 0 then
		args.sup.label = "superlative"
		table.insert(data.inflections, args.sup)
	end

	if args.islemma then
		-- If islemma, we're a comparative adjective without positive form,
		-- so we're treated as a lemma. In that case, we return "adjectives" as
		-- the part of speech, which will automatically categorize into
		-- "Old English adjectives" and "Old English lemmas", otherwise we don't
		-- return anything, which defaults to the passed-in POS (usually
		-- "comparative adjectives"), which will automatically categorize into
		-- that POS (e.g. "Old English comparative adjectives") and into
		-- "Old English non-lemma forms".
		return pos
	end
end

local function adjectives_sup(pos, def, args, data, infl_classes, appendix)
	if args.is_lemma then
		-- Track so we can remove uses
		track("islemma")
	end
	local params = {
		[1] = {alias_of = 'head'},
		[2] = {alias_of = 'pos'},
		["head"] = {list = true, default = mw.title.getCurrentTitle().text},
		["pos"] = {list = true},
		["comp"] = {list = true},
		["islemma"] = {type = "boolean"},
		["is_lemma"] = {type = "boolean", alias_of = "islemma"},
		["indecl"] = {type = boolean},
		["id"] = {},
	}
	local args = require("Module:parameters").process(args, params)
	data.heads = args.head
	data.id = args.id

	if args.islemma then
		-- See below. This happens automatically by virtue of the default POS
		-- unless we overrride it, which we do when islemma.
		table.insert(data.categories, "Old English superlative " .. pos)
	end

	if args.indecl then
		table.insert(data.inflections, {label = glossary_link("indeclinable")})
	end
	if #args.pos > 0 then
		args.pos.label = "positive"
		table.insert(data.inflections, args.pos)
	end
	if #args.comp > 0 then
		args.comp.label = "comparative"
		table.insert(data.inflections, args.comp)
	end
	if #args.pos == 0 and #args.comp == 0 and args.islemma then
		table.insert(data.inflections, {label = "no positive or comparative form"})
	end

	if args.islemma then
		-- If islemma, we're a superlative adjective without positive form,
		-- so we're treated as a lemma. In that case, we return "adjectives" as
		-- the part of speech, which will automatically categorize into
		-- "Old English adjectives" and "Old English lemmas", otherwise we don't
		-- return anything, which defaults to the passed-in POS (usually
		-- "superlative adjectives"), which will automatically categorize into
		-- that POS (e.g. "Old English superlative adjectives") and into
		-- "Old English non-lemma forms".
		return pos
	end
end

pos_functions["adjectives"] = function(def, args, data, infl_classes, appendix)
	return adjectives("adjectives", def, args, data, infl_classes, appendix)
end

pos_functions["comparative adjectives"] = function(def, args, data, infl_classes, appendix)
	return adjectives_comp("adjectives", def, args, data, infl_classes, appendix)
end

pos_functions["superlative adjectives"] = function(def, args, data, infl_classes, appendix)
	return adjectives_sup("adjectives", def, args, data, infl_classes, appendix)
end
	
pos_functions["participles"] = function(def, args, data, infl_classes, appendix)
	return adjectives("participles", def, args, data, infl_classes, appendix)
end

pos_functions["determiners"] = function(def, args, data, infl_classes, appendix)
	return adjectives("determiners", def, args, data, infl_classes, appendix)
end

pos_functions["pronouns"] = function(def, args, data, infl_classes, appendix)
	return adjectives("pronouns", def, args, data, infl_classes, appendix)
end

pos_functions["suffixes-adjective"] = function(def, args, data, infl_classes, appendix)
	return adjectives("suffixes", def, args, data, infl_classes, appendix)
end

pos_functions["numerals-adjective"] = function(def, args, data, infl_classes, appendix)
	return adjectives("numerals", def, args, data, infl_classes, appendix)
end

pos_functions["adverbs"] = function(def, args, data, infl_classes, appendix)
	local params = {
		[1] = {alias_of = 'head'},
		[2] = {alias_of = 'comp'},
		[3] = {alias_of = 'sup'},
		["head"] = {list = true},
		["comp"] = {list = true},
		["sup"] = {list = true},
		["id"] = {},
	}

	local args = require("Module:parameters").process(args, params)
	data.heads = args.head
	data.id = args.id
	local comp, sup

	if args.comp[1] == "-" then
		comp = "-"
	elseif #args.comp > 0 then
		args.comp.label = glossary_link("comparative")
		comp = args.comp
	end
	if args.comp[1] == "-" or args.sup[1] == "-" then
		sup = "-"
	elseif #args.sup > 0 then
		args.sup.label = glossary_link("superlative")
		sup = args.sup
	end

	if comp == "-" then
		table.insert(data.inflections, {label = "not [[Appendix:Glossary#comparative|comparable]]"})
		table.insert(data.categories, "Old English uncomparable adverbs")
	else
		table.insert(data.inflections, comp)
	end
	if sup == "-" then
		if comp ~= "-" then
			table.insert(data.inflections, {label = "no [[Appendix:Glossary#superlative|superlative]]"})
		end
	else
		table.insert(data.inflections, sup)
	end
end

pos_functions["comparative adverbs"] = function(def, args, data, infl_classes, appendix)
	local params = {
		[1] = {alias_of = 'head'},
		[2] = {alias_of = 'pos'},
		["head"] = {list = true, default = mw.title.getCurrentTitle().text},
		["pos"] = {list = true},
		["sup"] = {list = true},
		["islemma"] = {type = "boolean"},
		["id"] = {},
	}
	local args = require("Module:parameters").process(args, params)
	data.heads = args.head
	data.id = args.id
	if args.islemma then
		-- See below. This happens automatically by virtue of the default POS
		-- unless we overrride it, which we do when islemma.
		table.insert(data.categories, "Old English comparative adverbs")
	end

	if #args.pos > 0 then
		args.pos.label = "positive"
		table.insert(data.inflections, args.pos)
	elseif args.islemma then
		table.insert(data.inflections, {label = "no positive form"})
	end

	if #args.sup > 0 then
		args.sup.label = "superlative"
		table.insert(data.inflections, args.sup)
	end

	if args.islemma then
		-- See the corresponding comment in adjectives_comp().
		return "adverbs"
	end
end

pos_functions["superlative adverbs"] = function(def, args, data, infl_classes, appendix)
	local params = {
		[1] = {alias_of = 'head'},
		[2] = {alias_of = 'pos'},
		["head"] = {list = true, default = mw.title.getCurrentTitle().text},
		["pos"] = {list = true},
		["comp"] = {list = true},
		["islemma"] = {type = "boolean"},
		["id"] = {},
	}
	local args = require("Module:parameters").process(args, params)
	data.heads = args.head
	data.id = args.id

	if args.islemma then
		-- See below. This happens automatically by virtue of the default POS
		-- unless we overrride it, which we do when islemma.
		table.insert(data.categories, "Old English superlative adverbs")
	end

	if #args.pos > 0 then
		args.pos.label = "positive"
		table.insert(data.inflections, args.pos)
	end
	if #args.comp > 0 then
		args.comp.label = "comparative"
		table.insert(data.inflections, args.comp)
	end
	if #args.pos == 0 and #args.comp == 0 and args.islemma then
		table.insert(data.inflections, {label = "no positive or comparative form"})
	end

	if args.islemma then
		-- See the corresponding comment in adjectives_comp().
		return "adverbs"
	end
end

pos_functions["suffixes-adverb"] = pos_functions["adverbs"]

local function non_lemma_forms(def, args, data, infl_classes, appendix, postscript)
	local params = {
		[1] = {required = true, default = def}, -- headword or cases
		["head"] = {list = true, require_index = true},
		["g"] = {list = true},
		["id"] = {},
	}

	local args = require("Module:parameters").process(args, params)

	local heads = {args[1]}
	for _, head in ipairs(args.head) do
		table.insert(heads, head)
	end
	data.heads = heads
	data.genders = args.g
	data.id = args.id
end

pos_functions["noun forms"] = non_lemma_forms
pos_functions["proper noun forms"] = non_lemma_forms
pos_functions["pronoun forms"] = non_lemma_forms
pos_functions["verb forms"] = non_lemma_forms
pos_functions["adjective forms"] = non_lemma_forms
pos_functions["participle forms"] = non_lemma_forms
pos_functions["determiner forms"] = non_lemma_forms
pos_functions["numeral forms"] = non_lemma_forms
pos_functions["suffix forms"] = non_lemma_forms

return export

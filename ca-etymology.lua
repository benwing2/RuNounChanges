local export = {}

local com = require("Module:ca-common")
local lang = require("Module:languages").getByCode("ca")


local function looks_like_infinitive(term)
	return term:find("[aeiu]r$") or term:find("re$")
end


local function form_imperative(imp, inf, parse_err)
	local stem, ending = inf:match("^(.*)([aei]r)$")
	if not stem then
		stem, ending = inf:match("^(.*)(re)$")
	end
	if not stem then
		parse_err(("Unrecognized infinitive '%s', doesn't end in -ar, -er, -ir, -ur or -re"):format(inf))
	end
	if imp ~= "+" then
		parse_err(("Unrecognized imperative spec '%s'"):format(imp))
	end
	if ending == "ar" then
		return stem .. "a"
	else
		-- córrer -> corre, tòrcer -> torce
		-- The addition of -e applies even in cases like [[tòrcer]] where the third-singular present isn't expected to
		-- have an -e, and to cases like [[cobrir]] that have -eix in the third-singular present.
		return com.remove_accents(stem) .. "e"
	end
end


local function form_plural(pl, term, parse_err)
	if pl ~= "1" then
		parse_err(("Unrecognized plural spec '%s'"):format(pl))
	end
	-- FIXME, maybe we can do better than default to masculine.
	local pls = com.make_plural(term, "m")
	if #pls == 0 then
		parse_err(("Can't form plural of '%s'"):format(term))
	else
		return pls[1]
	end
end


function export.ca_verb_obj(frame)
	local data = {
		lang = lang,
		looks_like_infinitive = looks_like_infinitive,
		default_args = {"cercar<t:to seek>", "tresor<t:treasures><pl:1>"},
		make_plural = form_plural,
		make_imperative = form_imperative,
	}
	return require("Module:romance etymology").verb_obj(data, frame)
end


function export.ca_verb_verb(frame)
	local data = {
		lang = lang,
		looks_like_infinitive = looks_like_infinitive,
		default_args = {"anar<t:go><imp:va>", "i", "venir<t:come><imp:ve>"},
		make_plural = form_plural,
		make_imperative = form_imperative,
	}
	return require("Module:romance etymology").verb_verb(data, frame)
end


return export

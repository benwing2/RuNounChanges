local export = {}

local com = require("Module:es-common")
local lang = require("Module:languages").getByCode("es")


local function looks_like_infinitive(term)
	return term:find("[aei]r$")
end


local function form_imperative(imp, inf, parse_err)
	local stem, ending = inf:match("^(.*)([aei]r)$")
	if not stem then
		parse_err(("Unrecognized infinitive '%s', doesn't end in -ar, -er or -ir"):format(inf))
	end
	local alternation = rmatch(imp, "^%+(.*)$")
	if not alternation then
		parse_err(("Unrecognized imperative spec '%s'"):format(imp))
	end
	if alternation ~= "" then
		local alt_and_err = com.apply_vowel_alternation(stem, alternation)
		if alt_and_err.err then
			parse_err(("Can't apply alternation '%s' to stem '%s'; %s"):format(
				alternation, stem, alt_and_err.err))
		end
		stem = alt_and_err.ret
	end
	if ending == "ar" then
		return stem .. "a"
	else
		return stem .. "e"
	end
end


local function form_plural(pl, term, parse_err)
	if pl ~= "1" then
		parse_err(("Unrecognized plural spec '%s'"):format(pl))
	end
	return require(com_module).make_plural(term)
end


function export.es_verb_obj(frame)
	local data = {
		lang = lang,
		looks_like_infinitive = looks_like_infinitive,
		default_args = {"lavar<t:to wash>", "plato<t:dishes><pl:1>"},
		make_plural = form_plural,
		make_imperative = form_imperative,
	}
	return require("Module:romance etymology").verb_obj(data, frame)
end


function export.es_verb_verb(frame)
	local data = {
		lang = lang,
		looks_like_infinitive = looks_like_infinitive,
		default_args = {"andar<t:go><imp:va>", "y", "venir<t:come><imp:vén>"},
		make_plural = form_plural,
		make_imperative = form_imperative,
	}
	return require("Module:romance etymology").verb_verb(data, frame)
end


return export

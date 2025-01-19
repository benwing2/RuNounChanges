local export = {}

local string_utilities_module = "Module:string utilities"
local parse_utilities_module = "Module:parse utilities"
local table_module = "Module:table"

--[=[
Loaders for functions in other modules, which overwrite themselves with the target function when called. This ensures
modules are only loaded when needed, retains the speed/convenience of locally-declared pre-loaded functions, and has no
overhead after the first call, since the target functions are called directly in any subsequent calls.
]=]
local function rfind(...)
	rfind = require(string_utilities_module).find
	return rfind(...)
end

local function rsplit(...)
	rsplit = require(string_utilities_module).split
	return rsplit(...)
end

local function split_on_comma(...)
	split_on_comma = require(parse_utilities_module).split_on_comma
	return split_on_comma(...)
end

local function split_escaping(...)
	split_escaping = require(parse_utilities_module).split_escaping
	return split_escaping(...)
end

local function parse_inline_modifiers(...)
	parse_inline_modifiers = require(parse_utilities_module).parse_inline_modifiers
	return parse_inline_modifiers(...)
end

local function parse_term_with_lang(...)
	parse_term_with_lang = require(parse_utilities_module).parse_term_with_lang
	return parse_term_with_lang(...)
end

local function term_contains_top_level_html(...)
	term_contains_top_level_html = require(parse_utilities_module).term_contains_top_level_html
	return term_contains_top_level_html(...)
end

local function escape_comma_whitespace(...)
	escape_comma_whitespace = require(parse_utilities_module).escape_comma_whitespace
	return escape_comma_whitespace(...)
end

local function unescape_comma_whitespace(...)
	unescape_comma_whitespace = require(parse_utilities_module).unescape_comma_whitespace
	return unescape_comma_whitespace(...)
end

local function shallow_copy(...)
	shallow_copy = require(table_module).shallowCopy
	return shallow_copy(...)
end

local function decode_entities(...)
	-- FIXME: Why are we doing this? It was added to [[Module:form of/templates]] in
	-- https://en.wiktionary.org/w/index.php?title=Module:form_of/templates&diff=prev&oldid=81900806 on 2024-09-24
	-- by [[User:Theknightwho]] with the comment "Optimisations + decode HTML entities.".
	--
	-- NOTE: We could add a check for & in the term before calling decode_entities(), but in practice,
	-- [[Module:string utilities]] is essentially always loaded so there's little point.
	str_decode_entities = require(string_utilities_module).decode_entities
	return str_decode_entities(...)
end


--[==[
This is an almost drop-in replacement for split_on_comma() in [[Module:parse utilities]], with optimizations to avoid
loading and running the while algorithm in [[Module:parse utilities]] except when necessary.
]==]
local function export.split_on_comma(val)
	if val:find(",%s") or (val:find(",") and val:find("[\\%[<]")) then
		-- Comma after whitespace not split; nor are backslash-escaped commas or commas inside of square or
		-- angle brackets. If we see any of these, use the more sophisticated algorithm in
		-- [[Module:parse utilities]]. Otherwise it's safe to just split on commas directly. This optimization
		-- avoids loading [[Module:parse utilities]] unnecessarily.
		return split_on_comma(val)
	else
		return rsplit(val, ",")
	end
end


--[==[
This is similar to parse_term_with_lang() in [[Module:parse utilities]], but if there is no colon + non-space in the
term, it will be returned directly and not parsed into link/display format. If you need the link/display arguments
even in the absence of a language prefix, call [[Module:parse utilities]] directly.
]==]
local function export.parse_term_with_lang(data)
	if data.term:find(":[^ ]") then
		return parse_term_with_lang(data)
	else
		return data.term, nil, nil, nil
	end
end


--[==[
This is an almost drop-in replacement for parse_inline_modifiers() in [[Module:parse utilities]] except that
# it won't attempt to parse inline modifiers if it detects that top-level HTML is present (but it will still split on
  `splitchar` if given, unless it detects the presence of the {{tl|,}} template);
# it has a default for `generate_obj` that simply sets `lang` and `term` after calling `decode_entities()` on the term
  (FIXME: this was inherited from code added to [[Module:form of/templates]] by [[User:Theknightwho]]; I don't know why
  it is necessary);
# it has a lot of optimizations to avoid loading [[Module:parse utilities]] in simple cases where there are no `<` signs  and (when `splitchar` is given) either there are no delimiters present at all or no characters present that will make
  a simple split on `splitchar` invalid.

Generally you should use this in preference to either calling parse_inline_modifiers() directly in
[[Module:parse utilities]] or rolling your own front-end function.
]==]
function export.parse_inline_modifiers(val, props)
	local paramname, lang, splitchar = props.paramname, props.lang, props.splitchar
	local preserve_splitchar, escape_fun, unescape_fun = props.preserve_splitchar, props.escape_fun, props.unescape_fun
	local outer_container = props.outer_container
	local generate_obj = props.generate_obj or function(term)
		return {lang = lang, term = decode_entities(term)}
	end
	local delimiter_key = props.delimiter_key or "delimiter"

	-- Check for inline modifier, e.g. מרים<tr:Miryem>. But exclude HTML entry with <span ...>, <i ...>, <br/> or
	-- similar in it, caused by wrapping an argument in {{l|...}}, {{af|...}} or similar. Basically, all tags of
	-- the sort we parse here should consist of a less-than sign, plus letters, plus a colon, e.g. <tr:...>, so if
	-- we see a tag on the outer level that isn't in this format, we don't try to parse it. The restriction to the
	-- outer level is to allow generated HTML inside of e.g. qualifier tags, such as foo<q:similar to {{m|fr|bar}}>.
	if val:find("<") and not term_contains_top_level_html(val) then
		if not props.generate_obj then
			props = shallow_copy(props)
			props.generate_obj = generate_obj
		end
		return parse_inline_modifiers(val, props)
	end
	if not splitchar then
		return generate_obj(val)
	end
	local retval
	if splitchar == "," and not escape_fun and not unescape_fun then
		if val:find(",<") then
			-- This happens when there's an embedded {{,}} template, as in [[MMR]], [[TMA]], [[DEI]], where an
			-- initialism expands to multiple terms; easiest not to try and parse the lemma spec as multiple lemmas.
			retval = {val}
		else
			retval = export.split_on_comma(val)
		end
		for i, split in ipairs(retval) do
			retval[i] = generate_obj(split)
			if preserve_splitchar and i > 1 then
				retval[delimiter_key] = ","
			end
		end
	elseif rfind(val, splitchar) then
		if val:find(",<") then
			-- This happens when there's an embedded {{,}} template, as in [[MMR]], [[TMA]], [[DEI]], where an
			-- initialism expands to multiple terms; easiest not to try and parse the lemma spec as multiple lemmas.
			retval = {val}
		elseif escape_fun or unescape_fun or val:find(",%s") or val:find("[\\%[<]") then
			retval = split_escaping(val, splitchar, preserve_splitchar, escape_fun or escape_comma_whitespace,
				unescape_fun or unescape_comma_whitespace)
		elseif preserve_splitchar then
			retval = rsplit(val, "(" .. splitchar .. ")")
		else
			retval = rsplit(val, splitchar)
		end
		if preserve_splitchar then
			local new_retval = {}
			for j = 1, #retval, 2 do
				local obj = generate_obj(retval[j])
				if j > 1 then
					obj[delimiter_key] = retval[j - 1]
				end
				table.insert(new_retval, obj)
			end
			retval = new_retval
		else
			for i, split in ipairs(retval) do
				retval[i] = generate_obj(split)
			end
		end
	else
		retval = {generate_obj(val)}
	end

	if outer_container then
		outer_container.terms = retval
		return outer_container
	end
	return retval
end

return export

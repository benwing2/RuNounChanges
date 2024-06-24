local export = {}

local dump = mw.dumpObject
local IPA_module = "Module:IPA"
local parameter_utilities_module = "Module:parameter utilities"
local pron_qualifier_module = "Module:pron qualifier"

--[==[ intro:
This module provides utilities to simplify and standardize the creation of pronunciation modules, particularly when it
comes to argument parsing. Using this module, it should only be necessary to provide the function that actually converts
respelling to IPA.
]==]

local function combine_qualifiers(q1, q2)
	if type(q1) == "string" then
		q1 = {q1}
	end
	if type(q2) == "string" then
		q2 = {q2}
	end
	if not q1 then
		return q2
	end
	if not q2 then
		return q1
	end
	local qs = mw.clone(q1)
	for _, q in ipairs(q2) do
		table.insert(qs, q)
	end
	return qs
end

--[==[
Function to parse arguments and format one or more pronunciations. Meant to be called from a module. `data` is a table
containing the following fields:<ul>
<li> `lang` ('''required'''): Language object for the respellings.
<li> `raw_args` ('''required'''): Unparsed arguments, generally taken from {frame:getParent().args}.
<li> `respelling_to_IPA` ('''required'''): Function to generate one or more pronunciations given respelling. On input, the
  function is passed a single object `data` with the following fields:<ul>
  <li> `respelling`: The respelling.
  <li> `orig_respelling`: The original respelling; may be {nil} or `+` (which is substituted with the pagename).
  <li> `item`: The item parsed from the argument containing the respelling, along with inline modifiers and separate
     parameters.
  <li> `args`: The parsed `args` table generated from `raw_args`.
  <li> `pagename`: The pagename, either taken from `args.pagename` or from the actual pagename.</ul>
  The function should return either a string (the respelling); a table with the respelling in the `pron` field and
  optional left and right regular and/or accent qualifiers in (respectively) `q`, `qq`, `a` and `aa`; a list of
  respelling strings; or a list of respelling+qualifier tables. If regular or accent qualifiers are returned, they will
  be combined with any user-specified qualifiers (which go first).
<li> `track_module` ('''recommended'''): Name of the invoking module, for debug-tracking purposes.
<li> `include_bullet`: If specified, a bullet (`*`) will be added before the generated pronunciation. When this is given,
  extra parameters {{para|bullets}} (to override the number of added bullets) and {{para|pre}} (to specify text to
  insert between the bullets and the generated pronunciation) will be available. '''Use of this field is not
  recommended; it is provided for compatibility only.'''
<li> `augment_params`: If specified, a key-value table of arguments to add to the `params` table, prior to parsing the
  raw arguments using `process` in [[Module:parameters]]. See [[Module:fr-pron]] for an example of specifying this
  field.
<li> `augment_param_mod_spec`: If specified, a list of specs of the form accepted by `construct_param_mods()` in
  [[Module:parameter utilities]] to add to the default specs (which specify the following inline modifiers and separate
  parameters: {{para|q}} and {{cd|<q:...>}}; {{para|qq}} and {{cd|<qq:...>}}; {{para|a}} and {{cd|<a:...>}};
  {{para|aa}} and {{cd|<aa:...>}}; and {{para|ref}} and {{cd|<ref:...>}}. See [[Module:fr-pron]] for an example of
  specifying this field.
</ul>
]==]
function export.format_prons(data)
	local params = {
		[1] = {list = true, allow_holes = true, default = "+"},
		["pagename"] = {},
		["notext"] = {},
	}
	if data.include_bullet then
		params["pre"] = {}
		params["bullets"] = {type = "number", default = 1}
	end
	if data.augment_params then
		for k, v in pairs(data.augment_params) do
			params[k] = v
		end
	end

	local m_param_utils = require(parameter_utilities_module)

	local construct_param_mod_spec = {
		{group = {"q", "a", "ref"}},
		{group = "link", include = {"t", "gloss", "pos"}},
	}
	if data.augment_param_mod_spec then
		for _, spec in ipairs(data.augment_param_mod_spec) do
			table.insert(construct_param_mod_spec, spec)
		end
	end

	local param_mods = m_param_utils.construct_param_mods(construct_param_mod_spec)

	local items, args = m_param_utils.process_list_arguments {
		params = params,
		param_mods = param_mods,
		raw_args = data.raw_args,
		termarg = 1,
		term_dest = "pron",
		track_module = data.track_module,
	}

	local pagename = args.pagename or mw.loadData("Module:headword/data").pagename

	local saw_multiple_prons = false
	for i, item in ipairs(items) do
		local respelling = item.pron or "+"
		if respelling == "+" then
			respelling = pagename
		end
		local pron = data.respelling_to_IPA {
			orig_respelling = item.pron,
			respelling = respelling,
			item = item,
			args = args,
			pagename = pagename,
		}
		if type(pron) == "table" and not pron.pron then
			-- assume a list
			if pron[1] and not pron[2] then
				-- a single-element list
				pron = pron[1]
			else
				saw_multiple_prons = true
			end
		end
		item.pron = pron
	end

	if saw_multiple_prons then
		-- we need to flatten out the pronuns
		local pron_items = {}
		for _, item in ipairs(items) do
			local prons = item.pron
			if type(prons) ~= "table" then
				prons = {prons}
			end
			if prons.pron then
				-- a single item with qualifiers, not a list
				prons = {prons}
			end
			for i, pron in ipairs(prons) do
				if type(pron) ~= "table" then
					-- a string; convert to item table with qualifiers
					pron = {pron = pron}
				end
				if not pron.pron then
					error(("Internal error: Pronunciation table doesn't have a pronunciation in '.pron': %s"):format(
						dump(pron)))
				end
				pron.separator = i == 1 and item.separator or " ~ "
				if i == 1 then
					pron.q = combine_qualifiers(item.q, pron.q)
					pron.a = combine_qualifiers(item.a, pron.a)
					pron.pos = item.pos
					pron.gloss = item.gloss
				end
				if i == #prons then
					pron.refs = item.refs
					pron.qq = combine_qualifiers(item.qq, pron.qq)
					pron.aa = combine_qualifiers(item.aa, pron.aa)
				end
				if not pron_items then
					pron_items = {pron}
				else
					table.insert(pron_items, pron)
				end
			end
		end
		items = pron_items
	else
		for _, item in ipairs(items) do
			if type(item.pron) == "table" then
				if not item.pron.pron then
					error(("Internal error: Pronunciation table doesn't have a pronunciation in '.pron': %s"):format(
						dump(item.pron)))
				end
				item.q = combine_qualifiers(item.q, item.pron.q)
				item.a = combine_qualifiers(item.a, item.pron.a)
				item.qq = combine_qualifiers(item.qq, item.pron.qq)
				item.aa = combine_qualifiers(item.aa, item.pron.aa)
				item.pron = item.pron.pron
			end
		end
	end

	local prontext
	local q = args.q.default
	local qq = args.qq.default
	local a = args.a.default
	local aa = args.aa.default
	if args.notext then
		prontext = require(IPA_module).format_IPA_multiple(data.lang, items)
		if q and q[1] or qq and qq[1] or a and a[1] or aa and aa[1] then
			prontext = require(pron_qualifier_module).format_qualifiers {
				lang = data.lang,
				text = prontext,
				q = q,
				qq = qq,
				a = a,
				aa = aa,
			}
		end
	else
		prontext = require(IPA_module).format_IPA_full {
			lang = data.lang,
			items = items,
			q = q,
			qq = qq,
			a = a,
			aa = aa,
		}
	end
	if args.pre then
		prontext = args.pre .. " " .. prontext
	end
	if args.bullets and args.bullets ~= 0 then
		prontext = ("*"):rep(args.bullets) .. " " .. prontext
	end
	return prontext
end

return export

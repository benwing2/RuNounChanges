local export = {}

local m_links = require("Module:links")
local parameter_utilities_module = "Module:parameter utilities"
local pron_qualifier_module = "Module:pron qualifier"
local string_utilities_module = "Module:string utilities"

local function rsplit(text, pattern)
	return require(string_utilities_module).split(text, pattern)
end

local function track(page)
	require("Module:debug/track")("homophones/" .. page)
	return true
end

--[==[
Meant to be called from a module. `data` is a table containing the following fields:
* `lang`: language object for the homophones;
* `homophones`: a list of homophones, each described by an object which can contain all the fields in the object
  passed to {full_link()} in [[Module:links]] except for `lang` and `sc` (which are copied from the outer level), and in
  addition can contain left and right regular and accent qualifier fields:
  ** `term`: the homophone itself;
  ** `alt`: display text for the homophone, as in {{tl|l}};
  ** `gloss`: gloss for the homophone, as in {{tl|l}};
  ** `tr`: transliteration for the homophone, as in {{tl|l}};
  ** `ts`: transcription for the homophone, as in {{tl|l}};
  ** `genders`: list of genders for the homophone, as in {{tl|l}};
  ** `pos`: part of speech of the homophone, as in {{tl|l}};
  ** `lit`: literal meaning of the homophone, as in {{tl|l}};
  ** `id`: sense ID for the homophone, as in {{tl|l}};
  ** `q`: {nil} or a list of left regular qualifier strings, formatted using {format_qualifier()} in [[Module:qualifier]]
     and displayed directly before the homophone in question;
  ** `qq`: {nil} or a list of right regular qualifier strings, displayed directly after the homophone in question;
  ** `qualifiers`: {nil} or a list of qualifier strings; currently displayed on the right but that may change; for
     compatibility purposes only, do not use in new code;
  ** `a`: {nil} or a list of left accent qualifier strings, formatted using {format_qualifiers()} in
     [[Module:accent qualifier]] and displayed directly before the homophone in question;
  ** `aa`: {nil} or a list of right accent qualifier strings, displayed directly after the homophone in question;
  ** `refs`: {nil} or a list of references or reference specs to add after the pronunciation and any posttext and
	 qualifiers; the value of a list item is either a string containing the reference text (typically a call to a
	 citation template such as {{tl|cite-book}}, or a template wrapping such a call), or an object with fields `text`
	 (the reference text), `name` (the name of the reference, as in {{cd|<nowiki><ref name="foo">...</ref></nowiki>}}
	 or {{cd|<nowiki><ref name="foo" /></nowiki>}}) and/or `group` (the group of the reference, as in
	 {{cd|<nowiki><ref name="foo" group="bar">...</ref></nowiki>}} or
	 {{cd|<nowiki><ref name="foo" group="bar"/></nowiki>}}); this uses a parser function to format the reference
	 appropriately and insert a footnote number that hyperlinks to the actual reference, located in the
	 {{cd|<nowiki><references /></nowiki>}} section;
* `q`: {nil} or a list of left regular qualifier strings, formatted using {format_qualifier()} in [[Module:qualifier]]
  and displayed before the initial caption;
* `qq`: {nil} or a list of right regular qualifier strings, displayed after all homophones;
* `a`: {nil} or a list of left accent qualifier strings, formatted using {format_qualifiers()} in
  [[Module:accent qualifier]] and dispalyed before the initial caption;
* `aa`: {nil} or a list of right accent qualifier strings, displayed after all homophones;
* `sc`: {nil} or script object for the homophones;
* `sort`: {nil} or sort key;
* `caption`: {nil} or string specifying the caption to use, in place of {"Homophone"} (if there is a single homophone),
  or {"Homophones"} (otherwise); a colon and space is automatically added after the caption;
* `nocaption`: If true, suppress the caption display.
* `nocat`: If true, suppress categorization.

If both regular and accent qualifiers on the same side and at the same level are specified, the accent qualifiers precede
the regular qualifiers on both left and right.

'''WARNING''': Destructively modifies the objects inside the `homophones` field.
]==]
function export.format_homophones(data)
	local hmptexts = {}
	local hmpcats = {}

	local overall_sep = data.separator or ", "
	for i, hmp in ipairs(data.homophones) do
		hmp.lang = hmp.lang or data.lang
		hmp.sc = hmp.sc or data.sc
		local text = m_links.full_link(hmp)
		if hmp.q and hmp.q[1] or hmp.qq and hmp.qq[1] or hmp.qualifiers and hmp.qualifiers[1]
			or hmp.a and hmp.a[1] or hmp.aa and hmp.aa[1] or hmp.refs and hmp.refs[1] then
			-- FIXME, change handling of `qualifiers`
			text = require(pron_qualifier_module).format_qualifiers {
				lang = hmp.lang,
				text = text,
				q = hmp.q,
				qq = hmp.qq,
				qualifiers = hmp.qualifiers,
				qualifiers_right = true,
				a = hmp.a,
				aa = hmp.aa,
				refs = hmp.refs,
			}
		end
		table.insert(hmptexts, hmp.separator or i > 1 and overall_sep or "")
		table.insert(hmptexts, text)
	end

	table.insert(hmpcats, data.lang:getCanonicalName() .. " terms with homophones")
	local text = table.concat(hmptexts)
	local caption = data.nocaption and "" or (
		data.caption or "[[Appendix:Glossary#homophone|Homophone" .. (#data.homophones > 1 and "s" or "") .. "]]"
	) .. ": "
	text = caption .. text
	if data.q and data.q[1] or data.qq and data.qq[1] or data.a and data.a[1] or data.aa and data.aa[1] then
		text = require(pron_qualifier_module).format_qualifiers {
			lang = data.lang,
			text = text,
			q = data.q,
			qq = data.qq,
			a = data.a,
			aa = data.aa,
		}
	end
	text = "<span class=\"homophones\">" .. text .. "</span>"
	if not data.nocat then
		local categories = require("Module:utilities").format_categories(hmpcats, data.lang, data.sort)
		text = text .. categories
	end
	return text
end


--[==[
Entry point for {{tl|homophones}} template (also written {{tl|homophone}} and {{tl|hmp}}).
]==]
function export.show(frame)
	local parent_args = frame:getParent().args
	local compat = parent_args.lang
	local offset = compat and 0 or 1

	local params = {
		[compat and "lang" or 1] = {required = true, type = "language", etym_lang = true, default = "en"},
		[1 + offset] = {list = true, required = true, allow_holes = true, default = "term"},
		["caption"] = {},
		["nocaption"] = {type = "boolean"},
		["nocat"] = {type = "boolean"},
		["sort"] = {},
	}

	local param_mods = {
		alt = {},
		t = {
			-- We need to store the t1=/t2= param and the <t:...> inline modifier into the "gloss" key of the parsed term,
			-- because that is what [[Module:links]] expects.
			item_dest = "gloss",
		},
		gloss = {
			-- The `extra_specs` handles the fact that "gloss" is an alias of "t".
			extra_specs = {alias_of = "t"},
		},
		tr = {},
		ts = {},
		g = {
			-- We need to store the g1=/g2= param and the <g:...> inline modifier into the "genders" key of the parsed term,
			-- because that is what [[Module:links]] expects.
			item_dest = "genders",
			convert = function(arg, parse_err)
				return rsplit(arg, ",")
			end,
		},
		pos = {},
		lit = {},
		id = {},
		sc = {
			separate_no_index = true,
			extra_specs = {type = "script"},
		},
	}

	local m_param_utils = require(parameter_utilities_module)

	m_param_utils.augment_param_mods_with_pron_qualifiers(param_mods)
	m_param_utils.augment_params_with_modifiers(params, param_mods)

	local args = require("Module:parameters").process(parent_args, params)

	-- FIXME: temporary.
	if args.q.default then
		error("Use of q= in [[Template:homophones]] no longer permitted; use qq1=; in a month or two, q= will return as an overall left qualifier")
	end
	if args.q.maxindex > 0 then
		error("Use of qN= in [[Template:homophones]] no longer permitted; use qqN=; in a month or two, qN= will return as left qualifiers")
	end

	local lang = args[compat and "lang" or 1]

	local homophones = m_param_utils.process_list_arguments {
		args = args,
		param_mods = param_mods,
		termarg = 1 + offset,
		parse_lang_prefix = true,
		track_module = "homophones",
		lang = lang,
		sc = args.sc.default,
	}

	local data = {
		lang = lang,
		homophones = homophones,
		caption = args.caption,
		nocaption = args.nocaption,
		nocat = args.nocat,
		sc = args.sc.default,
		sort = args.sort,
	}
	require(pron_qualifier_module).parse_qualifiers {
		store_obj = data,
		q = args.q.default,
		qq = args.qq.default,
		a = args.a.default,
		aa = args.aa.default,
	}

	return export.format_homophones(data)
end

return export

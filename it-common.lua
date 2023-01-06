local export = {}

local romut_module = "Module:romance utilities"

local rsplit = mw.text.split

local prepositions = {
	-- a, da + optional article
	"d?al? ",
	"d?all[oae] ",
	"d?all'",
	"d?ai ",
	"d?agli ",
	-- di, in + optional article
	"di ",
	"d'",
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

function export.parse_abbreviated_references_spec(spec)
	local spec_before_modifiers, modifiers = spec:match("^(.-)(<<.*>>)$")
	if spec_before_modifiers then
		spec = spec_before_modifiers
	else
		modifiers = ""
	end
	local template_name, props = spec:match("^([^:]+):(.*)$")
	if not template_name then
		template_name = spec
		props = ""
	else
		if props:find(",%s") then
			props = require("Module:parse utilities").split_on_comma(props)
		else
			props = rsplit(props, ",")
		end
		for i, prop in ipairs(props) do
			if prop:find("#") then
				local param, val = prop:match("^(.-)#(.*)$")
				props[i] = "|" .. param .. "=" .. val
			else
				props[i] = "|" .. prop
			end
		end
		props = table.concat(props)
	end
	return mw.getCurrentFrame():preprocess(("{{R:it:%s%s}}"):format(template_name, props)) .. modifiers
end

-- Given a term `term`, if the term is multiword (either through spaces or hyphens), handle inflection of the term by
-- calling handle_multiword() in [[Module:romance utilities]]. `special` indicates which parts of the multiword term to
-- inflect, and `inflect` is a function of one argument to inflect the individual parts of the term. As an optimization,
-- if the term is not multiword and `special` is not given, do nothing.
local function call_handle_multiword(term, special, inflect)
	if not special and not term:find("[ %-]") then
		return nil
	end
	local retval = require(romut_module).handle_multiword(term, special, inflect, prepositions)
	if retval and #retval > 0 then
		if #retval ~= 1 then
			error("Internal error: Should have only one return value from inflection function: " .. table.concat(retval, ","))
		end
		return retval[1]
	end
	return nil
end

-- Generate a default plural form, which is correct for most regular nouns and adjectives.
function export.make_plural(term, gender, special)
	local plspec
	if special == "cap*" or special == "cap*+" then
		plspec = special
		special = nil
	end
	local retval = call_handle_multiword(term, special, function(term) return make_plural(term, gender, plspec) end)
	if retval then
		return retval
	end

	local function check_no_mf()
		if gender == "mf" or gender == "mfbysense" or gender == "?" then
			error("With gender=" .. gender .. ", unable to pluralize term '" .. term .. "'"
				.. (special and " using special=" .. special or "") .. " because its plural is gender-specific")
		end
	end

	if plspec == "cap*" or plspec == "cap*+" then
		check_no_mf()
		if not term:find("^capo") then
			error("With special=" .. plspec .. ", term '" .. term .. "' must begin with capo-")
		end
		if gender == "m" then
			term = term:gsub("^capo", "capi")
		end
		if plspec == "cap*" then
			return term
		end
	end

	if term:find("io$") then
		term = term:gsub("io$", "i")
	elseif term:find("ologo$") then
		term = term:gsub("o$", "i")
	elseif term:find("[ia]co$") then
		term = term:gsub("o$", "i")
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
	elseif term:find("[cg]o$") then
		term = term:gsub("o$", "hi")
	elseif term:find("o$") then
		term = term:gsub("o$", "i")
	elseif term:find("[cg]a$") then
		check_no_mf()
		term = term:gsub("a$", (gender == "m" and "hi" or "he"))
	elseif term:find("logia$") then
		if gender ~= "f" then
			error("Term '" .. term .. "' ending in -logia should have gender=f if it is using the default plural")
		end
		term = term:gsub("a$", "e")
	elseif term:find("[cg]ia$") then
		check_no_mf()
		term = term:gsub("ia$", (gender == "m" and "i" or "e"))
	elseif term:find("a$") then
		check_no_mf()
		term = term:gsub("a$", (gender == "m" and "i" or "e"))
	elseif term:find("e$") then
		term = term:gsub("e$", "i")
	else
		return nil
	end
	return term
end

-- Generate a default feminine form.
function export.make_feminine(term, special)
	local retval = call_handle_multiword(term, special, make_feminine)
	if retval then
		return retval
	end

	-- Don't directly return gsub() because then there will be multiple return values.
	if term:find("o$") then
		term = term:gsub("o$", "a")
	elseif term:find("tore$") then
		term = term:gsub("tore$", "trice")
	elseif term:find("one$") then
		term = term:gsub("one$", "ona")
	end

	return term
end

-- Generate a default masculine form.
function export.make_masculine(term, special)
	local retval = call_handle_multiword(term, special, make_masculine)

	-- Don't directly return gsub() because then there will be multiple return values.
	if term:find("a$") then
		term = term:gsub("a$", "o")
	elseif term:find("trice$") then
		term = term:gsub("trice$", "tore")
	end

	return term
end

return export

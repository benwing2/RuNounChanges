--[[
	TODO: The current code primarly focuses on transcription, rather than actual implementation
	into a working template. Transcriptions are now bare strings, they should most likely be made
	into tables to allow qualifiers, references and similar parameters. Ability to add audio.

	TODO: Middle Polish. This is already handled, but might need a rewrite.

	TODO: Decide on whether we want the Northern Borderlands dialect.
		The general consensus is to including it by doing the consonant subsitution and put the transcription in brackets
--]]

local export = {};

--[[
	As can be seen from the last lines of the function, this returns a table of transcriptions,
	and if do_hyph, also a string being the hyphenation. These are based on a single spelling given,
	so the reason why the transcriptions are multiple is only because of the -yka alternating stress
	et sim. This only accepts single-word terms. Multiword terms are handled by multiword().
--]]
local function phonemic(text, do_hyph)

	local ante = 0;
	local unstressed = false;
	local colloquial = true;

	function rsub(s, r)
		text, c = mw.ustring.gsub(text, s, r);
		return c > 0;
	end
	function rfind(s) return mw.ustring.find(text, s); end

	-- Save indices of uppercase characters before setting everything lowercase.
	local uppercase_indices;
	if (do_hyph) then
		uppercase_indices = {};
		if (rfind('[A-Z]')) then
			local i = 1;
			local str = mw.ustring.gsub(text, "[.']", '');
			while (mw.ustring.find(str, '[A-Z]', i)) do
				local r, _ = mw.ustring.find(str, '[A-Z]', i);
				table.insert(uppercase_indices, r);
				i = r + 1;
			end
		end
		if (#uppercase_indices == 0) then
			uppercase_indices = nil;
		end
	end

	text = mw.ustring.lower(text);

	-- falling diphthongs <au> and <eu>
	rsub('([ae])u', '%1U');

	-- rising diphthongs with <iV>
	local V = 'aąeęioóuy';
	rsub('([^'..V..'])i(['..V..'])', '%1I%2');

	local ka_endings = { 'k[aąęio]', 'ce', 'kach', 'kom' };

	if (text:find('^*')) then
		-- The symbol <*> before a word indicates it is unstressed.
		unstressed = true;
		text = text:sub(2);
	elseif (text:find('^%^+')) then
		-- The symbol <^> before a word indicates it is stressed on the ante-penult,
		-- <^^> on the ante-ante-penult, etc.
		ante = text:gsub('(%^).*', '%1'):len();
		text = text:sub(ante + 1);
	elseif (text:find('^%+')) then
		-- The symbol <+> indicates the word is stressed regularly on the penult. This is useful
		-- for avoiding the following checks to come into place.
		text = text:sub(2);
	else
		-- Some words endings trigger stress on the ante-penult or ante-ante-penult regularly.
		if (rfind('[łlb][iy]')) then
			if (rfind('liśmy$') or rfind('[bł]yśmy$') or rfind('liście$') or rfind('[bł]yście$')) then
				ante = 2;
			elseif (rfind('by[mś]?$') and not rfind('ła?by[mś]?$')) then
				ante = 1;
				colloquial = false;
			end
		end
		if (rfind('[yi][kc]')) then
			for _, v in ipairs(ka_endings) do
				if (rfind('[yi]'..v..'$')) then
					ante = 1;
				end
			end
		end
	end

	if (not text:find('%.')) then
		-- Don't recognise affixes whenever there's only one vowel (or dipthong).
		local _, n_vowels = mw.ustring.gsub(text, '['..V..']', '');
		if (n_vowels > 1) then

			--[[ TODO:
				Prepositions that merge into the following word mess with prefix
				recognition. Maybe when merging they should leave behind a character
				that the prefix recognition interprets as an alternative of ^, i.e.
				beginning of string, and is later removed.
			--]]

			-- syllabify common prefixes as separate
			local prefixes = {
				'do', 'wy', 'za', 'aktyno', 'akusto', 'akwa', 'anarcho', 'andro', 'anemo', 'antropo', 'arachno', 'archeo', 'archi', 'arcy', 'areo', 'arytmo', 'audio', 'awio', 'balneo', 'biblio', 'brachy', 'broncho', 'ceno', 'centro', 'centy', 'chalko', 'chiro', 'chloro', 'chole', 'chondro', 'choreo', 'chromato', 'chrysto', 'cyber', 'cyklo', 'cztero', 'ćwierć', 'daktylo', 'decy', 'deka', 'dendro', 'dermato', 'diafano', 'dwu', 'dynamo', 'egzo', 'ekstra', 'elektro', 'encefalo', 'endo', 'entero', 'entomo', 'ergo', 'erytro', 'etno', 'farmako', 'femto', 'ferro', 'fizjo', 'flebo', 'franko', 'ftyzjo', 'galakto', 'galwano', 'germano', 'geronto', 'giganto', 'giga', 'gineko', 'giro', 'gliko', 'gloso', 'glotto', 'grafo', 'granulo', 'grawi', 'haplo', 'helio', 'hemato', 'hepta', 'hetero', 'hiper', 'histo', 'hydro', 'info', 'inter', 'jedno', 'kardio', 'kortyko', 'kosmo', 'krypto', 'kseno', 'logo', 'magneto', 'między', 'niby', 'nie', 'nowo', 'około', 'oksy', 'onto', 'ornito', 'para', 'pierwo', 'pięcio', 'pneumo', 'poli', 'ponad', 'post', 'poza', 'proto', 'pseudo', 'psycho', 'radio', 'samo', 'sfigmo', 'sklero', 'staro', 'stereo', 'tele', 'tetra', 'wice', 'zoo', 'żyro', 'am[bf]i', 'ang[il]o', 'ant[ey]', 'a?steno', '[be]lasto', 'chro[mn]o', 'cys?to', 'de[rs]mo', 'h?ekto', '[gn]eo', 'hi[ge]ro', 'kontra?', 'me[gt]a', 'mi[nl]i', 'a[efg]ro', '[pt]rzy', 'przed?', 'wielk?o', 'mi?elo', 'eur[oy]', 'ne[ku]ro', 'allo', 'astro', 'atto', 'brio', 'heksa', 'all?o', 'at[mt]o', 'a[rs]tro', 'br?io', 'heksa?', 'pato', 'ba[tr][oy]', 'izo', 'myzo', 'm[ai]kro', 'mi[mzk]o', 'chemo', 'gono', 'kilo', 'lipo', 'nano', 'kilk[ou]', 'hem[io]', 'home?o', 'fi[lt]o', 'ma[łn]o', 'h[ioy]lo', 'hip[ns]?o', '[fm]o[nt]o',
				-- <na-, po-, o-, u-> would hit too many false positives
			};
			for _, v in ipairs(prefixes) do
				if (rfind('^'..v)) then
					local _, other_vowels = mw.ustring.gsub(v, '['..V..']', '');
					if ((n_vowels - other_vowels) > 0) then
						rsub('^('..v..')', '%1.');
						break;
					end
				end
			end

			-- syllabify common suffixes as separate
			local suffixes = {
				'nąć',
				'[sc]tw[aou]', '[sc]twie', '[sc]tw[eo]m', '[sc]twami', '[sc]twach',
				'dztw[aou]', 'dztwie', 'dztw[eo]m', 'dztwami', 'dztwach',
				'dł[aou]', 'dł[eo]m', 'dłami', 'dłach',
				'[czs]j[aeięąo]', '[czs]jom', '[czs]jami', '[czs]jach',
			};

			for _, v in ipairs(suffixes) do
				if (rsub('('..v..')$', '.%1')) then break; end
			end

			-- syllabify <istka> as /ist.ka/
			if (text:find('[iy]st[kc]')) then
				table.insert(ka_endings, 'kami');
				for _, v in ipairs(ka_endings) do
					if (rsub('([iy])st('..v..')$', '%1st.%2')) then break; end
				end
			end
		end
	end

	-- syllabification
	for _ = 0, 1 do
		rsub('(['..V..'U])([^'..V.."U.']*)(["..V..'])', function (a, b, c)
			local function find(x) return mw.ustring.find(b, x); end
			if ((mw.ustring.len(b) < 2) or find('^([crsd]z)$') or (b == 'ch') or (b == 'dż')) then
				b = '.'..b;
			else
				local i = 2;
				if (find('^([crsd]z)') or find('^ch') or find('^dż')) then i = 3; end
				if (mw.ustring.sub(b, i, i):find('^[rlłI-]$')) then
					b = '.'..b;
				else
					b = mw.ustring.sub(b, 0, i - 1)..'.'..mw.ustring.sub(b, i);
				end
			end
			return a..b..c;
		end);
	end

	local hyph;
	if (do_hyph) then
		hyph = text:gsub("'", '.'):gsub('-', ''):lower();
		-- Restore uppercase characters.
		if (uppercase_indices) then
			-- str_i loops through all the characters of the string
			-- list_i loops as above but doesn't count dots
			-- array_i loops through the indices at which the capital letters are
			local str_i, list_i, array_i = 1, 1, 1;
			function h_sub(x, y) return mw.ustring.sub(hyph, x, y); end
			while (array_i <= #uppercase_indices) do
				if (h_sub(str_i, str_i) ~= '.') then
					if (list_i == uppercase_indices[array_i]) then
						hyph = h_sub(1,str_i-1)..h_sub(str_i,str_i):upper()..h_sub(str_i+1);
						array_i = array_i + 1;
					end
					list_i = list_i + 1;
				end
				str_i = str_i + 1;
			end
		end
	end

	rsub("'", 'ˈ');

	-- handle digraphs
	rsub('ch', 'x');
	rsub('[crsd]z', { ['cz']='t_ʂ', ['rz']='R', ['sz']='ʂ', ['dz']='d_z' });
	rsub('dż', 'd_ʐ');

	-- basic orthographical rules
	rsub('.', {
		['e']='ɛ', ['o']='ɔ',
		['ą']='ɔN', ['ę']='ɛN',
		['ó']='u', ['y']='ɨ',
		['c']='t_s', ['ć']='t_ɕ',
		['ń']='ɲ', ['ś']='ɕ', ['ź']='ʑ',
		['w']='v', ['ł']='w', ['ż']='ʐ',
		['g']='ɡ', ['h']='x',
		-- letters which stay the same: a b d f i j k l m n p r s t u z
	});
	rsub("n(%.?[kɡx])", "ŋ%1"); -- TODO: this is not phonemic, should it really stay?

	-- palatalisation
	local palatise_into = { ['n'] = 'ɲ', ['s'] = 'ɕ', ['z'] = 'ʑ' };
	rsub('([nsz])I', function (c) return palatise_into[c]; end);
	rsub('([nsz])i', function (c) return palatise_into[c] .. 'i'; end);

	-- voicing and devoicing
	local T = 'ptsʂɕkx';
	local D = 'bdzʐʑɡ';

	rsub('(['..T..'])v', '%1f');
	rsub('(['..T..'])R', '%1ʂ'); rsub('R', 'ʐ');

	local function arr_list(x) local r = ''; for i in pairs(x) do r = r..i; end return r; end
	local devoice = {
		['b'] = 'p', ['d'] = 't', ['ɡ'] = 'k',
		['z'] = 's', ['v'] = 'f',
		['ʑ'] = 'ɕ', ['ʐ'] = 'ʂ',
	};
	rsub('['..arr_list(devoice)..']$', devoice);

	local voice = {}; for i, v in pairs(devoice) do voice[v] = i; end

	local arr_list_devoice = arr_list(devoice);
	local arr_list_voice = arr_list(voice);
	for _ = 0, 5 do
		rsub('(['..arr_list_devoice..'])([._]?['..T..'])', function (a, b) return devoice[a] .. b; end);
		rsub('(['..arr_list_voice..'])([._]?['..D..'])', function (a, b) return voice[a] .. b; end);
	end

	-- Hyphen separator, e.g. to prevent palatisation of <kwazi->.
	rsub('-', '');

	-- nasal vowels
	rsub('N([.ˈ]?[pb])', 'm%1');
	rsub('N([.ˈ]?[ɕʑ])', 'ɲ%1');
	rsub('N([.ˈ]?[td]_[ɕʑ])', 'ɲ%1');
	rsub('N([.ˈ]?[tdsz])', 'n%1');
	rsub('N([.ˈ]?[kɡ])', 'ŋ%1');
	rsub('N([.ˈ]?[wl])', '%1');
	rsub('ɛN$', 'ɛ');

	rsub('N', 'w̃'); rsub('_', '͡');
	rsub('I', 'j'); rsub('U', 'w');

	-- stress
	local function add_stress(a)
		local s = '';
		for _ = 0, a do
			s = s .. '[^.]+%.';
		end
		local r = mw.ustring.gsub(text, '%.('..s..'[^.]+)$', 'ˈ%1');
		if (not mw.ustring.find(r, 'ˈ')) then
			r = 'ˈ' .. r;
		end
		return r;
	end

	local prons = {};

	if (not unstressed and not text:find('ˈ')) then
		table.insert(prons, add_stress(ante));
		if (ante > 0 and colloquial) then
			--[[ TODO:
				This is supposed to handle colloquial pronunciation stressed on the penult
				for words that in proscribed speech would be spelled on some other syllable,
				usually the antepenult. For now it just prints both variants, ideally it should
				print the first one with a qualifier "standard" and the second one with
				"colloquial; common in casual speech".
			--]]
			local thing = add_stress(0);
			if (thing ~= prons[1]) then
				table.insert(prons, thing);
			end
		end
	else
		table.insert(prons, text);
	end

	if (do_hyph) then
		return prons, hyph;
	else
		return prons;
	end

end

-- TODO: This might slow things down if used too much?
local function table_insert_if_absent(t, s)
	for _, v in ipairs(t) do
		if (v == s) then return; end
	end
	table.insert(t, s);
end

-- Returns a table of rhymes from a table of transcriptions.
local function rhymes(prons)
	local t = {};
	for _, v in ipairs(prons) do
		table_insert_if_absent(t, mw.ustring.gsub(mw.ustring.gsub(mw.ustring.gsub(v, '^.*ˈ', ''), '^[^aɛiɔuɨ]-([aɛiɔuɨ])', '%1'), '%.', ''));
	end
	return t;
end

--[[
	Handles a single input, returning a table of transcriptions. Returns also a string of
	hyphenation and a table of rhymes if it is a single-word term.
--]]
local function multiword(term)
	if (term:find(' ')) then

		-- Prepositions are recognised and merged with the following word.
		local prepositions = {
			'beze?', 'na', 'dla', 'do', 'ku', 'na',
			'nade?', 'o', 'ode?', 'po', 'pode?', 'przede?',
			'przeze?', 'przy', 'spode?', 'u', 'we',
			'za', 'ze', 'znade?', 'zza',
		};

		-- TODO: I know there's no pipe to do (^| ), but is there really no better
		-- way than this to handle this situation?
		for _, v in ipairs(prepositions) do
			term = mw.ustring.gsub(term, '( '..v..') ', '%1.');
			term = mw.ustring.gsub(term, '^('..v..') ', '%1.');
		end
		term = mw.ustring.gsub(term, "%.(['.])", '%1');

		-- Consonantal-only prepositions <w> and <z> are handled separately
		term = mw.ustring.gsub(term, '( [wz]) ', '%1');
		term = mw.ustring.gsub(term, '^([wz]) ', '%1');

		local here = {};

		--[[ TODO:
			This whole function is supposed to handle when one of the words in a
			multiword term has more than one possible pronunciation. It of course needs
			to handle qualifiers well. For example <gramatyka gramatyka> should print
			just two pronunciations, not all four possible combinations as it does now,
			because it should only merge together pronunciation with the same qualifier.
			The whole thing is hopefully going to be simplified once pronunciations
			are made into tables rather than bare strings.
		--]]
		local function concat(s, v)
			if (#s == 0) then
				return v;
			elseif (#s == 1 and #v == 1) then
				return {s[1] .. ' ' .. v[1]};
			else
				local t = {};
				for _, v_s in ipairs(s) do
					for _, v_v in ipairs(v) do
						local concatted = v_s .. ' ' .. v_v;
						table_insert_if_absent(t, concatted);
					end
				end
				return t;
			end
		end

		for v in term:gmatch('[^ ]+') do
			here = concat(here, phonemic(v, false));
		end

		return here;

	else
		local prons, hyph = phonemic(term, true);
		return prons, hyph, rhymes(prons);
	end
end

-- This handles all the magic characters <*>, <^>, <+>, <.>, <#>.
local function normalise_input(term, title)

	local function check_affixes(r, err_msg)
		if (not mw.ustring.find(title, r)) then
			error("the word does not "..err_msg);
		end
	end

	if (term == '#') then
		-- The diesis stands simply for {{PAGENAME}}.
		return title;
	elseif ((term == '+') or term:find('^%^+$') or (term == '*')) then
		-- Inputs that are just '+', '*', '^', '^^', etc. are treated as
		-- if they contained the title with those symbols preceding it.
		return term .. title;
	-- Handle syntax like <po.>, <.ka> and <po..ka>. This allows to not respell
	-- the entire word when all is needed is to specify syllabification of a prefix
	-- and/or a suffix.
	elseif (term:find('.+%.$')) then
		local prefix = term:sub(1, -2);
		check_affixes('^'..prefix, "start with "..prefix);
		return term .. title:gsub('^'..prefix, '');
	elseif (term:find('^%..+')) then
		local suffix = term:sub(2);
		check_affixes(suffix..'$', "end with "..suffix);
		return title:gsub(suffix..'$', '') .. term;
	elseif (term:find('.+%.%..+')) then
		local prefix = term:gsub('%.%..+', '');
		local suffix = term:gsub('.+%.%.', '');
		check_affixes('^'..prefix, "start with "..prefix);
		check_affixes(suffix..'$', "end with "..suffix);
		return mw.ustring.gsub(title, '^('..prefix..')(.+)('..suffix..')', '%1.%2.%3');
	end

	return term;

end

function export.IPA(frame)

	local args = require('Module:parameters').process(frame:getParent().args, {

		-- TODO: This needs handling of the other parameters at [[MOD:pl-pronunciation]].

		[1] = { list = true },

		["title"] = { default = nil }, -- for debugging or demonstration only

	});

	local terms = args[1];
	local title = args.title or mw.title.getCurrentTitle().text;

	if (#terms == 0) then
		terms = { '#' };
	end

	local IPA_results, hyphs, rhymes = {}, {}, {};

	for _, term in ipairs(terms) do
		term = normalise_input(term, title);
		local prons, hyph, rhyme = multiword(term);
		for _, f_term in ipairs(prons) do
			table.insert(IPA_results, { pron = '/'..f_term..'/' });
		end
		if (hyph) then
			table_insert_if_absent(hyphs, hyph);
		end
		if (rhyme) then
			for _, v in ipairs(rhyme) do
				table_insert_if_absent(rhymes, v);
			end
		end
	end

	-- The following code is definitely not the cleanest.

	local hyph_text;

	if (#hyphs > 0) then

		local new_hyphs = {};
		for _, v in ipairs(hyphs) do
			if (v:gsub('%.', '') == title) then
				local r, _ = v:gsub('%.', '‧');
				table.insert(new_hyphs, r);
			end
		end

		-- TODO: Syllabification here is temporally manual just to show it as a proof of concept.
		hyph_text = '\n* Syllabification: ' .. ((#new_hyphs == 0)
			and '<small>[please specify hyphenation manually]</small>'
			-- don't categorise for now since it's in the sandbox
			-- ..'[[Category:pl-pronunciation_without_hyphenation]]'
			or table.concat(new_hyphs, ', '));

	end

	local rhyme_text;

	local lang = require('Module:languages').getByCode('pl');

	if (#rhymes > 0) then
		local new_rhymes = {};
		for _, v in ipairs(rhymes) do
			table.insert(new_rhymes, {rhyme = v});
		end
		rhyme_text = '\n*'..require('Module:rhymes').format_rhymes({ lang = lang, rhymes = new_rhymes });
	end

	return '*'..require('Module:IPA').format_IPA_full(lang, IPA_results) .. (hyph_text or '') .. (rhyme_text or '');
end

return export;

--
-- Created by IntelliJ IDEA.
-- User: junjie
-- Date: 2014/11/4
-- Time: 16:01
-- To change this template use File | Settings | File Templates.
--
-- RC4
-- http://en.wikipedia.org/wiki/RC4


local function KSA(key)
	local key_len = string.len(key)
	local S = {}
	local key_byte = {}

	for i = 0, 255 do
		S[i] = i
	end

	for i = 1, key_len do
		key_byte[i - 1] = string.byte(key, i, i)
	end

	local j = 0
	for i = 0, 255 do
		j = (j + S[i] + key_byte[i % key_len]) % 256
		S[i], S[j] = S[j], S[i]
	end
	return S
end

local function PRGA(S, text_len)
	local i = 0
	local j = 0
	local K = {}

	for n = 1, text_len do

		i = (i + 1) % 256
		j = (j + S[i]) % 256

		S[i], S[j] = S[j], S[i]
		K[n] = S[(S[i] + S[j]) % 256]
	end
	return K
end



-------------------------------
------------- bit wise-----------
-------------------------------

local bit_op = {}
function bit_op.cond_and(r_a, r_b)
	return (r_a + r_b == 2) and 1 or 0
end

function bit_op.cond_xor(r_a, r_b)
	return (r_a + r_b == 1) and 1 or 0
end

function bit_op.cond_or(r_a, r_b)
	return (r_a + r_b > 0) and 1 or 0
end

function bit_op.base(op_cond, a, b)
	-- bit operation
	if a < b then
		a, b = b, a
	end
	local res = 0
	local shift = 1
	local r_a, r_b
	while a ~= 0 do
		r_a = a % 2
		r_b = b % 2

		res = shift * bit_op[op_cond](r_a, r_b) + res
		shift = shift * 2

		a = math.modf(a / 2)
		b = math.modf(b / 2)
	end
	return res
end

local function bxor(a, b)
	return bit_op.base('cond_xor', a, b)
end

local function band(a, b)
	return bit_op.base('cond_and', a, b)
end

function bor(a, b)
	return bit_op.base('cond_or', a, b)
end


local function output(S, text)
	local len = string.len(text)
	local c
	local res = {}
	for i = 1, len do
		c = string.byte(text, i, i)
		res[i] = string.char(bxor(S[i], c))
	end
	return table.concat(res)
end

local function RC4(key, text)
	local text_len = string.len(text)

	local S = KSA(key)
	local K = PRGA(S, text_len)
	return output(K, text)
end

return {
	encode = RC4,
	decode = RC4,
}

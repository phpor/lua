--[[
aes encrypt & decrypt
Copyright (C) by Junjie Li (phpor.net@gmail.com)
]]

local ffi = require("ffi")
local crypto = ffi.load("crypto")

ffi.cdef[[
struct aes_key_st {
    unsigned int rd_key[4 *(14 + 1)];
    int rounds;
};
typedef struct aes_key_st AES_KEY;
const char *AES_options(void);

int AES_set_encrypt_key(const unsigned char *userKey, const int bits, AES_KEY *key);
int AES_set_decrypt_key(const unsigned char *userKey, const int bits, AES_KEY *key);

void AES_encrypt(const unsigned char *in, unsigned char *out, const AES_KEY *key);
void AES_decrypt(const unsigned char *in, unsigned char *out, const AES_KEY *key);
]]


local function pad(data, key_len)
	local len = string.len(data)
	local pad_length = key_len - len % key_len
	return data .. string.rep(string.char(pad_length), pad_length)
end
local function unpad(data)
	local len = string.len(data)
	local pad_length = string.byte(data, len)
	return string.sub(data, 1, len - pad_length)
end

local AES_ENCRYPT = 1
local AES_DECRYPT = 0
local function init_key(key, type)
	local aes_key = ffi.new("AES_KEY[1]")
	local aes_key_bin = ffi.cast("const unsigned char *", key)
	local aes_key_bits = string.len(key)*8
	local ret
	if type == AES_ENCRYPT then
		-- int AES_set_encrypt_key(const unsigned char *userKey, const int bits, AES_KEY *key);
		ret = crypto.AES_set_encrypt_key(aes_key_bin, aes_key_bits, aes_key)
	elseif type == AES_DECRYPT then
		-- int AES_set_decrypt_key(const unsigned char *userKey, const int bits, AES_KEY *key);
		ret = crypto.AES_set_decrypt_key(aes_key_bin, aes_key_bits, aes_key)
	end
	if ret ~= 0 then
		return nil, "key is invalid"
	end
	return aes_key, nil
end
local function init_encrypt_key(key)
	return init_key(key, AES_ENCRYPT)
end
local function init_decrypt_key(key)
	return init_key(key, AES_DECRYPT)
end

local function encrypt(key, data)
	local aes_key,err = init_encrypt_key(key)
	if err ~= nil then
		return nil, err
	end

	local key_len = string.len(key)
	local buf = ffi.new("unsigned char[?]", key_len)
	data = pad(data, key_len)
	local i
	local result = ""
	for i = 0, string.len(data) - 1 , key_len do
		-- void AES_encrypt(const unsigned char *in, unsigned char *out, const AES_KEY *key);
		crypto.AES_encrypt(ffi.cast("const unsigned char *", string.sub(data, i+1, i+ key_len)), buf, aes_key)
		result = result ..ffi.string(buf, key_len)
	end
	return result, nil
end

local function decrypt(key, data)
	local aes_key,err = init_decrypt_key(key)
	if err ~= nil then
		return nil, err
	end

	local key_len = string.len(key)
	local buf = ffi.new("unsigned char[?]", key_len)
	local i
	local result = ""
	for i = 0, string.len(data) - 1, key_len do
		-- void AES_decrypt(const unsigned char *in, unsigned char *out, const AES_KEY *key);
		crypto.AES_decrypt(ffi.cast("const unsigned char *", string.sub(data, i + 1, i+ key_len)), buf, aes_key)
		result = result ..ffi.string(buf, key_len)
	end
	return unpad(result), nil
end

return {
	encrypt = encrypt,
	decrypt = decrypt,
}

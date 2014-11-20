
local ffi = require("ffi")
local crypto = ffi.load("crypto")

-- 注意： rc4_key_st 中的unsigned int 有可能需要替换成unsigned char 参看：openssl/crypto/rc4/rc4.h
ffi.cdef[[
typedef struct rc4_key_st {
	unsigned int x,y;
	unsigned int data[256];
} RC4_KEY;

const char *RC4_options(void);
void RC4_set_key(RC4_KEY *key, int len, const unsigned char *data);
void RC4(RC4_KEY *key, unsigned long len, const unsigned char *indata, unsigned char *outdata);
]]

local function encrypt(key, data)
	local data_len = string.len(data)
	local rc4_key = ffi.new("RC4_KEY[1]")
	local buf = ffi.new("unsigned char[?]", data_len)
	crypto.RC4_set_key(rc4_key, string.len(key), ffi.cast("const unsigned char *", key))
	crypto.RC4(rc4_key, ffi.cast("unsigned long ", data_len), ffi.cast("const unsigned char *", data), buf)
	return ffi.string(buf, data_len)
end
local function test()
	local key = "test"
	local data = "data"
	local en = encrypt(key, data)
	local de = encrypt(key, en)
	print(de)
end
return {
	encrypt = encrypt,
	decrypt = encrypt,
}

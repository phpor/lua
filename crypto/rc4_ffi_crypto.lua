
local ffi = require("ffi")
local crypto = ffi.load("crypto")

ffi.cdef[[
typedef struct rc4_key_st {
	unsigned char x,y;
	unsigned char data[256];
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
--	print(ffi.string(crypto.RC4_options())) -- rc4(1x,char)
--	local key = "test"
--	local rc4_key = ffi.new("RC4_KEY[1]")
--	crypto.RC4_set_key(rc4_key, ffi.cast("int", string.len(key)), ffi.cast("const unsigned char *", key))
--  测试发现： 只要执行了 RC4_set_key ,程序结束时就会段错误
end
return {
	encrypt = encrypt,
	decrypt = encrypt,
	test = test, --only for test
}

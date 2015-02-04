--
-- Created by IntelliJ IDEA.
-- User: junjie
-- Date: 2014/11/5
-- Time: 15:40
-- 稍后完善其他函数的包装
--


local ffi = require("ffi")
local crypto = ffi.load("crypto")

ffi.cdef[[
typedef struct rsa_st RSA;
typedef struct bio_st BIO;
typedef int pem_password_cb(char *buf, int size, int rwflag, void *userdata);

int RSA_public_encrypt(int flen, const unsigned char *from, unsigned char *to, RSA *rsa,int padding);
int RSA_private_encrypt(int flen, const unsigned char *from, unsigned char *to, RSA *rsa,int padding);
int RSA_public_decrypt(int flen, const unsigned char *from, unsigned char *to, RSA *rsa,int padding);
int RSA_private_decrypt(int flen, const unsigned char *from, unsigned char *to, RSA *rsa,int padding);

BIO *BIO_new_mem_buf(void *buf, int len);
int BIO_free(BIO *a);
RSA *PEM_read_bio_RSA_PUBKEY(BIO *bp, RSA **x, pem_password_cb *cb, void *u);
RSA *PEM_read_bio_RSAPrivateKey(BIO *bp, RSA **x, pem_password_cb *cb, void *u);
int RSA_size(const RSA *r);
void RSA_free(RSA *r);

]]


local RSA_PKCS1_PADDING = 1

local function init_public_key(pem_key)
	local bio = crypto.BIO_new_mem_buf(ffi.cast("unsigned char *", pem_key), -1)
	local rsa = crypto.PEM_read_bio_RSA_PUBKEY(bio, nil, nil, nil)
	crypto.BIO_free(bio)
	if rsa == nil then
		return nil, "parse public key fail"
	end
	return rsa, nil
end
local function init_private_key(pem_key)
	local bio = crypto.BIO_new_mem_buf(ffi.cast("unsigned char *", pem_key), -1)
	local rsa = crypto.PEM_read_bio_RSAPrivateKey(bio, nil, nil, nil)
	crypto.BIO_free(bio)
	if rsa == nil then
		return nil, "parse private key fail"
	end
	return rsa, nil
end
local function public_decrypt(key, data)
	local rsa, err = init_public_key(key)
	if err ~= nil then
		return nil, err
	end
	local size = tonumber(crypto.RSA_size(rsa))
	local decrypted = ffi.new("unsigned char[?]", size)
	data = ffi.cast("const unsigned char *" ,data)
	local len = crypto.RSA_public_decrypt(size, data, decrypted, rsa, RSA_PKCS1_PADDING)
	crypto.RSA_free(rsa)
	if len <= 0 then
		return nil, "decrypt fail"
	end
	return ffi.string(decrypted, len), nil
end

local function private_encrypt(key, data)
	local rsa, err = init_private_key(key)
	if err ~= nil then
		return nil, err
	end
	local size = tonumber(crypto.RSA_size(rsa))
	local encrypted = ffi.new("unsigned char[?]", size)
	local len = crypto.RSA_private_encrypt(#data, data, encrypted, rsa, RSA_PKCS1_PADDING)
	crypto.RSA_free(rsa)
	if len ~= size then
		return nil, "encrypt fail"
	end
	return ffi.string(encrypted, len), nil
end

return {
	public_decrypt = public_decrypt,
	private_encrypt = private_encrypt,
}


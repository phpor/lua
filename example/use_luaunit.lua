-- with luaunit version 3.1
-- get luaunit from: https://github.com/bluebird75/luaunit
local luaunit = require("luaunit")

TestClass = {} --class
function TestClass:test1_method()
	local a = 1
	luaunit.assertEquals( a , 1 )
	-- will fail
	--assertEquals( a , 2 )
end

function test_function() 
	luaunit.assertEquals(1, 1)
end

os.exit(luaunit.LuaUnit:runSuite())

--
-- Created by IntelliJ IDEA.
-- User: junjie
-- Date: 2014/12/4
-- Time: 18:02
-- To change this template use File | Settings | File Templates.
--

local person = {
	name = "unkown",
	age = -1,
}

person.say = function(self)
	print("my name is ".. self.name, " my age is ".. self.age)
end

function NewPerson(name, age)
	local p = {}
	setmetatable(p, { __index = person})
	p.name = name
	p.age = age
	return p
end

local phpor1 = NewPerson("phpor", 18)
local phpor2 = NewPerson("phpor2", 19)

phpor1:say()
phpor2:say()
phpor1:say()
phpor2:say()

--[[ 输出结果
my name is phpor	 my age is 18
my name is phpor2	 my age is 19
my name is phpor	 my age is 18
my name is phpor2	 my age is 19
]]

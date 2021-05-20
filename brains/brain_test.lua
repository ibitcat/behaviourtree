-- test ai

oo.class("Brain_test","Brain")
function Brain_test:__init(owner, name)
	Brain.__init(self, owner, name)
end

-- 死亡之后，清除召唤的小怪
function Brain_test:onStop()
	--print("停止ai")
end

function Brain_test:onStart()
	local pz = 0
	local owner = self:getOwner()
	local x,y = owner:getCell()
	local root = PriorityNode:new(
		{
			SkillOnTarget:new(),
			IfNode:new(function() return not self:selectTarget() end,GoHome:new({speed=100}))
		},
		2000
	)

    self._bt = BehaviourTree:new(self, root)
end
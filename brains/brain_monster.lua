-- 小怪 ai

oo.class("Brain_monster","Brain")
function Brain_monster:__init(owner, name)
	Brain.__init(self, owner, name)
end

-- 死亡之后，清除召唤的小怪
function Brain_monster:onStop()
	--print("停止ai")
end

function Brain_monster:onStart()
	local owner = self:getOwner()
	local x,y = owner:getCell()
	local root = PriorityNode:new({
			SkillOnTarget:new(),
			IfNode:new(function() return not self:selectTarget() end,GoHome:new({speed=100}))
		},
		2000
	)

    self._bt = BehaviourTree:new(self, root)
end
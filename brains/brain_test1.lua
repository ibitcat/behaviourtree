-- 主动怪 ai

oo.class("Brain_test1","Brain")
function Brain_test1:__init(owner, name)
	Brain.__init(self, owner, name)
end

function Brain_test1:onStart()
	local owner = self:getOwner()
	local x,y = owner:getCell()
	local root = PriorityNode:new({
			SkillOnTarget:new(),
			IfNode:new(function() return not self:selectTarget() end,GoHome:new({speed=100}))
		},
		1000
	)

    self._bt = BehaviourTree:new(self, root)
end
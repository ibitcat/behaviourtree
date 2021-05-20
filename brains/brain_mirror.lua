-- 玩家镜像 ai

oo.class("Brain_mirror","Brain")
function Brain_mirror:__init(owner, name)
	Brain.__init(self, owner, name)
end

function Brain_mirror:onStop()
	--print("停止ai")
end

function Brain_mirror:onStart()
	local owner = self:getOwner()
	local x,y = owner:getCell()
	local root = PriorityNode:new({
			SkillOnTarget:new(owner:getFightSkills()),
		},
		2000
	)

	self._bt = BehaviourTree:new(self, root)
end
-- 毒蜘蛛大脑

local _skill_suanye =  100902001 	--酸液技能
local _skill_tusi = 100901001		--吐丝技能
local _skill_zhuluan = 100903001 	--蛛卵技能

oo.class("DuzhizhuBrain","Brain")
function DuzhizhuBrain:__init(owner, name, cnf)
	Brain.__init(self,owner, name, cnf)
end

-- 死亡之后，清除召唤的小怪
function DuzhizhuBrain:onStop()
	print("死亡之后，清除召唤的小怪")
	self._owner:removeAllSummon()
end

function DuzhizhuBrain:onStart()
	--local pz = self:getValue("landingPz")
	local pz = 0
	local x,y = self._owner:getCell()
	local root = PriorityNode({
			--EventNode(EVENT.BE_KILLED, ActionNode(function() self._owner:removeAllSummon() end), 10),
			DoActionNode(function() return self._owner:beControled() end),
			IfNode(function() return not self._isLand end,
				SequenceNode({
					MoveTo({x=x+1, y=y, pz=pz, speed=250, act="frun", land={x=-1}}),
					ActionNode(function() self._isLand = true end)
				})		
			),

			--NotDecorator(DoActionNode(function() return self:searchTarget() end)),
			AlarmRescue(),
			IfNode(function() return self:skillCoolDowned(_skill_suanye) end, SkillOnTarget({_skill_suanye, findWay = true})),
			IfNode(function() return self:skillCoolDowned(_skill_zhuluan)end, SkillOnTarget({_skill_zhuluan, findWay = true})),
			IfNode(function() return self:skillCoolDowned(_skill_tusi)   end, SkillOnTarget({_skill_tusi, findWay = true}))
		},
		500
	)

    self._bt = BehaviourTree(self, root)
end
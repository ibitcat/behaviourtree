-- skillOnTarget action

-- param = {skillId1, skillId2...}
oo.class("SkillOnTarget","BehaviourNode")
function SkillOnTarget:__init(param, preEffect, endEffect)
	BehaviourNode.__init(self, nil, true)
	self._kind = "SkillOnTarget"
	self._param = param
	self._ctx = {}
	self._preEffectFn = preEffect -- 技能释放前
	self._endEffectFn = endEffect -- 技能释放完，可能需要一些效果
end

function SkillOnTarget:reset()
	BehaviourNode.reset(self)
	table.clear(self._ctx)
end

function SkillOnTarget:visit()
	if self._status==BT.READY and self._preEffectFn then
		self._preEffectFn()
	end

	local ret = self:evaluate()
	--print("skill ret = ",ret,self._param[1])
	if ret==0 then
		self._status = BT.SUCCESS
		table.clear(self._ctx)

		-- 技能释放成功后的效果
		if self._endEffectFn then
			self._endEffectFn()
		end
	elseif ret>0 then
		self._status = BT.RUNNING
		self:sleep(ret)
	else
		self._status = BT.FAILED
		table.clear(self._ctx)
	end
end

function SkillOnTarget:evaluate()
	local brain = self._brain
	local cnf = brain:getConfig()
	local owner = brain:getOwner()

	-- 技能在释放的过程中，被打断
	if owner:beControled() then
		return -1
	end

	local target = brain:selectTarget()
	if not target then
		-- 没有目标，技能释放失败
		return -1
	end

	local ctx = self._ctx
	local idx = ctx.idx or 1
	local skillList = self._param or cnf.normalSkill
	local skillId = skillList[idx]
	if not skillId then
		owner:traceTarget(nil)
		return -1
	end

	-- 在技能施法范围内
	local skCon = owner._skillCT
	if skCon:inSkillDistance(skillId, target) then
		if owner:isTracing() then
			owner:traceTarget(nil)
		end

		-- 技能系统触发
		local ok, _ = skCon:castOnObj(skillId, target)
		if ok then
			-- 技能成功释放，1s后放下一个技能
			--print("技能成功释放，1s后放下一个技能")
			local nextIdx = idx + 1
			if nextIdx>#skillList then
				ctx.idx = 1
			else
				ctx.idx = nextIdx
			end
			return 1000
		else
			local cdms = skCon:getSkillCd(skillId)
			return cdms
		end
	else
		local skillDistance = skCon:getSkillDistance(skillId)
		if not owner:isStopping() then --不在定身状态
			if not owner:isTracing() or owner:getTracingTarget()~=target then
				--追踪目标
				owner:traceTarget(target, skillDistance)
				owner:tracingUpdate()
			else
				owner:tracingUpdate()
			end
		end
		return 1000 --等待下一次思考
	end
end
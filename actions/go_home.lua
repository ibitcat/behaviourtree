-- go home action

oo.class("GoHome","BehaviourNode")
function GoHome:__init(param)
	BehaviourNode.__init(self, nil, true)
	self._kind = "GoHome"
	self._param = param
end

function GoHome:moveStart(cnf)
	cnf = cnf or self._brain:getConfig()
	local owner = self._brain:getOwner()
	local param = self._param
	local speed = param and param.speed or cnf.goHomeSpeed or owner:getSpeed()
	assert(speed > 0)
	local x, y = owner:getBornCell()
	owner:moveStartCell(x, y, speed)
end

function GoHome:visit()
	local brain = self._brain
	local owner = brain:getOwner()
	local cnf = brain:getConfig()
	local thinkType = cnf.thinkType

	-- 开始归位
	if self._status==BT.READY then
		-- 回家时满血
		if cnf.goHomeFullHp == 1 then
			owner:addHp(owner:getHpUpper())
		end

		-- 归位开始时无敌
		if cnf.goHomeWD == 1 then
			owner:incInvincible()
		end

		-- 清除
		brain._currentTarget = nil
		brain._scannedTarget = nil
		brain._attackTarget  = nil
		brain._blackboard = {}
		owner:clearAttacker()
		owner:traceTarget(nil)

		local x, y = owner:getBornCell()
		if owner:isInCell(x, y) then
			self._status = BT.SUCCESS

			-- 如果是被动怪，归位后暂停思考
			if thinkType==1 or brain._aiRangeAmt==0 then
				--print("1 stop brain:", owner:getObjId())
				self._brain:markNeedStop()
			end
			return
		end

		brain:setState("goingHome")
		self:moveStart(cnf)
		self._status = BT.RUNNING
	end

	if self._status == BT.RUNNING then
		if owner:isInCell(owner:getBornCell()) then
			-- 归位成功后解除无敌
			if cnf.goHomeWD then
				owner:decInvincible()
			end

			self._status = BT.SUCCESS
			brain:setState(nil)

			-- 如果是被动怪，归位后暂停思考
			if thinkType==1 or brain._aiRangeAmt==0 then
				--print("2 stop brain:", owner:getObjId())
				self._brain:markNeedStop()
			end
			return
		else
			if not owner:isMoving() then
				self:moveStart(cnf)
			end
		end

		self:sleep(1000)
	end
end
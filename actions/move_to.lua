-- moveto action

-- param = {x=x, y=y, speed=250}

oo.class("MoveTo","BehaviourNode")
function MoveTo:__init(param, fn)
	BehaviourNode.__init(self, nil, true)
	self._kind = "MoveTo"
	self._param = param or {}
	self._ctx = {}
	self._fn = fn	-- 用来改变param
end

function MoveTo:reset()
	BehaviourNode.reset(self)
	table.clear(self._ctx)
end

function MoveTo:resetParam(param)
	if not param then return end

	--table.clear(self._param)
	for k,v in pairs(param) do
		self._param[k] = v
	end
end

function MoveTo:move()
	local param = self._param
	local owner = self._brain:getOwner()

	local speed = param.speed or owner:getSpeed()
	local ctx = self._ctx
	-- 没有寻路点
	if not ctx._path then
		self._status = BT.SUCCESS
		return
	end

	local x, y = ctx._path[ctx.idx], ctx._path[ctx.idx+1]
	if not x or not y then
		self._status = BT.SUCCESS
		return
	end

	if owner:isInCell(x, y) then
		ctx.idx = ctx.idx + 2
	else
		owner:moveStartCell(x, y, speed)
	end
end

function MoveTo:visit()
	local param = self._param
	local owner = self._brain:getOwner()

	if self._status==BT.READY then
		if self._fn then
			self._fn(self)
		end

		if not next(param) then
			self._status = BT.FAILED
			return
		end

		local map = owner:getMapInstance()
		local ctx = self._ctx
		if not ctx._path then
			local path
			local cx, cy = owner:getCell()
			if param.findWay then
				local can, x, y = map:lineCanMove(cx, cy, param.x, param.y)
				if can then
					path = {param.x, param.y}
				else
					path = map:findPathByAstar(cx, cy, param.x, param.y)
				end
			else
				path = {param.x, param.y}
			end

			ctx._path = path
			ctx.idx = 1
		end

		self._status = BT.RUNNING
	end

	-- 检查是否走到了
	if self._status==BT.RUNNING then
		local sleepTm = 500
		if owner:isInCell(param.x, param.y) then
			self._status = BT.SUCCESS
			return
		end

		if not owner:isMoving() then
			self:move()
			if self._status == BT.SUCCESS then
				return
			end
		end

		-- 睡眠500ms后再来检查
		self:sleep(sleepTm)
	end
end
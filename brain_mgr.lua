-- 大脑管理器
-- 暂无用

oo.single("BrainMgr")
function BrainMgr:init()
	self._brains = {}

	self._waiters = {}		--等待执行的行为树
	self._runnings = {}		--正在运行的行为树
	self._hibernaters = {}	--休眠中的行为树

	-- 100ms执行一次
	--self._evo:addTimerListener(self, "onTimer", 10)
end

function BrainMgr:addBrain(brain)
	table.insert(self._brains,brain)
	--self._brains[brain] = self._waiters
	--self._waiters[brain] = true
end

function BrainMgr:removeBrain(brain)
	self:sendToList(brain, nil)

	self._waiters[brain] = nil
	self._hibernaters[brain] = nil
	self._runnings[brain] = nil

	self._brains[brain] = nil
end

-- 实体删除时，干掉它的ai
function BrainMgr:onRemoveEntity(inst)
	if inst.brain and self._brains[inst.brain] then
		self:removeBrain(inst.brain)
	end
end

function BrainMgr:sendToList(brain, list, val)
	local old_list = self._brains[brain]
	if old_list and old_list ~= list then
		if old_list then
			-- 如果是正在运行的brain，需要干掉定时器
			if old_list==self._runnings and old_list[brain] then
				self._evo:removeTimerListener(old_list[brain])
			end
			old_list[brain] = nil
		end

		self._brains[brain] = list

		if list then
			list[brain] = val or true
		end
	end
end

function BrainMgr:wake(brain)
	if self._brains[brain] then
		self:sendToList(brain, self._waiters)
	end
end

function BrainMgr:hibernate(brain)
	if self._brains[brain] then
		self:sendToList(brain, self._hibernaters)
	end
end

function BrainMgr:running(brain,timerId)
	if self._brains[brain] then
		self:sendToList(brain, self._runnings, timerId)
	end
end

function BrainMgr:onTimer()
	for brain,_ in pairs(self._waiters) do
		self:think(brain)
	end
	self._evo:addTimerListener(self, "onTimer", 10)
end

-- 大脑启动思考
function BrainMgr:think(brain)
	assert(brain)
	brain:onUpdate() --大脑思考一次

	local sleep_amount = brain:getSleepTime()
	if sleep_amount then
		sleep_amount = sleep_amount>=10 and sleep_amount or 10 --必须是10ms的倍数
		local tick = math.floor(sleep_amount/10)
		local timerId = self._evo:addTimerListener(self, "think", tick, brain)
		self:running(brain,timerId)
	else
		self:hibernate(brain) --休眠
	end
end
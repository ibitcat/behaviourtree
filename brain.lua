-- 大脑（ai的封装）

local _mathRandom = math.random
local _mathFloor  = math.floor

oo.class("Brain")
function Brain:__init(owner, name)
	assert(owner)
	assert(name)

	self._owner = owner
	self._bt = nil					--大脑的行为树
	self._aiName = name 			--大脑名字
	self._thinkTimerId = nil		--大脑思考的定时器
	self._lastThinkTime = 0			--大脑上一次思考的时间戳（ms）
	self._thinkVersion = 0			--大脑思考版本号
	self._blackboard = {}			--黑板
	self._aiRangeAmt = nil 			--ai范围感知计数器(nil表示需要感知触发)
end

function Brain:getOwner()
	return self._owner
end

function Brain:isThinking()
	return self._thinkTimerId
end

function Brain:isValid()
	-- 大脑没有拥有者
	-- 或者 拥有者未出生
	-- 或者 拥有者死亡，则停止思考
	local owner = self._owner
	if not owner or not owner:isValid() or owner:isDead() then
		return false
	end
	return true
end

function Brain:markNeedStop()
	-- 供行为树节点执行
	self._needStop = true
end

-- 行为树强制update一次
function Brain:forceUpdate()
	if not self:isThinking() then return end
	if self._bt then
		self._bt:forceUpdate()
	end

	if self._thinkTimerId then
		self._owner:removeTimerListener(self._thinkTimerId)
		self._thinkTimerId = nil
	end

	--强制思考一次
	print("强制思考一次")
	self:think()
end

function Brain:getSleepTime()
	if self._needStop then
		self._needStop = nil
		return
	end

	if self._bt then
		return self._bt:getSleepTime()
	end

	return 0
end

-- 创建怪物后并给怪物创建一个大脑，并启动大脑
function Brain:start()
	if self:isThinking() then return end
	if not self:isValid() then return end

	--创建行为树bt，由具体的子类重写(必须要实现该方法)
	self:onStart()

	--行为树的初始化，由具体的子类重写
	if self.onInit then
		self:onInit()
	end

	-- 触发大脑思考的事件注册
	self:addEventHandler()

	-- wake up
	-- 如果是主动怪，立即开启思考
	local thinkType = self:getThinkType() or 1
	if thinkType>1 then
		local layoutId = self._owner._objLayoutId
		if layoutId then
			self:regAiRange(layoutId)
			if not self._aiRangeAmt then return end
		end

		assert(self._bt)
		assert(not self._thinkTimerId)
		local cnf = self:getConfig()
		local buffer = cnf.aiBuffer or 0
		if buffer>=10 then
			buffer = _mathRandom(1, _mathFloor(buffer/10))
		else
			buffer = 1
		end
		self._thinkTimerId = self._owner:addTimerListener(self, "think", buffer)
	end
end

-- 事件注册
function Brain:addEventHandler()
	assert(self._bt)

	-- 大脑触发思考事件
	self._owner:addEventListener(self, EVENT.BE_ATTACKED_END, 'onEvent')

	-- 大脑停止思考事件
	--self._owner:addEventListener(self, EVENT.BE_KILLED, "stop")
end

-- ai范围感知
function Brain:regAiRange(layoutId)
	-- 注册ai触发范围
	local map = self._owner:getMapInstance()
	if map then
		local cnf = self:getConfig()
		local layoutCnf = Config:find("layout", layoutId)
		map:addRangeListener(layoutCnf.x, layoutCnf.y, layoutCnf.radius + cnf.scanRange + 2, self, "onInAiRange")
	end
end

-- 停止后，删除所有的事件
function Brain:delEventHandler()
	self._owner:removeEventListener(self)
end

-- 事件触发大脑思考，比如：被攻击等
function Brain:onEvent()
	if not self:isThinking() then
		self:think()
	end
end

function Brain:onInAiRange(obj, status)
	if obj and obj:getCamp()~=self._owner:getCamp() then
		local old = self._aiRangeAmt or 0
		if status=="enter" then
			self._aiRangeAmt = old + 1
			if old==0 then
				self:onEvent()
			end
		elseif status =="leave" then
			self._aiRangeAmt = math.max(0, old-1)
		end
	end
end

--  update
function Brain:update()
	if self.doUpdate then
		self:doUpdate()
	end

	if self._bt then
		self._bt:update()
	end

	if self.onUpdate then
		self:onUpdate()
	end
end

-- 大脑停止思考 如果对象未死亡，则下一次受到攻击后会继续思考
function Brain:stop()
	if self._bt then
		self._bt:stop()
	end
	self._lastThinkTime = 0

	if not self:isValid() then
		self:delEventHandler()
	end

	if self._thinkTimerId then
		self._owner:removeTimerListener(self._thinkTimerId)
		self._thinkTimerId = nil
	end

	if self.onStop then
		self:onStop()
	end
end

-- 大脑开始思考一次
function Brain:think()
	self._thinkTimerId = nil --重置定时器

	if not self:isValid() then return end
	if self._thinkVersion==0xFFFFFFFF then
		self._thinkVersion = 0
	else
		self._thinkVersion = self._thinkVersion + 1
	end
	self:update() --大脑思考一次
	self._lastThinkTime = env.unixtimeMs()

	-- next think
	local sleep_amount = self:getSleepTime()
	if sleep_amount then
		sleep_amount = sleep_amount>=10 and sleep_amount or 10 --必须是10ms的倍数
		--print("sleep_amount------------>>",sleep_amount)
		local tick = math.floor(sleep_amount/10)
		self._thinkTimerId = self._owner:addTimerListener(self, "think", tick)
	else
		--休眠
		--log("大脑休眠, objId=%d, aiRangeAmt=%d", self._owner:getObjId(), self._aiRangeAmt or -1)
	end
end

function Brain:btString()
	if self._bt then
		if not self:isThinking() then
			print("\nbtree stoped")
			return
		end
		local btStr = self._bt._root:getTreeString()
		print('\n'..btStr or "empty btree")
	end
end
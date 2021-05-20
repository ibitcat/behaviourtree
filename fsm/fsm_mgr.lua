-- 状态机管理器
oo.single('FsmMgr')

function FsmMgr:init()
    self._fsm = {}
    self._objCtx = {}
    GEventMgr:addTimerListenerForever(self, 'update', 500)
end

function FsmMgr:addFsm(fsmClass, fsm)
    assert(fsmClass and fsm)
    if self._fsm[fsmClass] then return -1 end
    self._fsm[fsmClass] = fsm
end

function FsmMgr:addCtx(id, ctx, fsmClass)
    assert(id and ctx and fsmClass)

    if self._objCtx[id] then return -1 end
    local fsm = self._fsm[fsmClass]
    if not fsm then return -2 end

    ctx._fsm = fsm
    ctx._fsm_state = fsm:getFirstState()

    self._objCtx[id] = ctx
end

function FsmMgr:removeCtx(id)
    assert(id)
    local ctx = self._objCtx[id]
    if not ctx then return -1 end

    local fsm, state = ctx._fsm, ctx._fsm_state
    local action = fsm._actions[state]
    action:stop(ctx)
    action:cleanup(ctx)

    ctx._fsm = nil
    ctx._fsm_state = nil
    self._objCtx[id] = nil
end

function FsmMgr:update()
    local fsm, state
    for id, ctx in pairs(self._objCtx) do
        fsm, state = ctx._fsm, ctx._fsm_state
        local action = fsm._actions[state]
        action:run(ctx)
        local newState = ctx._fsm_state
        if newState ~= state then
            action:cleanup(ctx)
            newAction = fsm._actions[newState]
            newAction:init(ctx)
        end
    end
end

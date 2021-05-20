-- 状态机动作
oo.class('FsmAction')
function FsmAction:__init(state)
    self._state = state
end

function FsmAction:getActionState()
    return self._state
end

function FsmAction:init(ctx)
end

function FsmAction:cleanup(ctx)
end

function FsmAction:run(ctx)
end

function FsmAction:stop(ctx)
end

oo.class('FSM')
function FSM:__init()
    self._actions = {}
    self._firstState = nil
end

function FSM:addState(action, state)
    state = state or action:getActionState()
    if self._actions[state] then return -1 end
    self._actions[state] = action
    if not self._firstState then self._firstState = state end
end

function FSM:getFirstState()
    return self._firstState
end


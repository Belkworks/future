local noop
noop = function() end
local Future
do
  local _class_0
  local _base_0 = {
    transition = function(self, State, Value)
      if not (self.State == self.__class.STATE.RUNNING) then
        return 
      end
      self.State = State
      self.Value = Value
      local _list_0 = self.Listeners
      for _index_0 = 1, #_list_0 do
        local C = _list_0[_index_0]
        Future.ASYNC(C, self.State, self.Value)
      end
      self.Listeners = nil
    end,
    transitioner = function(self, State)
      return function(Value)
        return self:transition(State, Value)
      end
    end,
    resolver = function(self, State)
      return self:transitioner(self.__class.STATE.RESOLVED)
    end,
    hook = function(self, Callback)
      if self.State > self.__class.STATE.RUNNING then
        return Callback(self.State, self.Value)
      else
        return table.insert(self.Listeners, Callback)
      end
    end,
    hookState = function(self, Target, Callback)
      return self:hook(function(State, Value)
        if not (State == Target) then
          return 
        end
        return Callback(Value)
      end)
    end,
    fork = function(self, Resolved, Rejected)
      self:hookState(self.__class.STATE.RESOLVED, Resolved or function() end)
      self:hookState(self.__class.STATE.REJECTED, Rejected or function() end)
      if not (self.State == self.__class.STATE.IDLE) then
        return 
      end
      self.State = self.__class.STATE.RUNNING
      local Resolve = self:transitioner(self.__class.STATE.RESOLVED)
      local Reject = self:transitioner(self.__class.STATE.REJECTED)
      local Cancel = self:transitioner(self.__class.STATE.CANCEL)
      Future.ASYNC(function()
        local S, E = pcall(self.Callback, Resolve, Reject)
        if S then
          if (type(E)) == 'function' then
            return self:hookState(self.__class.STATE.CANCEL, E)
          end
        else
          return Reject(E)
        end
      end)
      return Cancel
    end,
    value = function(self, Callback)
      return self:fork(Callback, error)
    end,
    done = function(self, Callback)
      local Resolved
      Resolved = function(Value)
        return Callback(nil, Value)
      end
      return self:fork(Resolved, Callback)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, Callback)
      self.Callback = Callback
      self.State = self.__class.STATE.IDLE
      self.Listeners = { }
    end,
    __base = _base_0,
    __name = "Future"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.ASYNC = function(fn, ...)
    return coroutine.wrap(fn)(...)
  end
  self.STATE = {
    IDLE = -2,
    RUNNING = -1,
    RESOLVED = 0,
    REJECTED = 1,
    CANCEL = 2
  }
  self.resolve = function(value)
    return Future(function(resolve)
      return resolve(value)
    end)
  end
  self.reject = function(value)
    return Future(function(self, reject)
      return reject(value)
    end)
  end
  self.never = function()
    do
      local _with_0 = Future(noop)
      _with_0.Never = true
      return _with_0
    end
  end
  self.race = function(A, B)
    return Future(function(resolve, reject)
      A:fork(resolve, reject)
      return B:fork(resolve, reject)
    end)
  end
  self.alt = function(A, B)
    return Future(function(resolve, reject)
      return A:fork(resolve, function()
        return B:fork(resolve, reject)
      end)
    end)
  end
  self.both = function(A, B)
    return Future(function(resolve, reject)
      return A:fork((function()
        return B:fork(resolve, reject)
      end), reject)
    end)
  end
  self.log = function(header)
    return function(value)
      return print("[" .. tostring(header) .. "]:", value)
    end
  end
  Future = _class_0
  return _class_0
end

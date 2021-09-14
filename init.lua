local insert
insert = table.insert
local wrap
wrap = coroutine.wrap
local noop
noop = function() end
local after
after = function(fn, ...)
  return unpack((function(...)
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = {
      ...
    }
    for _index_0 = 1, #_list_0 do
      local c = _list_0[_index_0]
      _accum_0[_len_0] = (function(v)
        return c(v, fn(v))
      end)
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)(...))
end
local bound
bound = function(fn, ...)
  local Args = {
    ...
  }
  return function()
    return fn(unpack(Args))
  end
end
local cancel
cancel = function(...)
  local Args = {
    ...
  }
  return function()
    for _index_0 = 1, #Args do
      local F = Args[_index_0]
      F:cancel()
    end
  end
end
local indexOf
indexOf = function(t, x)
  for k, v in pairs(t) do
    if v == x then
      return k
    end
  end
end
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
    cancel = function(self)
      return self:transition(self.__class.STATE.CANCEL)
    end,
    isDead = function(self)
      return self.State > self.__class.STATE.RUNNING
    end,
    hook = function(self, Callback)
      if self:isDead() then
        return Callback(self.State, self.Value)
      else
        return insert(self.Listeners, Callback)
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
    return wrap(fn)(...)
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
  self.isNever = function(F)
    return F.Never == true
  end
  self.value = function(F, Callback)
    return F:fork(Callback, error)
  end
  self.done = function(F, Callback)
    local Resolved
    Resolved = function(Value)
      return Callback(nil, Value)
    end
    return F:fork(Resolved, Callback)
  end
  self.node = function(Callback)
    return Future(function(resolve, reject)
      return Callback(function(err, value)
        if err == nil then
          return resolve(value)
        else
          return reject(err)
        end
      end)
    end)
  end
  self.swap = function(F)
    return Future(function(resolve, reject)
      return F:fork(reject, resolve)
    end)
  end
  self.race = function(A, B)
    local clean = cancel(A, B)
    return Future(function(resolve, reject)
      A:fork(after(clean, resolve, reject))
      B:fork(after(clean, resolve, reject))
      return clean
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
  self.lastly = function(A, B)
    local clean = cancel(A, B)
    return Future(function(resolve, reject)
      local lastly
      lastly = function(val)
        return B:fork((bound(resolve, val)), reject)
      end
      local lastlyRej
      lastlyRej = function(err)
        return B:fork((bound(reject, err)), reject)
      end
      A:fork(lastly, lastlyRej)
      return clean
    end)
  end
  self.log = function(header)
    return function(value)
      return print("[" .. tostring(header) .. "]:", value)
    end
  end
  self.watch = function(F, Callback)
    if Callback == nil then
      Callback = print
    end
    if F:isDead() then
      return 
    end
    return F:hook(function(State, Value)
      return Callback((indexOf(Future.STATE, k)))
    end)
  end
  Future = _class_0
  return _class_0
end

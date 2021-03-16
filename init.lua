local STATE = {
  NEW = -1,
  PENDING = 0,
  REJECTED = 1,
  RESOLVED = 2,
  ERROR = 3,
  CANCELED = 4
}
local noop
noop = function() end
local Future
do
  local _class_0
  local _base_0 = {
    drain = function(self, Value, State)
      while #self.Futures > 0 do
        local f = table.remove(self.Futures)
        if f.state == State then
          f.fn(Value)
        end
      end
    end,
    transition = function(self, State, Value)
      if self.State ~= STATE.PENDING then
        return 
      end
      self.State = State
      self.Value = Value
      return self:drain(Value, State)
    end,
    onState = function(self, state, fn)
      local _exp_0 = self.State
      if STATE.PENDING == _exp_0 or STATE.NEW == _exp_0 then
        return table.insert(self.Futures, {
          state = state,
          fn = fn
        })
      elseif state == _exp_0 then
        return fn(self.Value)
      end
    end,
    execute = function(self, reject, resolve)
      self:onState(STATE.REJECTED, reject)
      self:onState(STATE.RESOLVED, resolve)
      if self.State ~= STATE.NEW then
        return 
      end
      self.State = STATE.PENDING
      local tReject
      tReject = function(value)
        return self:transition(STATE.REJECTED, value)
      end
      local tResolve
      tResolve = function(value)
        return self:transition(STATE.RESOLVED, value)
      end
      local S, E = pcall(self.Operation, tReject, tResolve)
      if S then
        return function(...)
          if self.State ~= STATE.PENDING then
            return 
          end
          self:transition(STATE.CANCELED)
          return E(...)
        end
      else
        self:transition(STATE.ERROR, E)
        return error(E)
      end
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, Operation)
      self.Operation = Operation
      assert('function' == type(self.Operation), 'Future: Arg1 should be a function!')
      self.State = STATE.NEW
      self.Futures = { }
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
  Future = _class_0
end
local F = { }
F = {
  Future = Future,
  fork = function(reject, resolve, future)
    return future:execute(reject, resolve)
  end,
  value = function(resolve, future)
    return F.fork(error, resolve, future)
  end,
  log = function(T)
    return function(...)
      return print('[' .. T .. ']: ', ...)
    end
  end,
  resolve = function(value)
    return Future(function(reject, resolve)
      resolve(value)
      return noop
    end)
  end,
  reject = function(value)
    return Future(function(reject, resolve)
      reject(value)
      return noop
    end)
  end,
  attempt = function(fn)
    return Future(function(reject, resolve)
      local S, E = pcall(fn)
      if S then
        resolve(E)
      else
        reject(E)
      end
      return noop
    end)
  end,
  both = function(a, b)
    return Future(function(reject, resolve)
      local nowB
      nowB = function()
        return F.fork(reject, resolve, b)
      end
      return F.fork(reject, nowB, a)
    end)
  end,
  alt = function(a, b)
    return Future(function(reject, resolve)
      local tryB
      tryB = function()
        return F.fork(reject, resolve, b)
      end
      return F.fork(tryB, resolve, a)
    end)
  end,
  lastly = function(a, b)
    return Future(function(reject, resolve)
      local tryB
      tryB = function(V)
        return F.fork(reject, (function()
          return reject(V)
        end), b)
      end
      local nowB
      nowB = function(V)
        return F.fork(reject, (function()
          return resolve(V)
        end), b)
      end
      return F.fork(tryB, nowB, a)
    end)
  end,
  map = function(f, future)
    return Future(function(reject, resolve)
      local transform
      transform = function(v)
        return resolve(f(v))
      end
      return F.fork(reject, transform, future)
    end)
  end,
  mapRej = function(f, future)
    return Future(function(reject, resolve)
      local transform
      transform = function(v)
        return reject(f(v))
      end
      return F.fork(transform, resolve, future)
    end)
  end,
  bimap = function(r, a, future)
    return Future(function(reject, resolve)
      local transform
      transform = function(v)
        return resolve(a(v))
      end
      local transformRej
      transformRej = function(v)
        return reject(r(v))
      end
      return F.fork(transformRej, transform, future)
    end)
  end,
  swap = function(f)
    return Future(function(reject, resolve)
      return F.fork(resolve, reject, f)
    end)
  end
}
setmetatable(F, {
  __call = function(self, ...)
    return Future(...)
  end
})
return F

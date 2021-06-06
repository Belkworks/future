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
        assert('function' == type(E), 'future must return a cancellation function!')
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
    end,
    pipe = function(self, fn, ...)
      local F = fn(self, ...)
      assert(self.__class:isFuture(F), 'pipe: must return a future!')
      return F
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
  local self = _class_0
  self.isFuture = function(F)
    return F.__class == self
  end
  Future = _class_0
end
local F = { }
F = {
  Future = Future,
  fork = function(future, reject, resolve)
    return future:execute(reject, resolve)
  end,
  value = function(future, resolve)
    return F.fork(future, error, resolve)
  end,
  done = function(future, fn)
    return F.fork(future, (function(V)
      return fn(V)
    end), (function(V)
      return fn(nil, V)
    end))
  end,
  log = function(T)
    return function(...)
      return print('[' .. T .. ']: ', ...)
    end
  end,
  node = function(fn)
    return Future(function(reject, resolve)
      fn(function(e, v)
        if e == nil then
          return resolve(v)
        else
          return reject(e)
        end
      end)
      return noop
    end)
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
        return F.fork(b, reject, resolve)
      end
      return F.fork(a, reject, nowB)
    end)
  end,
  alt = function(a, b)
    return Future(function(reject, resolve)
      local tryB
      tryB = function()
        return F.fork(b, reject, resolve)
      end
      return F.fork(a, tryB, resolve)
    end)
  end,
  lastly = function(a, b)
    return Future(function(reject, resolve)
      local tryB
      tryB = function(V)
        return F.fork(b, reject, (function()
          return reject(V)
        end))
      end
      local nowB
      nowB = function(V)
        return F.fork(b, reject, (function()
          return resolve(V)
        end))
      end
      return F.fork(a, tryB, nowB)
    end)
  end,
  map = function(future, f)
    return Future(function(reject, resolve)
      local transform
      transform = function(v)
        return resolve(f(v))
      end
      return F.fork(future, reject, transform)
    end)
  end,
  mapRej = function(future, f)
    return Future(function(reject, resolve)
      local transform
      transform = function(v)
        return reject(f(v))
      end
      return F.fork(future, transform, resolve)
    end)
  end,
  bimap = function(future, r, a)
    return Future(function(reject, resolve)
      local transform
      transform = function(v)
        return resolve(a(v))
      end
      local transformRej
      transformRej = function(v)
        return reject(r(v))
      end
      return F.fork(future, transformRej, transform)
    end)
  end,
  swap = function(future)
    return Future(function(reject, resolve)
      return F.fork(future, resolve, reject)
    end)
  end,
  race = function(a, b)
    return Future(function(reject, resolve)
      local cA, cB = noop, noop
      local clean
      clean = function()
        return cA(), cB()
      end
      local lose
      lose = function(v)
        reject(v)
        return clean()
      end
      local win
      win = function(v)
        resolve(v)
        return clean()
      end
      cA = F.fork(a, lose, win)
      cB = F.fork(b, lose, win)
      return clean
    end)
  end,
  never = function()
    local f = Future(noop)
    f.never = true
    return f
  end,
  isNever = function(future)
    return future.never == true
  end,
  isFuture = function(future)
    return Future.isFuture(future)
  end
}
setmetatable(F, {
  __call = function(self, ...)
    return Future(...)
  end
})
return F

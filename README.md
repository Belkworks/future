
# Future
*An alternative to Promises, inspired by [Fluture](https://github.com/fluture-js/Fluture)*

***THIS DOCUMENT IS OUTDATED***

**Importing with [Neon](https://github.com/Belkworks/NEON)**:
```lua
Future = NEON:github('belkworks', 'future')
```
## API
### Creating a future

When a Future is executed, the runner is passed two functions, `reject` and `resolve`.  
Calling `reject` or `resolve` (with an output as an optional argument) will settle the Future.  
Futures can only be settled once, so additional calls to `reject`/`resolve` will be ignored.  
`Future(runner) -> Future`
```lua
F = Future(function(reject, resolve)
    coroutine.wrap(function() -- do some (a)synchronous work
        resolve(123) -- resolve with the value 123
        -- reject(456) -- reject with the value 456
        -- resolve() -- resolve with no value
        -- reject() -- reject with no value
    end)()
    return function() end -- return a cancel function
end)
```

Alternatively, you can use a node-style runner by calling the `node` function.  
The runner is passed a single function, `done`, that settles the Future.  
`node(nodeback) -> Future`
```lua
node = Future.node
F = node(function(done)
    coroutine.wrap(function() -- do some (a)synchronous work
        done(nil, 123) -- resolve with value 123
        -- done(123) or done(123, nil) -- reject with value 123
        -- done() -- resolve with no value
    end)()
    -- No cancel function, return is ignored
end)
```

You can make a Future that instantly resolves using the `resolve` function.
```lua
resolve = Future.resolve
F = resolve(42)
```

Similarly, you can use the `reject` function to make a Future that instantly rejects.
```lua
reject = Future.reject
F = reject(-4)
```

### Consuming Futures
*In the following examples, `F` is a Future*.  
To run a Future, use the `fork` function.  
`fork(future, reject, resolve) -> Cancel`
```lua
fork = Future.fork
cancel = fork(F, warn, function(v)
    print('resolved with:', v)
end)

-- call cancel to unsubscribe from the execution
-- cancel()
```

If a Future is sure to succeed, You can use the `value` function.  
This function will throw if the Future is rejected.  
`value(future, resolve) -> Cancel`
```lua
value = Future.value
cancel = value(F, function(v)
    print('resolved with:', v)
end)
```

You can run a Future using the node style with the `done` function.  
The callback will receive two parameters - `e` and `v`.  
If `e` is *nil*, the Future resolved with the value `v`.  
Otherwise it rejected with the value `e`.  
`done(future, fn) -> Cancel`
```lua
done = Future.done
cancel = done(F, function(e, v)
    if e == nil then
        print('resolved with:', v)
    else
        print('rejected with:', e)
    end
end)
```

### Utilities

Every Future has a `pipe` method to allow fluent chaining of futures.  
The receiving function, in this case `map`, should take a Future as its first argument.  
`Future:pipe(fn, ...) -> Future`
```lua
resolve = Future.resolve
map = Future.map
value = Future.value

num = resolve(42)
doubled = num:pipe(map, function(v) return v*2 end)

value(doubled, print) -- prints 84
```

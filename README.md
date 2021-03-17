
# Future
*An alternative to Promises, inspired by [Fluture](https://github.com/fluture-js/Fluture)*

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
```lua
F = Future.node(function(done)
    coroutine.wrap(function() -- do some (a)synchronous work
        done(nil, 123) -- resolve with value 123
        -- done(123) or done(123, nil) -- reject with value 123
        -- done() -- resolve with no value
    end)()
    -- No cancel function, return is ignored
end)
```
  
### Consuming Futures
To run a future, use the `fork` function.
`fork(future, reject, resolve) -> Cancel`
```lua
cancel = fork(F, warn, function(v)
    print('resolved with:', v)
end)

-- call cancel to unsubscribe from the execution
-- cancel()
```
  
If a Future is sure to succeed, You can use the `value` function.  
This function will throw if the Future is rejected.
```lua
cancel = value(F, function(v)
    print('resolved with:', v)
end)
```

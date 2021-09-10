-- future.moon
-- SFZILabs 2021

noop = ->

class Future
    @ASYNC: (fn, ...) -> coroutine.wrap(fn) ...
    @STATE:
        IDLE: -2
        RUNNING: -1
        RESOLVED: 0
        REJECTED: 1
        CANCEL: 2

    new: (@Callback) =>
        @State = @@STATE.IDLE
        @Listeners = {}

    transition: (State, Value) =>
        return unless @State == @@STATE.RUNNING
        @State = State
        @Value = Value

        -- debug
        -- for i, v in pairs @@STATE
            -- if State == v
            --  print i .. ' with ' .. tostring Value
            --  break

        for C in *@Listeners
            Future.ASYNC C, @State, @Value

        @Listeners = nil

    transitioner: (State) =>
        (Value) -> @transition State, Value

    resolver: (State) =>
        @transitioner @@STATE.RESOLVED

    hook: (Callback) =>
        if @State > @@STATE.RUNNING
            Callback @State, @Value
        else table.insert @Listeners, Callback

    hookState: (Target, Callback) =>
        @hook (State, Value) ->
            return unless State == Target
            Callback Value

    fork: (Resolved, Rejected) =>
        @hookState @@STATE.RESOLVED, Resolved or ->
        @hookState @@STATE.REJECTED, Rejected or ->

        return unless @State == @@STATE.IDLE
        @State = @@STATE.RUNNING

        Resolve = @transitioner @@STATE.RESOLVED
        Reject = @transitioner @@STATE.REJECTED
        Cancel = @transitioner @@STATE.CANCEL
        
        Future.ASYNC ->
            S, E = pcall @Callback, Resolve, Reject
            if S
                if (type E) == 'function'
                    @hookState @@STATE.CANCEL, E
            else Reject E

        Cancel

    -- TODO: make static
    value: (Callback) =>
        @fork Callback, error

    -- TODO: make static
    done: (Callback) =>
        Resolved = (Value) -> Callback nil, Value
        @fork Resolved, Callback

    -- TODO: node
    -- TODO: swap
    -- TODO: lastly

    @resolve: (value) -> Future (resolve) -> resolve value
    @reject: (value) -> Future (reject) => reject value
    @never: ->
        with Future noop
            .Never = true
    -- TODO: isNever

    -- TODO: cancel the loser
    @race: (A, B) ->
        Future (resolve, reject) ->
            A\fork resolve, reject
            B\fork resolve, reject

    @alt: (A, B) ->
        Future (resolve, reject) ->
            A\fork resolve, ->
                B\fork resolve, reject

    @both: (A, B) ->
        Future (resolve, reject) ->
            A\fork (-> B\fork resolve, reject), reject

    @log: (header) -> (value) -> print "[#{header}]:", value

STATE =
    NEW: -1
    PENDING: 0
    REJECTED: 1
    RESOLVED: 2
    ERROR: 3
    CANCELED: 4

noop = ->

class Future
    @isFuture: (F) -> F.__class == @ -- TODO: support subclass?
    new: (@Operation) =>
        assert 'function' == type(@Operation), 'Future: Arg1 should be a function!'
        @State = STATE.NEW
        @Futures = {}

    drain: (Value, State) =>
        while #@Futures > 0
            f = table.remove @Futures
            f.fn Value if f.state == State

    transition: (State, Value) =>
        return if @State ~= STATE.PENDING
        @State = State

        @Value = Value
        @drain Value, State
    
    onState: (state, fn) =>
        switch @State
            when STATE.PENDING, STATE.NEW
                table.insert @Futures, :state, :fn
            when state
                fn @Value

    execute: (reject, resolve) =>
        @onState STATE.REJECTED, reject
        @onState STATE.RESOLVED, resolve

        return if @State ~= STATE.NEW
        @State = STATE.PENDING

        tReject = (value) -> @transition STATE.REJECTED, value
        tResolve = (value) -> @transition STATE.RESOLVED, value

        S, E = pcall @Operation, tReject, tResolve
        if S -- return cancellation
            -- TODO: Assert E is a function?
            (...) ->
                return if @State ~= STATE.PENDING
                @transition STATE.CANCELED
                E ...
        else
            @transition STATE.ERROR, E
            error E

    pipe: (fn, ...) =>
        F = fn @, ...
        assert @@isFuture(F), 'pipe: must return a future!'
        F

F = {}
F =
    :Future
    fork: (future, reject, resolve) -> future\execute reject, resolve
    value: (future, resolve) -> F.fork future, error, resolve
    done: (future, fn) -> F.fork future, ((V)->fn V), ((V)->fn nil, V)

    log: (T) -> (...) -> print '['..T..']: ', ...

    node: (fn) ->
        Future (reject, resolve) ->
            fn (e, v) ->
                if e == nil
                    resolve v
                else reject e

            noop

    resolve: (value) ->
        Future (reject, resolve) ->
            resolve value
            noop

    reject: (value) ->
        Future (reject, resolve) ->
            reject value
            noop

    attempt: (fn) ->
        Future (reject, resolve) ->
            S, E = pcall fn
            if S
                resolve E
            else reject E
            
            noop

    both: (a, b) -> -- b or !a or !b
        Future (reject, resolve) ->
            nowB = -> F.fork b, reject, resolve
            F.fork a, reject, nowB

    alt: (a, b) -> -- a or b or !b
        Future (reject, resolve) ->
            tryB = -> F.fork b, reject, resolve
            F.fork a, tryB, resolve

    lastly: (a, b) ->
        Future (reject, resolve) ->
            tryB = (V) -> F.fork b, reject, (-> reject V)
            nowB = (V) -> F.fork b, reject, (-> resolve V)
            F.fork a, tryB, nowB

    map: (future, f) -> -- apply f to resolve
        Future (reject, resolve) ->
            transform = (v) -> resolve f v
            F.fork future, reject, transform

    mapRej: (future, f) -> -- apply f to rejection
        Future (reject, resolve) ->
            transform = (v) -> reject f v
            F.fork future, transform, resolve

    bimap: (future, r, a) -> -- apply r to rejection, a to resolve
        Future (reject, resolve) ->
            transform = (v) -> resolve a v
            transformRej = (v) -> reject r v
            F.fork future, transformRej, transform

    swap: (future) -> -- swap branches
        Future (reject, resolve) -> F.fork future, resolve, reject

    race: (a, b) ->
        Future (reject, resolve) ->
            cA, cB = noop, noop

            clean = -> cA!, cB!

            lose = (v) ->
                reject v
                clean!

            win = (v) ->
                resolve v
                clean!

            cA = F.fork a, lose, win
            cB = F.fork b, lose, win

            clean

    never: ->
        f = Future noop
        f.never = true
        f

    isNever: (future) -> future.never == true
    isFuture: (future) -> Future.isFuture future

setmetatable F, __call: (...) => Future ...

F

-- future.moon
-- SFZILabs 2021

import insert from table
import wrap from coroutine

noop = ->

after = (fn, ...) ->
    unpack [((v) -> c v, fn v) for c in *{...}]

bound = (fn, ...) ->
    Args = { ... }
    -> fn unpack Args

cancel = (...) ->
    Args = { ... }
    -> F\cancel! for F in *Args

indexOf = (t, x) ->
    return k for k, v in pairs t when v == x

class Future
    @ASYNC: (fn, ...) -> wrap(fn) ...
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

        for C in *@Listeners
            Future.ASYNC C, @State, @Value

        @Listeners = nil

    transitioner: (State) =>
        (Value) -> @transition State, Value

    resolver: (State) =>
        @transitioner @@STATE.RESOLVED

    cancel: =>
        @transition @@STATE.CANCEL

    isDead: => @State > @@STATE.RUNNING

    hook: (Callback) =>
        if @isDead!
            Callback @State, @Value
        else insert @Listeners, Callback

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

    @resolve: (value) -> Future (resolve) -> resolve value
    @reject: (value) -> Future (reject) => reject value
    @never: ->
        with Future noop
            .Never = true

    @isNever: (F) -> F.Never == true

    @fork: (F, ...) ->
        F\fork ...

    @value: (F, Callback) ->
        F\fork Callback, error

    @done: (F, Callback) ->
        Resolved = (Value) -> Callback nil, Value
        F\fork Resolved, Callback

    @node: (Callback) ->
        Future (resolve, reject) ->
            Callback (err, value) ->
                if err == nil
                    resolve value
                else reject err

    @swap: (F) ->
        Future (resolve, reject) ->
            F\fork reject, resolve

    @race: (A, B) ->
        clean = cancel A, B
        Future (resolve, reject) ->
            A\fork after clean, resolve, reject
            B\fork after clean, resolve, reject

            clean

    @alt: (A, B) ->
        Future (resolve, reject) ->
            A\fork resolve, ->
                B\fork resolve, reject

    @both: (A, B) ->
        Future (resolve, reject) ->
            A\fork (-> B\fork resolve, reject), reject

    @lastly: (A, B) ->
        clean = cancel A, B
        Future (resolve, reject) ->
            lastly = (val) -> B\fork (bound resolve, val), reject
            lastlyRej = (err) -> B\fork (bound reject, err), reject

            A\fork lastly, lastlyRej
            clean

    @log: (header) -> (value) -> print "[#{header}]:", value
    @watch: (F, Callback = print) ->
        return if F\isDead!
        F\hook (State, Value) -> Callback (indexOf Future.STATE, k)

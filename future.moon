STATE =
	NEW: -1
	PENDING: 0
	REJECTED: 1
	RESOLVED: 2
	ERROR: 3
	CANCELED: 4

noop = ->

class Future
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

F = {}
F =
	:Future
	fork: (reject, resolve, future) -> future\execute reject, resolve
	value: (resolve, future) -> F.fork error, resolve, future

	log: (T) -> (...) -> print '['..T..']: ', ...

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
			nowB = -> F.fork reject, resolve, b
			F.fork reject, nowB, a

	alt: (a, b) -> -- a or b or !b
		Future (reject, resolve) ->
			tryB = -> F.fork reject, resolve, b
			F.fork tryB, resolve, a

	lastly: (a, b) ->
		Future (reject, resolve) ->
			tryB = (V) -> F.fork reject, (-> reject V), b
			nowB = (V) -> F.fork reject, (-> resolve V), b
			F.fork tryB, nowB, a

	map: (f, future) -> -- apply f to resovle
		Future (reject, resolve) ->
			transform = (v) -> resolve f v
			F.fork reject, transform, future

	mapRej: (f, future) -> -- apply f to rejection
		Future (reject, resolve) ->
			transform = (v) -> reject f v
			F.fork transform, resolve, future

	bimap: (r, a, future) -> -- apply r to rejection, a to resolve
		Future (reject, resolve) ->
			transform = (v) -> resolve a v
			transformRej = (v) -> reject r v
			F.fork transformRej, transform, future

	swap: (f) -> -- swap branches
		Future (reject, resolve) -> F.fork resolve, reject, f

setmetatable F, __call: (...) => Future ...

F
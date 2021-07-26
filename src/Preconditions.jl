"""
# Preconditions.jl

	function f(x)
		@require x > 0
	end

From [HTTP.jl/src/debug.jl](https://git.io/JWkNl)
"""
module Preconditions

using ReadmeDocs

const DEBUG_LEVEL = Ref(0)

export @require, @ensure


function method_name(bt)
    for f in bt
        for i in StackTraces.lookup(f)
            if !i.from_c &&
               i.linfo != nothing &&
               i.func != :precondition_error &&
               i.func != :postcondition_error &&
               i.func != :backtrace 

               return i.func
            end
        end
    end
    return "unknown method"
end


@noinline function precondition_error(msg::String)
    msg = string(method_name(backtrace()), " requires ", msg)
    return ArgumentError(msg)
end


README"""
    @require precondition [message]

Throw `ArgumentError` if `precondition` is false.
"""
macro require(condition, msg = string(condition))
    esc(:($condition || throw(Preconditions.precondition_error($msg))))
end


@noinline function postcondition_error(msg::String, ls="", l="", rs="", r="")
    @nospecialize
    msg = string(method_name(backtrace()), " failed to ensure ", msg)
    if ls != ""
        msg = string(msg, "\n", ls, " = ", sprint(show, l),
                          "\n", rs, " = ", sprint(show, r))
    end
    return AssertionError(msg)
end


# Copied from stdlib/Test/src/Test.jl:get_test_result()
iscondition(ex) = isa(ex, Expr) &&
                  ex.head == :call &&
                  length(ex.args) == 3 &&
                  first(string(ex.args[1])) != '.' &&
                  (!isa(ex.args[2], Expr) || ex.args[2].head != :...) &&
                  (!isa(ex.args[3], Expr) || ex.args[3].head != :...) &&
                  (ex.args[1] === :(==) ||
                       Base.operator_precedence(ex.args[1]) ==
                           Base.operator_precedence(:(==)))


README"""
    @ensure postcondition [message]

Throw `ArgumentError` if `postcondition` is false.
"""
macro ensure(condition, msg = string(condition))

    if DEBUG_LEVEL[] < 0
        return :()
    end

    if iscondition(condition)
        l,r = condition.args[2], condition.args[3]
        ls, rs = string(l), string(r)
        return esc(quote
            if ! $condition
                # FIXME double-execution of condition l and r!
                throw(Preconditions.postcondition_error($msg,
                                                        $ls, $l, $rs, $r))
            end
        end)
    end

    esc(:(if ! $condition throw(Preconditions.postcondition_error($msg)) end))
end



end # module

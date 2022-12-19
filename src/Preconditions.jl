"""
# Preconditions.jl

	function f(x)
		@require x > 0
	end

From [HTTP.jl/src/debug.jl](https://git.io/JWkNl)
"""
module Preconditions

const USE_PREFERENCES_JL = VERSION >= v"1.6"
@static if USE_PREFERENCES_JL
using Preferences
end
using ReadmeDocs

export @require, @ensure


@static if USE_PREFERENCES_JL
const check_preconditions = @load_preference("check_preconditions", true)
enable_preconditions(x=true) = @set_preferences!("check_preconditions" => x)
disable_preconditions() = enable_preconditions(false)

const check_postconditions = @load_preference("check_postconditions", true)
enable_postconditions(x=true) = @set_preferences!("check_postconditions" => x)
disable_postconditions() = enable_postconditions(false)

function __init__()
    check_preconditions || @warn "Precondition checking is disabled!"
    check_postconditions || @warn "Postcondition checking is disabled!"
end
else
const check_preconditions = true
const check_postconditions = true
end # @static if USE_PREFERENCES_JL



function method_name(bt)
    for f in bt
        for i in StackTraces.lookup(f)
            if !i.from_c &&
               i.linfo != nothing &&
               !(contains(string(i.func), "precondition_error")) &&
               !(contains(string(i.func), "postcondition_error")) &&
               i.func != :backtrace 

               return i.func
            end
        end
    end
    return "unknown method"
end


@noinline function precondition_error(msg::String; args...)
    @nospecialize
    msg = string(method_name(backtrace()), " requires ", msg)
    @error msg args...
    msg = string(msg, (", $k=$v" for (k,v) in args)...)
    return ArgumentError(msg)
end


@doc README"""
    @require precondition [message] [variables...]

Throw `ArgumentError` if `precondition` is false.
Include the value of `variables...` in the error message.
"""
macro require(condition, args...)

    check_preconditions || return :()

    if length(args) > 0 && args[1] isa String
        msg = args[1]
        args = args[2:end]
    else
        msg = string(condition)
    end
    for a in args
        if !(a isa Symbol)
            throw(ArgumentError("Invalid `@require` variable name: $a"))
        end
    end
    esc(:($condition || throw(Preconditions.precondition_error($msg; $(args...)))))
end


@noinline function postcondition_error(msg::String, ls="", l="", rs="", r="")
    @nospecialize
    msg = string(method_name(backtrace()), " failed to ensure ", msg)
    Main.eval(:(@error($msg, $(Symbol(ls))=$(QuoteNode(l)),
                             $(Symbol(rs))=$(QuoteNode(r)))))
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
                   ex.args[1] === :isa ||
                       Base.operator_precedence(ex.args[1]) ==
                           Base.operator_precedence(:(==)))


@doc README"""
    @ensure postcondition [message]

Throw `AssertionError` if `postcondition` is false.
"""
macro ensure(condition, msg = string(condition))

    check_postconditions || return :()

    if iscondition(condition)
        f, l, r = condition.args
        ls, rs = string(l), string(r)
        return esc(quote
            let l = $l, r = $r
                if ! $f(l,r)
                    throw(Preconditions.postcondition_error($msg,
                                                            $ls, l, $rs, r))
                end
            end
        end)
    end

    esc(:(if ! $condition throw(Preconditions.postcondition_error($msg)) end))
end



end # module

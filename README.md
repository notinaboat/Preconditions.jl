# Preconditions.jl

```
function f(x)
	@require x > 0
end
```

From [HTTP.jl/src/debug.jl](https://git.io/JWkNl)


### `Preconditions.@require`

    @require precondition [message] [variables...]

Throw `ArgumentError` if `precondition` is false.
Include the value of `variables...` in the error message.


### `Preconditions.@ensure`

    @ensure postcondition [message]

Throw `AssertionError` if `postcondition` is false.

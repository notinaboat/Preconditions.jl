# Preconditions.jl

```
function f(x)
	@require x > 0
end
```

From [HTTP.jl/src/debug.jl](https://git.io/JWkNl)


    @require precondition [message]

Throw `ArgumentError` if `precondition` is false.


    @ensure postcondition [message]

Throw `ArgumentError` if `postcondition` is false.




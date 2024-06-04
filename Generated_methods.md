## Methods of the generated functions

Each `@problem` macro generates in the workspace five methods to be used for
producing the individual problems. Let's take an example:
```julia
@problem sub_add begin
    z ~ rand(7:9)
    w ~ rand(1:5)
    @solution begin
      zw_sub ~ z - w
      zw_add ~ z + w
    end
    @text raw""" Find the difference \(c = a - b\) and sum  \(d = a + b\)
    of two values: \(a = %z%\) and \(b = %w%\)
    """
    @text_solution raw"""
      Difference is equal to  \(c = %zw_sub%\), sum is equal to  \(c = %zw_add%\)
    """
end
```

That macro call is equivalent to manually defining the following five methods:

```julia
function sub_add() 
    z = rand(7:9)
    w = rand(1:5)
    zw_sub,zw_add = sub_add(z, w)

    return z,w,zw_sub,zw_add
end

function sub_add(z, w)
    zw_sub = z - w
    zw_add = z + w
    return zw_sub,zw_add
end

sub_add(::Val{:vars}) = [:z, :w, :zw_sub, :zw_add]

sub_add(::Val{:text}) = " Find the difference \\(c = a - b\\) and sum  \\(d = a + b\\)\nof two values: \\(a = %z%\\) and \\(b = %w%\\)\n"

sub_add(::Val{:solution_text}) = "  Difference is equal to  \\(c = %zw_sub%\\), sum is equal to  \\(c = %zw_add%\\)\n"

```
When processing the macros, the left-hand sides of tilde `~` operators are collected
and then the tildes are replaced by the equality signs `=`. Otherwise the syntax
within the macro is the usual Julian syntax. The left-hand sides must always
represent a single variable; assignment to a tuple is unsupported.

The first method generates (usually randomized) data for the problem's statement.

The second method computes the solution. Arguments for this method are the symbols that 
appear at the left-hand side of the tilde operator within the `@problem` macro,
but not the `@solution` macro. Their order as the arguments of the method call is the same
as their order of appearance at the left-hand side of the tilde. Those variables may be
assigned in the different order from what needed for the solution method, in which case
after assigning the needed values one may signal the inteded order in this fashion:

```julia

first_variable ~ first_variable
second_variable ~ second_variable
...
```
Other than telling the macro how to order the arguments of the second method, this is no-op.
To avoid ambiguity, it is not recommended to repeat any symbol at the left-hand side
of the tilde operator, and doing so produces a warning.


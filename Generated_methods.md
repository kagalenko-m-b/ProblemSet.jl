## Methods of the generated functions

Each `@problem` macro generates in the workspace four methods to be used for
producing the individual problems. Consider an example:
```julia
@problem sub_add begin
    z ~ rand(7:9)
    w ~ rand(1:5)
    @solution begin
      zw_sub ~ z - w
      zw_add ~ z + w
    end
    @text raw"""Find the difference \(c = a - b\) and sum  \(d = a + b\)
    of two values: \(a = %z%\) and \(b = %w%\)
    """
    @text_solution raw"""
      Difference is equal to  \(c = %zw_sub%\), sum is equal to  \(d = %zw_add%\)
    """
end
```

That macro call is equivalent to manually defining the following four methods:

```julia
function sub_add() 
    z = rand(7:9)
    w = rand(1:5)
    zw_sub,zw_add = sub_add(z, w)

    return (;z,w,zw_sub,zw_add)
end

function sub_add(z, w)
    zw_sub = z - w
    zw_add = z + w
    return (;zw_sub,zw_add)
end

sub_add(::Val{:text}) = TokenText(
      ["Find the difference \\(c = a - b\\) and sum  \\(d = a + b\\) of two values: \\(a = ",
       "\\) and \\(b = ", "\\)"],
      [x->x.a, x->x.b]
    )

sub_add(::Val{:solution_text}) = TokenText(
      [" Difference is equal to  \\(c = ", "\\), sum is equal to  \\(c = ", "\\)"],
      [x->x.zw_sub, x->x.zw_add]
    )

```
Macro collects the left-hand sides of tilde `~` operators
and replaces the tildes with the equality signs `=`. Otherwise the syntax
within the macro is the usual Julian syntax. The left-hand side of a tilde must always
be a single variable; assignment to a tuple is unsupported. The value assigned
to that variable may be a matrix or a tuple. Indexing of text variables is supported.

The first method generates data for the problem's statement.

The second method computes the solution. Arguments for this method are the symbols that 
appear at the left-hand side of the tilde operator within the `@problem` macro,
but not the `@solution` macro. Their order as the arguments of the method call is the same
as their order of appearance at the left-hand side of the tilde. 
To avoid ambiguity, it is not recommended to use a symbol at the left-hand side
of more than one tilde operator, and doing so produces a warning.


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

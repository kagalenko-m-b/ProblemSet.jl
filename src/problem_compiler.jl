
"""
    @problemset(set_name, set_body)

Macro to specify a set of problems.
"""
macro problemset(set_name, set_body)
    @assert set_body.head == :block "Syntax error: Expecting block of definitions!"
    prob_names = []
    for prob in skiplinenums(set_body.args)
        @assert is_macro(prob, :problem) "Only problems allowed in problemset!"
        prob.args[3] = Symbol(string(set_name)*'_'*string(prob.args[3]))
        push!(prob_names, prob.args[3])
    end
    if !allunique(prob_names)
        error("problem names must be unique within the set")
    end
    quote
        $(esc(set_body))
        $(esc(set_name)) = $(esc(:Function))[$([:($(esc(prob))) for prob in prob_names]...)]
    end
end

"""
    @problem(name, body)

Macro to specify a problem.
"""
macro problem(name, body)
    pr = problem(__module__, __source__, name, body)
    return esc(pr)
end

function problem(mod, linenumbernode, name, body)
    problemdef = process_body(mod, name, body)
    problem_out = build_output(problemdef, linenumbernode)

    return problem_out
end

"""
    process_problem(mod, expr)

Modify tilde expressions and gather their left-hand sides
"""
function process_body(mod, name, body)
    problemdef = Dict{Symbol,Any}(:name=>name,:kwargs=>[],:args=>[])
    cond_text = filter(x->is_macro(x, :text), body.args)
    @assert length(cond_text) <= 1 "more than one @text in problem"
    problemdef[:cond_text] = isempty(cond_text) ? nothing : macro_body(cond_text[], :text)
    body_args = filter(x->!is_macro(x, :text), body.args)
    #
    sol_text = filter(x->is_macro(x, :text_solution), body_args)
    @assert length(sol_text) <= 1 "more than one @solution_text in problem"
    problemdef[:sol_text] = isempty(sol_text) ? nothing : macro_body(sol_text[], :text_solution)
    filter!(x->!is_macro(x, :text_solution), body_args)
    #
    sol_body = filter(x->is_macro(x, :solution), body_args)
    @assert length(sol_body) <= 1 "each problem must have no more than one @solution"
    sol_body = isempty(sol_body) ? "" : macro_body(sol_body[], :solution)
    sol_vars = Symbol[]
    sol_body = process_body!(mod, sol_vars, sol_body)
    problemdef[:sol_body] = sol_body
    allunique(sol_vars) || @warn("duplicate variables at the left-hand "
                                 *"side of the tilde operator in @solution")
    problemdef[:sol_vars] = unique(sol_vars)
    #
    body_args = map(x->is_macro(x, :solution) ? :(:solution) : x, body_args)
    cond_body = Expr(body.head, body_args...)
    cond_vars = Symbol[]
    cond_body = process_body!(mod, cond_vars, cond_body)
    allunique(cond_vars) || @warn("duplicate variables at the left-hand "
                                 *"side of the tilde operator in @problem")
    problemdef[:cond_vars] = unique(cond_vars)
    problemdef[:cond_body] = cond_body

    return problemdef
end

"""
    process_body!(mod, vars, expr)

Modify tilde expressions and gather their left-hand sides
"""
process_body!(mod::Module, vars::Vector{Symbol}, x) = x
function process_body!(mod::Module, vars::Vector{Symbol}, expr::Expr)
    # Do not touch interpolated expressions
    expr.head === :$ && return expr.args[1]
    # @solution macro must have been replaced before the call
    @assert !is_macro(expr, :solution)
    # If it's a macro, expand it, unless it's @solution
    if Meta.isexpr(expr, :macrocall) && !is_macro(expr, :solution)
        return process_body!(mod, vars, macroexpand(mod, expr; recursive=true))
    end
    # Modify tilde operators and collect left-hand sides
    args_tilde = getargs_tilde(expr)
    if args_tilde !== nothing
        L, R = args_tilde
        push!(vars, L)
        return :($(L) = $(R))
    end

    return Expr(expr.head, map(x -> process_body!(mod, vars, x), expr.args)...)
end

function build_output(problemdef, linenumbernode)
    all_vars = [problemdef[:cond_vars]; problemdef[:sol_vars]]
    return_expr = :(return (;$(all_vars...)))
    #
    cond_body = problemdef[:cond_body]
    cond_args = cond_body.args
    idx_solution = findfirst(x-> x == :(:solution), cond_args)
    # in place of @solution macro, insert into the problem's condition
    # call to the solution function
    if isempty(problemdef[:sol_vars])
        sol_expr = Expr(:call, problemdef[:name], problemdef[:cond_vars]...)
    else
        sol_expr = Expr(Symbol("="),  Expr(:tuple, problemdef[:sol_vars]...),
                        Expr(:call, problemdef[:name], problemdef[:cond_vars]...))
    end
    if !isnothing(idx_solution)
        cond_args[idx_solution] = sol_expr
        cond_body.args = [linenumbernode; cond_body.args; return_expr]
    end
    problemdef[:body] = cond_body
    ex_cond_function = MacroTools.combinedef(problemdef)
    #
    problemdef[:args] = problemdef[:cond_vars]
    sol_body =  problemdef[:sol_body]
    return_expr = :(return (;$(problemdef[:sol_vars]...)))
    sol_body = quote
        $linenumbernode
        $sol_body
        $return_expr
    end
    problemdef[:body] = sol_body
    ex_sol_function = MacroTools.combinedef(problemdef)
    #
    problemdef[:args] = [:(::Val{:text})]
    if :cond_text in keys(problemdef)
        problemdef[:body] = tokenize_text(problemdef[:cond_text], all_vars)
    else
        problemdef[:body] = nothing
    end
    ex_text_function = MacroTools.combinedef(problemdef)
    #
    problemdef[:args] = [:(::Val{:solution_text})]
    if :sol_text in keys(problemdef)
        problemdef[:body] = tokenize_text(problemdef[:sol_text], all_vars)
    else
        problemdef[:body] = nothing
    end
    ex_solution_text_function = MacroTools.combinedef(problemdef)
    #
    return quote
        $ex_cond_function
        $ex_sol_function
        $ex_text_function
        $ex_solution_text_function
    end
end

# utility functions
"""
    getargs_tilde(x)

Return the arguments `L` and `R`, if `x` is an expression of the form `L ~ R`, or `nothing`
otherwise.
"""
getargs_tilde(x) = nothing

function getargs_tilde(expr::Expr)
    @capture(expr, L_Symbol ~ R_) || return nothing
    return (L, R)
end

is_macro(x, name)=false
function is_macro(ex::Expr, macro_name)
    Meta.isexpr(ex, :macrocall) && (ex.args[1] === Symbol('@'*string(macro_name)))
end

function macro_body(expr, name, n_args=1)
    is_macro(expr, name) || return nothing
    args = filter(e -> !(e isa LineNumberNode), expr.args)
    if length(args) != n_args+1
        throw(ArgumentError("number of arguments of macro @$(string(name)) "*
            "must be equal to $n_args"))
    end
    args[end]
end

skiplinenums(exprs) = filter(e -> !(e isa LineNumberNode), exprs)

"""
    substrings,tokens = tokenize_text(str, vars)

"""
function tokenize_text(str::AbstractString, vars::AbstractVector{Symbol})
    rgx = r"%(?<var>\w+)(?<idx>\[[^\]]+\])?%"
    funcdef = Dict(:args=>Any[:data], :body=>:(data), :kwargs=>Any[])
    tokens = Function[]
    for vm in eachmatch(rgx, str)
        if !in(Symbol(vm[:var]), vars)
            @warn("text variable $(vm[:var]) is not in problem variables")
            funcdef[:body] = :nothing
        else
            var_str = "data.$(vm[:var])"
            var_str *= isnothing(vm[:idx]) ? "" : vm[:idx]
            var_ex = Meta.parse(var_str)
            funcdef[:body] = var_ex
        end
        push!(tokens, eval(combinedef(funcdef)))
    end
    strs = collect(eachsplit(str,rgx))
    tt = TokenText(strs, tokens)

    return tt
end
tokenize_text(ex::Expr, vars::AbstractVector{Symbol}) = tokenize_text(eval(ex), vars)
tokenize_text(::Nothing, vars) = nothing

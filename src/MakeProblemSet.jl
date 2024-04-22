module MakeProblemSet

using MacroTools
using Random

export @problem, @problemset, problemset_latex

include("problem_compiler.jl")

function select_problems(subsets::Vector{<:Pair{<:Integer,<:AbstractRange{<:Integer}}})
    idx = Int[]
    for s in subsets
        N,range = s
        idx_r = randperm(length(range))
        append!(idx, range[idx_r[1:N]])
    end
    sort!(unique!(idx))

    return idx
end
select_problems(subset::Pair{Int, UnitRange{Int}}) = select_problems([subset])

function problemset_latex(
    names::AbstractVector{String},
    problems::AbstractVector{Function},
    subsets,
    rng_seed::Integer
    )
    N = length(names)
    txt = ""
    for n in 1:N
        txt *= "\\section{$(names[n])}\n"
        problems_active = select_problems(subsets)
        for p in problems_active
            Random.seed!(rng_seed + n + p)
            pr = problems[p]
            condition = build_text(:text, pr)
            solution =  build_text(:solution_text, pr)
            txt *= "\\underline{Задача $(p):}\n\n"
            txt *= "\\ifdefined\\issolution\n$(solution)\n\\else\n"
            txt *= "$(condition)\n\\fi}\n\n"
        end
        txt *= "\\newpage\n"
    end

    return txt
end

function build_text(kind::Symbol, pr::Function)
    data = pr()
    vars = pr(Val(:vars))
    str = pr(Val(kind))
    ms = eachmatch(r"%(\w+)%", str)
    vars_text = [Symbol(m.captures[1]) for m in ms]
    for k in 1:length(vars_text)
        v = vars_text[k]
        idx = findfirst(x->x===v, vars)
        if isnothing(idx)
            error("text variable $(v) is not in problem $(pr) variables")
        end
        str = replace(str, Regex("%$(string(v))%")=>"$(data[idx])")
    end
    str = replace(str, '\n'=>' ')
    str = replace(str, r" +"=>s" ")
    str = strip(str)
    return str
end

end

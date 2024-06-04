module MakeProblemSet

using MacroTools
using Random

export @problem, @problemset, problemset_latex, latex_preamble,latex_preamble_ru

include("problem_compiler.jl")

latex_preamble = """
\\documentclass[a4paper,12pt,notitlepage]{article}
\\usepackage{amsmath}
\\usepackage[left=1.cm,right=1cm,top=1cm,bottom=1cm]{geometry}
\\pagenumbering{gobble}
\\usepackage{fontspec}
\\usepackage{polyglossia}
\\usepackage{csvmerge}
\\usepackage{float}
\\usepackage{graphicx}
\\usepackage{bookmark}
\\setmainfont{Liberation Serif}
\\setsansfont{Liberation Sans}\n\n"""

function select_problems(
    Nmax::Integer, subsets::Vector{<:Pair{<:Integer,<:AbstractRange{<:Integer}}}
    )
    idx = Int[]
    for s in subsets
        N,range = s
        if maximum(range) > Nmax
            error("subset specification $(s) has greater range than the number"
                  *"of available problems: $Nmax")
        end
        idx_r = randperm(length(range))
        append!(idx, range[idx_r[1:N]])
    end
    sort!(unique!(idx))

    return idx
end

function select_problems(
    Nmax::Integer, subset::Pair{<:Integer,<:AbstractRange{<:Integer}}
    )
    return select_problems(Nmax, [subset])
end

"""
    problemset_latex(args...) -> (String,String)

Generate the latex source of the problems and solutions.

# Arguments

- `student_names::AbstractVector{String}`: Students' names
- `problems::AbstractVector{Function}`: Vector of functions defined using @problem macro
- `subsets::Union{Pair,Vector{<:Pair}}`: Subset specification or vector of specifications
- `rng_seed::Integer`: Random number generator's seed to make generated sets repeatable

Subset specifications instructs the function how to pick problems to be assigned to a
student from the supplied vector. For example, the specification [1=>1:3, 2=>4:7]
will select one out of the first three problems, two out of the problems four to seven
and then combine the results. If the ranges overlap, only unique problem numbers are kept.

# Example
```julia-repl
julia> student_names = ["A", "B", "C"];
julia> rng_seed = 123
julia> txt,txt_sol =  problemset_latex(student_names, my_set, 2=>1:3, rng_seed);
julia> write("problems.tex", latex_preamble*txt);
julia> write("solutions.tex", latex_preamble*txt);
```
"""
function problemset_latex(
    student_names::AbstractVector{<:AbstractString},
    problems::AbstractVector{Function},
    subsets::Union{Pair,Vector{<:Pair}},
    rng_seed::Integer;
    set_title::String=""
    )
    N = length(student_names)
    M = length(problems)
    txt = "\\begin{document}\n"
    txt_sol = txt
    for n in 1:N
        if !isempty(set_title)
            txt *= "{\\centering\n\\textbf{$set_title}\\\\\n}"
        end
        txt *= "\\section{$(student_names[n])}\n"
        txt_sol *= "\\section{$(student_names[n])}\n"
        problems_active = select_problems(M, subsets)
        for p in problems_active
            Random.seed!(rng_seed + n + p)
            pr = problems[p]
            data = pr()
            condition = build_text(:text, pr, data)
            solution =  build_text(:solution_text, pr, data)
            txt *= "\\underline{Задача $(p):}\n\n$(condition)\n\n"
            txt_sol *= "\\underline{Задача $(p):}\n\n$(solution)\n\n"
        end
        txt *= "\\newpage\n"
        txt_sol *= "\\newpage\n"
    end
    txt *= "\\end{document}\n"
    txt_sol *= "\\end{document}\n"
    return txt,txt_sol
end
function problemset_latex(
    number_variants::Integer,
    problems::AbstractVector{Function},
    subsets::Union{Pair,Vector{<:Pair}},
    rng_seed::Integer
    )
    nms = ["$(k)" for k in 1:number_variants]
    problemset_latex(nms, problems, subsets,  rng_seed)
end

function build_text(kind::Symbol, pr::Function, data::Tuple)
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

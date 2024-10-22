module ProblemSet

using MacroTools
using Random

export @problem, @problemset, TokenText, problemset_latex, latex_preamble

struct TokenText
    strings::Vector{<:AbstractString}
    tokens::Vector{Function}
    function TokenText(strings, tokens)
        @assert(length(strings) == length(tokens) + 1, "tokens must intersperse substrings")
        new(strings, tokens)
    end
end
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
    Nmax::Integer, subsets::Vector{<:Pair{<:Integer,<:AbstractVector{<:Integer}}}
    )
    idx = Int[]
    for s in subsets
        N,range = s
        if maximum(range) > Nmax
            throw(ArgumentError("subset specification $(s) has greater range "
                                *"than the number of available problems: $Nmax"))
        end
        idx_r = randperm(length(range))
        append!(idx, range[idx_r[1:N]])
    end
    sort!(unique!(idx))

    return idx
end

function select_problems(
    Nmax::Integer, subset::Pair{<:Integer,<:AbstractVector{<:Integer}}
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
    problems::AbstractVector{<:Function},
    subsets::Union{Pair,AbstractVector{<:Pair}},
    rng_seed::Integer;
    set_title::String="",
    problem_title="Problem"
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
            txt *= "\\underline{$(problem_title) $(p):}\n\n$(condition)\n\n"
            txt_sol *= "\\underline{$(problem_title) $(p):}\n\n$(solution)\n\n"
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
    problems::AbstractVector{<:Function},
    subsets::Union{Pair,AbstractVector{<:Pair}},
    rng_seed::Integer;
    set_title::String="",
    problem_title="Problem"
    )
    nms = ["$(k)" for k in 1:number_variants]
    problemset_latex(nms, problems, subsets,  rng_seed; set_title, problem_title)
end

function build_text(kind::Symbol, pr::Function, var_data::Tuple)
    txt_tok = pr(Val(kind))
    if isnothing(txt_tok) || length(txt_tok.strings) == 0
        return ""
    end
    # Number of substrings within the tokenized text must be larger by one
    # than the number of token expressions.
    N = length(txt_tok.strings)
    str_out = txt_tok.strings[1]
    for n in 2:N
        str_out *= to_string(txt_tok.tokens[n - 1](var_data))
        str_out *= txt_tok.strings[n]
    end

    return str_out
end

to_string(x) = string(x)
to_string(::Nothing) = "nothing"
function to_string(z::Complex)
    x,y = reim(z)
    if x == 0
        s = "i*$(y)"
    elseif y == 0
        s = "$(x)"
    else
        s = "$(x) + i*$(y)"
    end

    return s
end

end

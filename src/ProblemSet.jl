module ProblemSet

using MacroTools
using Random

export TokenText, SubSet, @problem, @problemset, @questions_str, latex_preamble
export problemset_latex

# const PSet = AbstractVector{<:Function}
const SubSet = Pair

struct TokenText
    strings::Vector{<:AbstractString}
    tokens::Vector{Function}
    function TokenText(strings, tokens)
        @assert(length(strings) == length(tokens) + 1, "tokens must intersperse substrings")
        new(strings, tokens)
    end
end
include("problem_compiler.jl")

function latex_preamble(
    ;font_size_pt::Integer=12, default_language=:english, landscape::Bool=false
    )
    landscape_str = landscape ? ",landscape" : ""
    str_out = """
    \\documentclass[a4paper,$(font_size_pt)pt,notitlepage$landscape_str]{extarticle}
    \\usepackage{amsmath}
    \\usepackage[left=1cm,right=1cm,top=1cm,bottom=1cm]{geometry}
    \\pagenumbering{gobble}
    \\usepackage{fontspec}
    \\usepackage{polyglossia}
    \\usepackage{csvmerge}
    \\usepackage{float}
    \\usepackage{graphicx}
    \\usepackage{bookmark}
    \\usepackage{tabularx}
    \\usepackage[table]{xcolor}
    \\setdefaultlanguage{$default_language}
    \\setmainfont{Liberation Serif}
    \\setmonofont{Liberation Mono}
    \\setsansfont{Liberation Sans}\n\n"""
end

function select_problems(
    num_variants::Integer,
    set_size::Integer,
    subsets::AbstractVector{<:SubSet}
    )
    num_subsets = length(subsets)
    if length(subsets) > 1
        isempty(intersect((x->x.second).(subsets)...)) ||  @warn "subsets overlap"
    end
    problems_idx = zeros(Int, num_variants, 0)
    for n in 1:num_subsets
        problems_idx = hcat(problems_idx,
                            select_problems(num_variants, set_size, subsets[n]))
    end
    
    return problems_idx
end

function select_problems(
    num_variants::Integer,
    set_size::Integer,
    subset::SubSet
    )
    num_problems,num_range = subset
    if maximum(num_range) > set_size
            throw(ArgumentError("subset specification $(subset) has greater range "
                                *"than the number of available problems: $set_size"))
    end
    range_len = length(num_range)
    range_unique_len = length(unique(num_range))
    if range_unique_len < num_problems
        throw(ArgumentError("can't select $num_problems unique problems from "
                            *" subset specification with $range_unique_len unique problems"))
    end
    # use randperm() to minimize the repeated assignments of the same problem
    # increase the number of repetitons by one, ensuring that 'while true'
    # loop below hits the break condition
    n_repeat = div(num_variants*num_problems, range_len, RoundUp) + 1
    idx = randperm(range_len*n_repeat)
    # For simplicity, this array implements a queue by means of push!() and popfirst!()
    range_idx = repeat(num_range, n_repeat)[idx]
    problem_idx = -ones(eltype(num_range), num_variants, num_problems)
    for k in 1:num_variants
        problem_idx[k, 1] = popfirst!(range_idx)
        for n in 2:num_problems
            while true # number of distinct elements in num_range is not less than
                       # num_problems, therefore this loop terminates
                el_n = popfirst!(range_idx)
                if el_n in problem_idx[k, :]
                    push!(range_idx, el_n)
                else
                    problem_idx[k, n] = el_n
                    break
                end
            end
        end
        sort!(view(problem_idx, k, :))
    end

    return problem_idx
end

"""
    problemset_latex(args...) -> (String,String)

Generate the latex source of the problems and solutions.

# Arguments
- `student_names::AbstractVector{String}`: Students' names
- `problems::AbstractVector{Function}`: Vector of functions defined using @problem macro
- `subsets::Union{SubSet,Vector{<:SubSet}}`: Subset specification or vector of specifications
- `rng_seed::Integer`: Random number generator's seed to make generated sets repeatable
- `set_title::String`: Title of the problem set
- `problem_title::String`: Constant part of the title of individual problems

# Returns
- `txt::String`: LaTeX source of the problem set
- `txt_sol::String`: LaTeX source of the soltuion for the problem set

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
    problems_active = select_problems(N, M, subsets)
    for n in 1:N
        if !isempty(set_title)
            txt *= "{\\centering\n\\textbf{$set_title}\\\\\n}"
        end
        txt *= "\\section{$(student_names[n])}\n"
        txt_sol *= "\\section{$(student_names[n])}\n"
        for p in problems_active[n, :]
            Random.seed!(rng_seed + n + p)
            pr = problems[p]
            data = pr()
            condition = build_text(:text, pr, data)
            solution =  build_text(:solution_text, pr, data)
            txt *= "\\underline{$(problem_title) $(p):}\n\n$(condition)\\\\\n"
            txt_sol *= "\\underline{$(problem_title) $(p):}\n\n$(solution)\\\\\n"
        end
        txt *= "\\newpage\n"
        txt_sol *= "\\newpage\n"
    end
    txt *= "\\end{document}\n"
    txt_sol *= "\\end{document}\n"
    return txt,txt_sol
end
function problemset_latex(
    number_variants::Integer, problems, subsets, rng_seed;
    set_title::String="", problem_title="Problem"
    )
    nms = ["" for k in 1:number_variants]
    problemset_latex(nms, problems, subsets,  rng_seed; set_title, problem_title)
end

function build_text(kind::Symbol, pr::Function, var_data::NamedTuple)
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
        s = y==0 ? "0" : "$(y)i"
    elseif y == 0
        s = "$(x)"
    else
        s = y > 0 ? "$(x) + $(y)i" : "$(x) - $(-y)i"
    end

    return s
end

end

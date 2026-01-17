module ProblemSet

using MacroTools
using Random

export TokenText, SubSet, @problem, @problemset, @questions_str, latex_preamble
export problemset_latex,compile_variants

const PSet = AbstractVector{<:Function}
const SubSet = Pair{<:Integer,<:PSet}

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
    subsets
    )
    num_subsets = length(subsets)
    if length(subsets) > 1
        isempty(intersect((x->x.second).(subsets)...)) ||  @warn "subsets overlap"
    end
    # how many problems in each variant
    num_problems_total = sum(num_problems for (num_problems,_) in subsets)
    # enable finding unique index of a problem for seeding the random nuber generator
    problems_all = unique(mapreduce(x->x[2], vcat, subsets))
    problem_index = Dict(prob=>k for (k,prob) in enumerate(problems_all))
    #
    problems = Matrix{Function}(undef, num_variants, num_problems_total)
    num_problems_assigned = 0
    for n in 1:num_subsets
        num_problems,problem_set = subsets[n]
        num_range = 1:length(problem_set)
        columns_idx = num_problems_assigned + 1:num_problems_assigned+num_problems
        problems_idx = select_unique(num_variants, num_problems, num_range)
        problems[:,columns_idx] = problem_set[problems_idx]
        num_problems_assigned += num_problems
    end

    return problems,problem_index
end

"""
Select `num_variants` variants, making sure indices are unique within each variant
and problems are reused within different variants as little as possible.
"""
function select_unique(
    num_variants::Integer,
    num_problems::Integer,
    num_range::AbstractVector
    )
    range_len = length(num_range)
    range_unique_len = length(unique(num_range))
    @assert(range_unique_len >= num_problems, "can't select $num_problems unique problems "*
        "from subset specification with $range_unique_len unique problems")
    # use randperm() to minimize the repeated variants of the same problem
    # increase the number of repetitions by one, ensuring that 'while true'
    # loop below hits the break condition
    n_repeat = div(num_variants*num_problems, range_len, RoundUp) + 1
    idx = randperm(range_len*n_repeat)
    # For simplicity, this array implements a queue by means of push!() and popfirst!()
    range_idx = repeat(num_range, n_repeat)[idx]
    problem_idx = zeros(eltype(num_range), num_variants, num_problems)
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
- `variants::AbstractVector{String}`: Students' names
- `problems::AbstractVector{Function}`: Vector of functions defined using @problem macro
- `subsets::Union{SubSet,Vector{<:SubSet}}`: Subset specification or vector of specifications
- `rng_seed::Integer`: Random number generator's seed to make generated sets repeatable
- `set_title::String`: Title of the problem set
- `problem_title::String`: Constant part of the title of individual problems

# Returns
- `txt::String`: LaTeX source of the problem set
- `txt_sol::String`: LaTeX source of the soltuion for the problem set

Subset specifications instructs the function how to pick problems to be assigned to a
student from the supplied vector. For example, the specification
[1=>problems[1:3], 2=>problems[4:7]]
will select one out of the first three problems, two out of the problems four to seven
and then combine the results.

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
    variants::AbstractVector{<:AbstractString},
    rng_seed::Integer,
    subsets::Vararg{SubSet};
    set_title::String="",
    problem_title="Problem"
    )
    N = length(variants)
    section_title = isempty(set_title) ? "" : "{\\centering\n\\textbf{$set_title}\\\\\n}"
    section_head(n) = section_title*"\\section{$(variants[n])}\n"
    problem_head(p_index) = "\\underline{$(problem_title) $(p_index):}\n"
    compile_variants(N, rng_seed, subsets...; section_head, problem_head)
end

function problemset_latex(
    number_variants::Integer, rng_seed::Integer, subsets...;
    set_title::String="", problem_title="Problem"
    )
    nms = [" " for k in 1:number_variants]
    problemset_latex(nms,  rng_seed, subsets...; set_title, problem_title)
end

function problemset_latex(
    variants,
    problems::AbstractVector{<:Function},
    subsets_old::Union{Pair,AbstractVector{<:Pair}},
    rng_seed::Integer;
    set_title::String="",
    problem_title="Problem"
    )
    @warn("This method is deprecated and will be removed in future versions", maxlog=1)
    subsets = (num_problems=>problems[problems_idx]
               for (num_problems, problems_idx) in subsets_old)
    problemset_latex(variants, rng_seed, subsets...; set_title, problem_title)
end

function compile_variants(
    number_variants::Integer,
    rng_seed::Integer,
    subsets::Vararg{SubSet};
    document_head::AbstractString="\\begin{document}\n",
    document_foot::AbstractString="\\end{document}\n",
    section_head::Function,
    section_foot::AbstractString="\\newpage\n",
    problem_head::Function,
    problem_foot::AbstractString="\\ \\\\\n"
    )
    txt = document_head
    txt_sol = txt
    Random.seed!(rng_seed)
    problems,problem_index = select_problems(number_variants, subsets)
    for n in 1:number_variants
        txt *= section_head(n)
        txt_sol *= section_head(n)
        for problm in problems[n, :]
            p_index = problem_index[problm]
            Random.seed!(rng_seed + n + p_index)
            data = problm()
            condition = build_text(:text, problm, data)
            solution = build_text(:solution_text, problm, data)
            txt *= problem_head(p_index)*condition*problem_foot
            txt_sol *= problem_head(p_index)*solution*problem_foot
        end
        txt *= section_foot
        txt_sol *= section_foot
    end
    txt *= document_foot
    txt_sol *= document_foot

    return txt,txt_sol
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

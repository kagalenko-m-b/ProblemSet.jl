# ProblemSets

[![Build Status](https://github.com/kagalenko-m-b/ProblemSets.jl/workflows/CI/badge.svg)](https://github.com/kagalenko-m-b/ProblemSets.jl/actions)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

This package facilitates creation of  assignments for a group of students. It allows
to randomize the assignments in two ways:

* [random selection](Random_selection.md) of problems from a set, and

* [random variations](Random_variations.md) of the specified parts of an individual
problem's statement.

Those two kinds of randomization may be combined.

A problem set consists of several problem templates. Each template may hold the textual
statement of the problem, its solution and fragments of Julia code to vary
the values of placeholder variables within the statement and the solution.

The package exports macros `@problem` and `@problemset` that create a template and a set,
respectively. Function `problemset_latex()` generates the latex sources of
assignments and their solutions. To ensure reproducibility, it calls `Random.seed!()`
with an incremental value before generating each succesive problem.

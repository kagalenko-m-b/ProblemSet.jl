## Random selection of problems from a set

A simplest set may be created by giving to the `@problemset` macro a list of questions
as a multiline string:
```julia
question_set = questions"The first question.
The second question.
...
The tenth question."
```

This creates a workspace vector named `question_set` that contains ten functions
`question_set_1()`, `question_set_2()`, … `question_set_10()`. Suppose you wish
an individual assignment to contain one question from the first half of the vector
and two questions from the second half. That may be accomplished as follows:
```julia
variants = ["A", "B", "C", "D"];
rng_seed = 123;
subsets =  question_set[1=>1:5, 2=>6:10]
txt, =  problemset_latex(variants, rng_seed, subsets);
write("questions.tex", latex_preamble()*txt);
```



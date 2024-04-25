# MakeProblemSet

The goal of this project is to facilitate the creation of problem assignments
for a group of students. A problem set consists of several problem templates with
text and placeholder variables. Percentage signs before and after mark the
placeholder variables within the template text. Function `problemset_latex()`
then generates the latex source of the assignment and solutions for a vector of students'
names.  In the latex source assigned values replace the placeholder variables.
Every placeholder variable must appear at least once as the left-hand of
an assignment where the tilde replaces the equality sign.

This is an example set:
```julia
@problemset my_set begin
@problem pool begin
    pool_size_liters ~ rand(1000:10:2000)
    inflow_liters_sec ~ rand(10:20)
    outflow_max = inflow_liters_sec ÷ 2
    outflow_liters_sec ~ rand(1:outflow_max)
    @solution begin
         fill_rate = inflow_liters_sec - outflow_liters_sec
         time_to_fill = pool_size_liters / fill_rate
         time_to_fill_min ~ round(time_to_fill / 60, digits=3)
         leaked_liters ~ round(time_to_fill*outflow_liters_sec, digits=3)
     end
     @text """
     An empty pool can hold %pool_size_liters% liters of water. Pipe
     fills it at the rate %inflow_liters_sec%~liters/sec while another
     drains it at the rate %outflow_liters_sec%~liters/sec. How many minutes
     will it take to fill the pool and how many liters of water will
     drain out by the time the pool is full?
     """
     @text_solution """
     It will take %time_to_fill_min% minutes to fill the pool and
     %leaked_liters%~liters of water will drain out.
     """
end
@problem addition begin
    x ~ rand(1:3)
    y ~ rand(2:5)
    @solution xy ~ x + y
    @text raw""" Find the sum \(c = a + b\) of two values: \(a = %x%\) and
    \(b = %y%\)
    """
    @text_solution raw"""
      Sum is equal to \(c = %xy%\)
    """
end
@problem subtraction begin
    z ~ rand(7:9)
    w ~ rand(1:5)
    @solution zw ~ z - w
    @text raw""" Find the difference \(c = a - b\) of two values: \(a = %z%\) and
    \(b = %w%\)
    """
    @text_solution raw"""
      Difference is equal to  \(c = %zw%\)
    """
end
end
```
After exection of this macro, there's a vector in workspace named `my_set` 
that contains three functions `my_set_pool()`, `my_set_addition()` and
`my_set_subtraction()`. Text-generating function makes use of their
[methods](Generated_methods.md). This is how an assignment may be produced:
```julia
student_names = ["A", "B", "C"];
rng_seed = 123;
txt,txt_sol =  problemset_latex(student_names, my_set, 2=>1:3, rng_seed);
write("problems.tex", latex_preamble*txt);
write("solutions.tex", latex_preamble*txt);
```

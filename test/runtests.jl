using ProblemSet
using Test

function cleanup_string(str::AbstractString)
    str = sub_add(Val(:text))
    str = replace(str, '\n'=>' ')
    str = replace(str, r" +"=>' ')
    str = strip(str)

    return str
end

cond_1 = [raw"Find the difference \(c= a - b\) and sum  \(d= a + b\) of two values: \(a = ",
        raw"\) and \(b = ", raw"\)"]
sol_1 = [raw"Difference is equal to  \(c = ", raw"\), sum is equal to  \(c = ", raw"\)"]

problem_1 = :(@problem sub_add begin
                  z ~ rand(7:9)
                  w ~ rand(1:5)
                  @solution begin
                      zw_sub ~ z - w
                      zw_add ~ z + w
                  end
                  @text $(cond_1[1])*"%z%"*$(cond_1[2])*"%w%"*$(cond_1[3])
                  @text_solution $(sol_1[1])*"%zw_sub%"*$(sol_1[2])*"%zw_add%"*$(sol_1[3])
              end)

cond_2 = [raw"Find the difference \(c = a - b\) of two values: \(a = ",
         raw"\) and \(b = ", raw"\)"]
sol_2 = [raw"Difference is equal to  \(c = ", raw"\)"]
problem_2 = :(@problem sub begin
                  z ~ rand(7:9)
                  w ~ rand(1:5)
                  @solution begin
                      zw_sub ~ z - w
                  end
                  @text $(cond_2[1])*"%zz%"*$(cond_2[2])*"%w%"*$(cond_2[3])
                  @text_solution $(sol_2[1])*"%zw_sub%"*$(sol_2[2])
              end)

problem_3 = :(@problem add begin
                  z ~ rand(7:9)
                  w ~ rand(1:5)
                  @solution begin
                      zw_add ~ z + w
                  end
                  @text raw"""
Find the sum \(c = a + b\) of two values: \(a = %z%\) and \(b = %w%\)
        """
                  @text_solution raw"""
             Sum is equal to  \(c = %zww_add%\)
        """
              end)

problem_4 = :(@problem dupl begin
                  x ~ 1
                  y ~ 2
                  x ~ 3
                  @solution begin z ~ 1; end
              end)

problem_5 = :(@problem pr_index begin
                  x ~ ["aa", "bb", "cc"]
                  @solution begin z ~ ["dd", "ee", 66]; end
                  @text raw"""input array: [%x[1]%, %x[2]%, %x[3]%]"""
                  @text_solution raw"""output array: [%z[1]%, %z[2]%, %z[3]%]"""
              end)

problem_set = :(@problemset test_problem_set begin
                    $problem_1
                    $problem_2
                    $problem_3                       
                end)

@testset "Single problem" begin
    pr = macroexpand( @__MODULE__, problem_1);
    eval(pr)
    Base.remove_linenums!(pr)
    @test length(pr.args) == 5
    @test pr.args[1] == Base.remove_linenums!(:(function sub_add(; )
                                                    z = rand(7:9)
                                                    w = rand(1:5)
                                                    (zw_sub, zw_add) = sub_add(z, w)
                                                    return (z, w, zw_sub, zw_add)
                                                end)
                                              )

    @test pr.args[3] ==  Base.remove_linenums!(:(function sub_add(z, w; )
                                                     begin
                                                         zw_sub = z - w
                                                         zw_add = z + w
                                                     end
                                                     return (zw_sub, zw_add)
                                                 end)
                                               )
    #
    data_1 = sub_add()
    @test all(sub_add(data_1[1:2]...) .== data_1[3:end])
    #
    @test sub_add(Val(:vars)) == [:z, :w, :zw_sub, :zw_add]
    #
    @test  sub_add(Val(:text)).strings == cond_1
    @test sub_add(Val(:solution_text)).strings == sol_1
    #
    @test_logs (:warn, r" zz | zww_add ") macroexpand( @__MODULE__, problem_2)
    @test_logs (:warn, r" zww_add ") macroexpand( @__MODULE__, problem_3);
    @test_logs (:warn, r"duplicate") macroexpand( @__MODULE__, problem_4);
end

@testset "Problem set" begin
    pr_set = macroexpand( @__MODULE__, problem_set, recursive=:false);
    Base.remove_linenums!(pr_set)
    @test length(pr_set.args) == 2
    @test pr_set.args[2] == :(test_problem_set = Function[
        test_problem_set_sub_add,
        test_problem_set_sub,
        test_problem_set_add])
end

@testset "Problem selection" begin
    @test_throws ArgumentError  ProblemSet.select_problems(5,[1=>1:7])
    idx = ProblemSet.select_problems(15,[1=>1:5, 2=>6:10, 3=>11:15])
    @test count(1 .<= idx .<= 5) == 1
    @test count(6 .<= idx .<= 10) == 2
    @test count(11 .<= idx .<= 15) == 3
end


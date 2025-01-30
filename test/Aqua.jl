using Aqua

@testset "Aqua.jl" begin
  Aqua.test_all(
    ProblemSet;
    deps_compat=(ignore=[:Random],),
  )
end

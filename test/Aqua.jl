using Aqua

@testset "Aqua.jl" begin
  Aqua.test_all(
    ProblemSets;
    deps_compat=(ignore=[:Random],),
  )
end

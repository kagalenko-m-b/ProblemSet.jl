using MakeProblemSet
using Test

ex_body = :(begin
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
                 leak out by the time the pool is full?
                     """
                @text_solution """
                It will take %time_to_fill_min% minutes to fill the pool and
                %leaked_liters%~liters of water will leak out.
                """
            end)

ex_set =:(begin
              @problem p1 begin
                  pool_size_liters ~ rand(1000:10:2000)
                  inflow_liters_sec ~ rand(20:30)
                  outflow_max = inflow_liters_sec÷2
                  outflow_liters_sec ~ rand(5:outflow_max)
                  @solution time_to_fill_min ~ pool_size_liters/(inflow_liters_sec-outflow_liters_sec)/60
              end
              @problem p2 begin
                  x ~ rand(1:3)
                  y ~ rand(2:5)
                  @solution xy ~ x + y
              end
          end)




@testset "MakeProblemSet.jl" begin
    # Write your tests here.
end

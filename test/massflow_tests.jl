# test mass flow functions


# define input masses for each source
M_in = Dict("A" => Dict("phosphor" => 600,
                        "nitrogen" => 400,
                        "water" => 260,
                        "totalsolids" => 90),
            "B" => Dict("phosphor" => 60,
                        "nitrogen" => 40,
                        "water" => 26,
                        "totalsolids" => 9))


# test mass balances
for sys in allSys
    m_outs = massflow(sys, M_in)
    @test isapprox(entered(M_in, sys) - recovered(m_outs) - sum(lost(m_outs), dims=2),
                   [0.0, 0.0, 0.0, 0.0],
                   atol=1e-12)

    m_outs = massflow(sys, M_in, MC=true)
    @test isapprox(entered(M_in, sys) - recovered(m_outs) - sum(lost(m_outs), dims=2),
                   [0.0, 0.0, 0.0, 0.0], atol=1e-12)

    m_outs = massflow(sys, M_in, MC=true, scale_reliability=100)
    @test isapprox(entered(M_in, sys) - recovered(m_outs) - sum(lost(m_outs), dims=2),
                   [0.0, 0.0, 0.0, 0.0], atol=1e-12)

    # summary function
    m1 = massflow_summary(sys, M_in,
                          MC=true, n=10)
    @test length(m1) == 5
end




# test scaling

@test_throws ErrorException scale_massflows(allSys[1], 100) # massflow summary is not yet computed
massflow_summary!.(allSys, Ref(M_in), n=10);

allSys2 = scale_massflows.(allSys, 100) # copy
for i in 1:length(allSys)
    for (k, v) in allSys2[i].properties["massflow_stats"]
        @test  all(v .≈ (allSys[i].properties["massflow_stats"][k] .* 100))
    end
end

# test that the RGN is not accidentally resetted
r1 = allSys[1].properties["massflow_stats"]["lost"][3,1,1]
massflow_summary!(allSys[1], M_in, n=10)
r2 = allSys[1].properties["massflow_stats"]["lost"][3,1, 1]
@test r1 != r2


scale_massflows!.(allSys, 0)    # inplace
for i in 1:length(allSys)
    for (k, v) in allSys[i].properties["massflow_stats"]
        @test all(v .≈ 0.0)
    end
end

# parallel calculations

massflow_summary_parallel!(allSys, M_in, n=10);

for s in allSys
    @test length(s.properties["massflow_stats"]) == 5
end
@test length(unique([hash(s.properties["massflow_stats"]) for s in allSys])) == length(allSys)

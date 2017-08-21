using SimJulia, Base.Test, PFlow, Distributions

function scheduling(sim::Simulation, log::Simlog, wu::Workunit, delay::Number=0, n::Int64=100)
  sched = Logvar("schedule", "")
  logvar2log(log, sched)
  for i ∈ 1:n
    if delay > 0
      yield(Timeout(sim, rand(Exponential(delay))))
    end
    item = 123000+i
    job = Job(item, "Job"*string(i), [wu.name], randn()+5, 0.0, 0.0, OPEN, 1, "")
    pro = Product(123, item, "test", "testproduct", "testorder", [job], 1, OPEN)
    enqueue!(wu.input, pro)
    sched.value = pro.item
    lognow(sim, log)
  end
  sched.value = ""
end

function delivering(sim::Simulation, log::Simlog, wu::Workunit, delay::Number=0)
  done = Logvar("done", "")
  logvar2log(log, done)
  while true
    if delay > 0
      yield(Timeout(sim, rand(Exponential(delay))))
    end
    pro = dequeue!(wu.output)
    done.value = pro.item
    lognow(sim, log)
  end
end

srand(1234)  # seed random number generator for reproducibility
sim = Simulation()
ml = newlog()
jl = newlog()
mm = machine(sim, ml, "test", input=10)
@process scheduling(sim, jl, mm, 0., 10) # without delay
@process delivering(sim, jl, mm, 0.)      # without delay
run(sim, 200)
ml = log2df(ml)
jl = log2df(jl)

@test length(ml[:test]) == 40
@test length(jl[:done]) == 20
@test length(jl[jl[:done] .!= "", :done]) == 10 # ten products were finished
@test length(ml[ml[:test] .== 1, :test]) == 20 # twenty times the machine changed status
@test round(ml[:time][40], 4) == 43.4712
@test round(jl[:time][20], 4) == 43.4712

println("1st test passed")

srand(2345)  # seed random number generator for reproducibility
sim = Simulation()
ml = newlog()
jl = newlog()
mm = machine(sim, ml, "test", input=2) # smaller input buffer
@process scheduling(sim, jl, mm, 10, 10) # starve input
@process delivering(sim, jl, mm, 0)      # without delay
@process lognow(sim, ml)
run(sim, 200)
ml = log2df(ml)
jl = log2df(jl)

@test length(ml[:test]) == 41
@test length(jl[:done]) == 20
@test length(Set(jl[:done])) == 11 # all ten products were finished
@test length(ml[ml[:test] .== 1, :test])/2 == 10 # ten times the machine got working
@test round(ml[:time][40], 4) == 181.2260
@test round(jl[:time][20], 4) == 181.2260

println("2nd test passed")

srand(3456)  # seed random number generator for reproducibility
sim = Simulation()
ml = newlog()
jl = newlog()
mm = machine(sim, ml, "test", input=2) # smaller input buffer
@process scheduling(sim, jl, mm, 8, 10) # starve input
@process delivering(sim, jl, mm, 12)      # starve output
@process lognow(sim, ml)
run(sim, 200)
ml = log2df(ml)
jl = log2df(jl)

@test length(ml[:test]) == 45
@test length(jl[:done]) == 20
@test length(Set(jl[:done])) == 11 # all ten products were finished
@test length(ml[ml[:test] .== 1, :test])/2 == 10 # ten times the machine got working
@test length(ml[:test][ml[:test] .== 3])/2 == 2  # two times the machine was blocked
@test round(ml[:time][45], 4) == 94.8730        # now the machine finished
@test round(jl[:time][20], 4) == 94.8730        # now the last product was delivered

println("3rd test passed")

srand(3456)  # seed random number generator for reproducibility
sim = Simulation()
ml = newlog()
jl = newlog()
mm = machine(sim, ml, "test", input=2, mtbf=25, mttr=5) # with failures
@process scheduling(sim, jl, mm, 8, 10) # starve input
@process delivering(sim, jl, mm, 10)      # starve output
@process lognow(sim, ml)
run(sim, 200)
ml = log2df(ml)
jl = log2df(jl)

@test length(ml[:test]) == 75
@test length(jl[:done]) == 20
@test length(Set(jl[:done])) == 11 # all ten products were finished
@test length(ml[ml[:test] .== 2, :test])/2 == 9 # nine times the machine failed
@test length(ml[ml[:test] .== 1, :test])/2 == 12 # twelve times the machine got working
@test length(ml[:test][ml[:test] .== 3])/2 == 1  # one times the machine was blocked
@test round(ml[:time][75], 4) == 198.8735        # now the machine finished
@test round(jl[:time][20], 4) == 92.9175        # now the last product was delivered

println("4th test passed")


println("Tests finished")

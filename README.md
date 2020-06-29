# Santiago.jl


A Julia package to generate approperiate sanitation system options. It is able to
- assess the approperiateness of a technology in a given context;
- find all possible systems given a set of sanitation technologies;
- calculate (optionally stochastic) the mass flows for each system for
  total `phosphor`, total `nitrogen`, `totalsolids`, and `water`;
- select a desired number of diverse but appropriate systems.


# Installation

1. Install [Julia](https://julialang.org/) version >= 1.4.

2. Install the `Santiago` package from the Julia prompt:
```Julia
] add https://github.com/santiago-sanitation-systems/Santiago.jl.git
```

# Usage

Some functions of `Santiago` are parallelized. To use
this feature you need to start Julia with multiple threads.


## Minimal Example

```Julia
using Santiago
using Logging

# -----------
# 0) define log level

global_logger(ConsoleLogger(stderr, Logging.Warn))

# -----------
# 1) Import technologies

# we use the test data that come with the package
input_tech_file = joinpath(pkgdir(Santiago), "test/example_techs.json")
input_case_file = joinpath(pkgdir(Santiago), "test/example_case.json")

sources, additional_sources, techs = import_technologies(input_tech_file, input_case_file)

# number of available technologies
# (more than in "example_techs.json" as some are auto generated)
length(techs)


# -----------
# 2) Build all systems

allSys = build_systems(sources, techs);

# number of found systems
length(allSys)


# -----------
# 3) Calculate (or update) system properties

sysappscore!.(allSys)
connectivity!.(allSys)
ntechs!.(allSys)
template!.(allSys)

# see all properties of the first system
allSys[1].properties


# -----------
# 4) Mass flows

input_masses = Dict("Dry.toilet" => Dict("phosphor" => 548.0,
                                         "nitrogen" => 4550.0,
                                         "water" => 22447113.5,
                                         "totalsolids" => 32120.0),
                    "Pour.flush" => Dict("phosphor" => 548.0,
                                         "nitrogen" => 4550.0,
                                         "water" => 1277113.465,
                                         "totalsolids" => 32120.0)
                    )

# calculate mass flows for all systems and save to system properties
massflow_summary!.(allSys, Ref(input_masses), n=20)

# Examples how to extract results
allSys[2].properties["massflow_stats"]["entered"]
allSys[2].properties["massflow_stats"]["recovery_ratio"]
allSys[2].properties["massflow_stats"]["recovered"]

allSys[2].properties["massflow_stats"]["lost"][:,"air loss",:]
allSys[2].properties["massflow_stats"]["lost"][:,:,"mean"]
allSys[2].properties["massflow_stats"]["lost"][:,:,"q_0.5"]

# -----------
# 5) select a subset of systems

# For example, select eight systems for further investigation
selectedSys = select_systems(allSys, 8)

# -----------
# 6) write some properties in a DataFrame for further analysis

df = properties_dataframe(selectedSys,
                          massflow_selection = ["recovered | water | mean",
                                                "recovered | water | sd",
                                                "lost | water | air loss| q_0.5",
                                                "entered | water"])


# -----------
# 8) export to JSON

# Note, the JSON export is designed to interface other applications,
# but not for serialization.

open("tech_export.json", "w") do f
    JSON3.write(f, techs)
end

open("system_export.json", "w") do f
    JSON3.write(f, selectedSys)
end

```

## Logging

By default, `Santiago` is rather talkative. This can be
adapted by the logging level. With the package `LoggingExtras.jl` (needs to
be installed extra)
different logging levels can be used for the console output and the log file:

```Julia
using Logging
using LoggingExtras

# - on console show only warings and errors, write everything in the logfile 'info.log'
mylogger = TeeLogger(
    MinLevelLogger(FileLogger("info.log"), Logging.Debug),  # logs to file
    MinLevelLogger(ConsoleLogger(), Logging.Warn)           # logs to console
)
global_logger(mylogger)

... use Santiago functions ...
```

## Update calculated systems with new case profile

The generation of all systems is computationally intense. The code
below demonstrates how to first generate all systems without case
information and later update the system scores with case data.

```Julia
## 1) build systems without case information

sources, additional_sources, techs = import_technologies(tech_file)
allSys = build_systems(sources, techs)

## 2) read case file and update sysappscore

tas, tas_components = appropriateness(tech_file, case_file);
update_appropriateness!(sources, tas)
update_appropriateness!(additional_sources, tas)
update_appropriateness!(techs, tas)

sysappscore!.(allSys)

## 3) select systems

fewSys = select_systems(allSys, 6)

```
Only the first step is slow, you may want to cache the result. Step 2 ad 3 can be iterated quickly.


## References

Spuhler, D., Scheidegger, A., Maurer, M., 2018. Generation of sanitation system options for urban planning considering novel technologies. Water Research 145, 259–278. https://doi.org/10.1016/j.watres.2018.08.021

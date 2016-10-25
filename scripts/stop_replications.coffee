Benchmark = require './benchmark'

Bench = new Benchmark()

Bench.stopReplications (err) ->
    return console.error err if err?
    console.log 'Replications stopped'

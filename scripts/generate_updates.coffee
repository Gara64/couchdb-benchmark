async = require 'async'
Benchmark = require './benchmark'


###
Generate updates in the db
interval -> interval of times between 2 updates, in ms
isDocShared -> [optionnal, default is true] update a doc in the shared db
duration -> [optionnal, default is -1] how long the script must be run
###

# Check input paramaters
if process.argv.length < 3 or process.argv.length > 5
    console.log 'Usage : coffee generate_updates.coffee interval [isDocShared] [duration]'
    return

interval = parseInt(process.argv[2])
isDocShared = process.argv[3] or 'true'
isDocShared = (isDocShared is 'true')
duration = parseInt(process.argv[4])

Bench = new Benchmark()

updateDoc = (callback) ->
    setTimeout () ->
        Bench.updateDoc isDocShared, (err) ->
            callback err
    , interval

if duration
    console.log 'coucou'
else
    async.forever (cb) ->
        updateDoc (err) ->
            cb err
    , (err) ->
        if err?
            console.error err
            process.exit()
        else
            console.log 'oki'

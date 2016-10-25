async = require 'async'
Benchmark = require './benchmark'


###
Generate inserts in the db
nDocs -> number of docs to insert
###

# Check input paramaters
if process.argv.length isnt 3
    console.log 'Usage : coffee generate_inserts.coffee nDocs'
    return

nDocs = parseInt(process.argv[2])

Bench = new Benchmark()

Bench.insertDocs nDocs, (err) ->
    return console.error err if err?

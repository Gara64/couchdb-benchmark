Benchmark = require './benchmark'
async = require 'async'

### 
This script intitializes the db, insert documents, and create couchdb
containers if needed
Parameters :
nDbs -> number of databases to create
nDocs -> number of docs to insert
port -> [default=5985] couchdb port
###


# Check input paramaters
if process.argv.length < 4 or process.argv.length > 5
    console.log 'Usage : coffee init_db.coffee nDbs nDocs [port=5985]'
    return

nDbs = parseInt(process.argv[2])
nDocs = parseInt(process.argv[3])
nRecipients = parseInt(process.argv[4])

Bench = new Benchmark()


async.series [
    (cb) ->
        Bench.initDbs nDbs, (err) ->
            console.log 'done'
            cb err
    ,
    (cb) ->
        Bench.insertDocs nDocs, (err) ->
            cb err
    ,
    (cb) ->
        if nRecipient?
            Bench.initRecipients nRecipients, (err) ->
                cb err
        else
            cb null
], (err, res) ->
    console.error  err if err?
    console.log 'done'

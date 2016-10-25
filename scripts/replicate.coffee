Benchmark = require './benchmark'
async = require 'async'



### 
This script creates replication process and monitor the RAM consumption
Parameters :
nDocs -> number of docs to replicate per replication process
nRecipient -> number of recipient, i.e. of replication process
byIds -> [default is true] replicate by doc ids or mango selecctor
continuous -> [Default is true] if the replication is continuous or not
###


# Check input paramaters
if process.argv.length < 4 or process.argv.length > 6
    console.log 'Usage : coffee replicate.coffee nDocs nRecipients [continuous=true]'
    console.log 'Usage : coffee replicate.coffee -s nRecipients '

    return

param = process.argv[2]
byIds = param isnt '-s'

nDocs = parseInt(process.argv[2]) if byIds

nRecipients = parseInt(process.argv[3])
continuous = process.argv[5] or 'true'
continuous = (continuous is 'true')


Bench = new Benchmark()

selector:
    docType: "benchmark"

replicate =
    nDocs: nDocs
    nRecipients: nRecipients
    continuous: continuous
    byIds: byIds
    selector: selector


Bench.replicateToRecipients replicate, (err) ->
    console.error err if err?

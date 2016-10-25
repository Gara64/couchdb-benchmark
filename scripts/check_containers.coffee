containerCouch = require './docker_couchdb'
Docker = require 'dockerode'
docker = new Docker()
Benchmark = require './benchmark'
async = require 'async'


# Create docker containers of couchdb

DOCKER_IMAGE_NAME = "klaemo/couchdb"

containerCouch.getRunningContainers (err, containers) ->
    return console.error err if err?

    console.log containers.length + ' containers running'
    cptInit = 0
    async.each containers, (container, cb) ->

        Bench = new Benchmark('http://localhost', container.port)
        Bench.systemDbsStatus (err, dbStatus) ->
            return cb err if err?

            isAllInit = true
            dbStatus.forEach (dbStatus) ->
                if not dbStatus.status
                    isAllInit = false
                    console.log dbStatus.db + ' does not exist for port ' + container.port

            if isAllInit
                console.log container.port  + ' is all init'
                cptInit++
            cb()

    , (err) ->
        console.log cptInit + ' containers correctly init'

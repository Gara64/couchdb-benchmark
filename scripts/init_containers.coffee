containerCouch = require './docker_couchdb'
Docker = require 'dockerode'
docker = new Docker()
Benchmark = require './benchmark'
async = require 'async'


# Create docker containers of couchdb

DOCKER_IMAGE_NAME = "klaemo/couchdb"

containerCouch.getRunningContainers (err, containers) ->
    return console.error err if err?

    async.each containers, (container, cb) ->

        Bench = new Benchmark('http://localhost', container.port)
        Bench.createSystemDbs (err) ->
            return console.error err if err?
            console.log 'init ok for ' + container.port

containerCouch = require './docker_couchdb'
Docker = require 'dockerode'
docker = new Docker()
Benchmark = require './benchmark'


# Create docker containers of couchdb

DOCKER_IMAGE_NAME = "klaemo/couchdb"

# Check input paramaters
if process.argv.length isnt 3
    console.log 'Usage : coffee create_couch_containers.coffee nContainers'
    return

showErrors = (errors, callback) ->
    if Object.keys(errors).length > 0
        console.error 'Error on containers'
        console.log JSON.stringify errors
    callback()

nContainers = parseInt(process.argv[2])
contIndex = containerCouch.getHighestContainerIndex (err, index) ->
    if err
        console.error err
        process.exit()
    else
        containerCouch.createDockerContainers nContainers, index, (err) ->
            console.error err if err?

            ###
            containerCouch.getRunningContainers (err, containers) ->
                # Wait for couchdb to boot
                setTimeout () ->
                    containers.forEach (container) ->
                        Bench = new Benchmark('http://localhost', container.port)

                        Bench.createSystemDbs (err) ->
                            if err
                                console.error err
                            else
                                console.log 'system dbs created for ' + container.port
                , 10000
            ###

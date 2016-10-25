Docker = require 'dockerode'
docker = new Docker()
async = require 'async'

DOCKER_IMAGE_NAME = "klaemo/couchdb"

# Get the exposed port for a docker container
getContainerPort = (containerInfo, callback) ->
    containerInfo.Ports.forEach (port) ->
        if port?
            callback null, port.PublicPort
        else callback null

createContainer = (startIndex, i, callback) ->
    # The ExposedPort and PortBinding params are necessary to publish
    # the 5984 port and access it fro the host
    # See https://docs.docker.com/engine/reference/api/docker_remote_api_v1.24/
    params =
        Image: DOCKER_IMAGE_NAME
        name: 'couchdb' + (startIndex + 1 + i)
        ExposedPorts: {"5984/tcp": {}}
        PortBindings: {"5984/tcp": [{ "HostPort": "" }] }
        #PublishAllPorts: true

    docker.createContainer params, (err, container) ->
        return callback err if err?

        container.start (err, data) ->
            return callback err if err?

            console.log 'container ' + (startIndex + 1 + i) + ' created and started'
            callback()

module.exports =

    # Returns the highest index name in couchdb containers
    # All containers contains the name "couchdb" and an index number to avoid
    # conflits. This function returns the highest value
    getHighestContainerIndex: (callback) ->
        highest = 0

        docker.listContainers {all: true}, (err, containerList) ->
            return callback err if err?

            containerList.forEach (containerInfo) ->
                name = containerInfo.Names[0].substring(1)
                if name.indexOf 'couchdb' > -1
                    index = parseInt(name.split('couchdb')[1])
                    if index > highest then highest = index

            callback null, highest

    # Returns the running containers with their name and port
    getRunningContainers: (callback) ->
        docker.listContainers (err, containerList) ->
            return callback err if err?
            containers = []

            containerList.forEach (containerInfo) ->
                container = {name: containerInfo.Names[0].substring(1)}

                if container.name.indexOf 'couchdb' > -1
                    getContainerPort containerInfo, (err, port) ->
                        if port?
                            container.port = port
                            containers.push container
            callback null, containers

    # Create docker containers of couchdb.
    createDockerContainers: (nRecipient, index, callback) ->
        async.times nRecipient, (i, cb) ->
            createContainer index, i, (err) ->
                cb err
        , (err) ->
            callback err

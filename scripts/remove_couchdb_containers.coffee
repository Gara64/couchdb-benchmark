Docker = require 'dockerode'
docker = new Docker()

# Remove all docker containers of couchdb

DOCKER_IMAGE_NAME = "klaemo/couchdb"

# Check input paramaters
if process.argv.length isnt 2
    console.log 'Usage : coffee remove_couch_containers.coffee'
    return

docker.listContainers {all: true}, (err, containerList) ->
    if err
        console.error err
        process.exit()
    else
        containerList.forEach (containerInfo) ->
            # Filter the containers to only keep couchdb
            if containerInfo.Names[0].substring(1).indexOf 'couchdb' > -1
                options =
                    force: true
                    v: true
                docker.getContainer(containerInfo.Id).remove options, (err) ->
                    if err
                        console.error err
                        process.exit()
                    else
                        console.log 'container removed'

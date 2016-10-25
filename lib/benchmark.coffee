cradle = require 'cradle'
async = require 'async'
containerCouch = require './docker_couchdb'

COUCH_URL = "http://localhost"
COUCH_PORT = "5985"
RECIPIENT_BASE_URL = "http://localhost"

DB_BASE_NAME = 'db_'
DB_SHARING = DB_BASE_NAME + 'sharing'
SYSTEM_DBS = [ '_global_changes', '_metadata', '_replicator', '_users', DB_SHARING ]

DEFAULT_DOC =
    docType: "benchmark"
    foo: "bar"


class Benchmark

    recipients = []
    conn = null

    # Initialize the connection with the host couchDB
    constructor: (couchUrl, couchPort) ->
        if couchUrl and couchPort
            COUCH_URL = couchUrl
            COUCH_PORT = couchPort
        console.log 'Create connection for port ' + COUCH_PORT
        conn = new cradle.Connection(COUCH_URL, COUCH_PORT)


    # Initialization of the databases :
    # remove all the current db and create the user ones
    initDbs: (nDb, callback) ->
        destroyAllDbs (err) ->
            return callback err if err?

            createAllDbs nDb, (err) ->
                callback err


    # Insert nDocs in each user db + the sharing db
    insertDocs: (nDocs, callback) ->

        getUserDatabases (err, dbs) ->
            return callback err if err?

            dbs.push DB_SHARING
            #nDocsPerDb = Math.floor(nDocs / dbs.length)

            async.each dbs, (dbName, cb) ->
                # Generate the docs for the db and insert
                docs = (DEFAULT_DOC for i in [0...nDocs])
                insertGeneratedDocs docs, dbName, (err) ->
                    console.log nDocs + ' docs inserted in db ' + dbName
                    cb err
            , (err) ->
                callback err


    # Update a doc in the sharing db or a user db
    updateDoc: (sharedDoc, callback) ->
        console.log 'is shared doc : ' + sharedDoc

        if sharedDoc
            db = conn.database DB_SHARING
        else
            db = conn.database DB_BASE_NAME + '0'

        # Update the first doc of the db
        requestDocs db, 1, true, (err, docs) ->
            if err?
                callback err
            else if docs.length is 0
                callback 'Error : no document found in database'
            else
                doc = docs[0].doc
                doc.foo = 'bar' + Math.random()
                db.save doc._id, doc, (err) ->
                    if err?
                        callback err
                    else
                        console.log 'doc updated'
                        callback()


    # Stop all the running replications
    stopReplications: (callback) ->
        db = conn.database DB_SHARING

        conn.activeTasks (err, tasks) ->
            tasks.forEach (task) ->
                options =
                    replication_id: task.replication_id
                    cancel: true
                conn.replicate  options, (err, res) ->
                    return callback err if err?

            removeReplicationDocs (err) ->
                callback err


    # Give the status (exist or not) of all the system databases
    systemDbsStatus: (callback) ->
        exists = (dbName, callback) ->
            db = conn.database dbName
            db.exists (err, exists) ->
                status =
                    db: dbName
                    status: exists
                callback err, status

        async.map SYSTEM_DBS, exists, (err, results) ->
            callback err, results


    # Create the system databases
    createSystemDbs: (callback) ->
        createSystemDbs (err) ->
            callback err



    # Remove all the db
    destroyAllDbs = (callback) ->
        console.log 'destruction of db...'

        getAllDatabases (err, dbs) ->
            return callback err if err?

            async.each dbs, (dbName, cb) ->
                destroyDb dbName, (err) ->
                    cb err
            , (err) ->
                callback err


    # Remove a single db
    destroyDb = (dbName, callback) ->
        db = conn.database dbName
        db.destroy (err) ->
            if err
                callback err
            else
                console.log dbName + ' destroyed'
                callback()


    # Create user and system dbs
    createAllDbs = (nDb, callback) ->
        createUserDbs nDb, (err) ->
            return callback err if err?

            createSystemDbs (err) ->
                callback err


    # Create new user dbs
    createUserDbs = (nDb, callback) ->
        console.log 'creation of ' + nDb + ' db...'
        async.times nDb, (i, cb) ->
            createDb DB_BASE_NAME + i, (err) ->
                cb err
        , (err) ->
            callback err


    # Create the system databases
    createSystemDbs = (callback) ->
        async.each SYSTEM_DBS, (db, cb) ->
            createDb db, (err) ->
                cb err
        , (err) ->
            callback err


    # Create a single db
    createDb = (dbName, callback) ->
        db = conn.database dbName
        db.exists (err, exists) ->
            return callback err if err

            if exists
                console.log dbName + ' already exists'
                callback()
            else
                db.create (err) ->
                    callback err


    # Insert the given docs in the specified db
    insertGeneratedDocs = (docs, dbName, callback) ->
        # Used to compute execution time
        console.time "insertion"

        db = conn.database dbName
        # Insert the docs in bulk mode
        db.save docs, (err, res) ->
            if err?
                callback err
            else
                console.timeEnd "insertion"
                callback null


    # Request n benchmark doc ids
    requestDocs = (db, nDocs, includeDocs, callback) ->
        if not includeDocs
            db.all limit: nDocs, (err, res) ->
                return callback err if err?

                ids = (row.id for row in res)
                callback null, ids
        else
            db.all limit: nDocs, include_docs: true, (err, res) ->
                callback err, res


    # Replicate docs to multiple recipients
    replicateToRecipients: (options, callback) ->
        # Check params
        unless options.nRecipients? and options.continuous? and options.byIds?
            err = new Error "Bad params"
            return callback err

        # Retrieve all the running targets
        containerCouch.getRunningContainers (err, containers) ->
            return callback err if err?

            # Check if there are enough containers to replicate
            if containers?.length < options.nRecipients
                err = new Error 'You asked ' + options.nRecipients + \
                ' replications but only ' + containers.length + \
                ' containers are running'
                callback err
            else
                console.log 'containers : ' + JSON.stringify containers

                for i in [0...options.nRecipients]
                    recipient = containers[i]
                    # Replicate by id or mango filter
                    if options.byIds
                        replicateDocsByIds options.nDocs, recipient, options.continuous, (err) ->
                            return callback err if err?
                    else
                        replicateDocsByMango options.selector, recipient, options.continuous, (err) ->
                            return callback err if err?

                callback()


    # Replicate nDocs specified by their ids, to the recipient
    replicateDocsByIds = (nDocs, recipient, continuous, callback) ->
        db = conn.database DB_SHARING

        # Get n doc ids
        requestDocs db, nDocs, false, (err, ids) ->
            if err? or not ids?
                callback err
            else if ids.length is not parseInt(nDocs, 10)
                msg = 'Error : cannot replicate ' + nDocs +  ' : '
                msg += 'only ' + ids.length + ' found'
                err = new Error msg
                callback err

            else
                source = "#{COUCH_URL}:#{COUCH_PORT}/#{DB_SHARING}"
                target = "#{RECIPIENT_BASE_URL}:#{recipient.port}/#{DB_SHARING}"

                replication =
                    source: source
                    doc_ids: ids
                    continuous: continuous
                    target: target
                    create_target: true
                    checkpoint_interval: 300000

                #console.log 'replication : ' + JSON.stringify replication


                replicate replication, (err, body) ->
                    callback err, body


    # Replicate docs specified by a selector query, to the recipient
    replicateDocsByMango = (selector, recipient, continuous, callback) ->

        options =
            source: "#{COUCH_URL}:#{COUCH_PORT}/#{DB_SHARING}"
            target: "#{RECIPIENT_BASE_URL}:#{recipient.port}/#{DB_SHARING}"
            continuous: continuous
            selector: selector
            create_target: true

        console.log 'replication : ' + JSON.stringify options

        replicate options, (err, body) ->
            callback err, body


    # Actual replication from source to target
    replicate = (options, callback) ->
        # Used to compute execution time
        console.time "replication"

        replicator = conn.database '_replicator'
        replicator.save options, (err, body) ->
            if err? then callback err
            else if not body.ok
                err = "Replication failed"
                callback err
            else
                console.log 'body : ' + JSON.stringify body
                console.timeEnd "replication"
                callback()


    # Remove all the docs in _replicator, except for the design ones
    removeReplicationDocs = (callback) ->
        db = conn.database '_replicator'

        db.all (err, res) ->
            return callback err if err?

            nDocs = 0
            async.each res, (doc, cb) ->
                if doc.id?.indexOf('design') < 0
                    db.remove doc.id, (err, res) ->
                        return cb err if err?
                        nDocs++
                        cb null
                else
                    cb()
            , (err) ->
                if err
                    callback err
                else
                    console.log nDocs + ' docs removed from _replicator'
                    callback null


    # Returns all the dbs, without the system ones
    getUserDatabases = (callback) ->
        conn.databases (err, dbs) ->
            if err
                callback err
            else
                curDbs = dbs.filter (db) ->
                    if SYSTEM_DBS.indexOf(db) < 0
                        db

                callback null, curDbs


    # Returns all the dbs, including the system ones
    getAllDatabases = (callback) ->
        conn.databases (err, dbs) ->
            callback err, dbs



module.exports = Benchmark

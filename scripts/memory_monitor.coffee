ps = require 'ps-node'
usage = require 'usage'
fs = require 'fs'

DEFAULT_DELAY = 300000

getCurrentDate = (callback) ->
    date = new Date()
    day = date.getDate()
    day = (day < 10 ? "0" : "") + day
    month = date.getMonth() + 1;
    month = (month < 10 ? "0" : "") + month
    hour = date.getHours()
    hour = (hour < 10 ? "0" : "") + hour
    min = date.getMinutes()
    min = (min < 10 ? "0" : "") + min
    sec  = date.getSeconds()
    sec = (sec < 10 ? "0" : "") + sec

    cur_date = "#{hour}:#{min}:#{sec}"
    callback cur_date


getTimestamp = () ->
    ms = new Date().getTime()
    return (ms / 1024)

getCouchProcess = (callback) ->
    couchdb_process = []
    params =
        command: 'beam'
        psargs: 'ux'

    ps.lookup params, (err, results) ->
        results.forEach (process) ->
            if process
                couchdb_process.push process
                #console.log 'PID: %s, COMMAND: %s, ARGUMENTS: %s', process.pid, process.command, process.arguments
        callback null, couchdb_process


getProcessMemoryUsage = (pid, callback) ->
    usage.lookup pid, (err, result) ->
        return callback err if err?
        if result
            res =
                memory: result.memory / 1024 / 1024
                cpu: result.cpu
            callback null, res
        else
            callback null



file = process.argv[2]
pid = parseInt(process.argv[3])
interval = parseInt(process.argv[4])



if not pid
    getCouchProcess (err, processes) ->
        if processes.length > 0
            processes.forEach (process) ->
                getProcessMemoryUsage process.pid, (err, res) ->
                    if res
                        console.log res.memory + ' Mo used by ' + process.pid

        else
            console.log 'no process found'
else
    delay = if interval then interval else DEFAULT_DELAY
    startTime = getTimestamp()
    setInterval () ->
        getProcessMemoryUsage pid, (err, res) ->
            if res?
                console.log res.memory + ' Mo used by ' + pid
                time = Math.floor(getTimestamp() - startTime)
                text = time + " \t\t " + res.memory + " \t\t " + res.cpu + " % cpu \n"
                fs.appendFile file, text, (err) ->
                    return console.error err if err?
    , delay

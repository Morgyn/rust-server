var WebRcon = require('webrconjs') // node.js only
 
// Create a new client:
var rcon = new WebRcon('127.0.0.1', 29016)
 
// Handle events:
rcon.on('connect', function() {
    console.log('CONNECTED')
    
    // Run a command once connected:
    rcon.run('status', 4444)
})
rcon.on('disconnect', function() {
    console.log('DISCONNECTED')
})
rcon.on('message', function(msg) {
    console.log('MESSAGE:', msg)
})
rcon.on('error', function(err) {
    console.log('ERROR:', err)
})
 
// Connect by providing the server's rcon.password:
rcon.connect('U4tMzaKKw')

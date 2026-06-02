var debug = false;
var WebRcon = require('webrconjs') // node.js only
 
// Create a new client:
var rcon = new WebRcon('127.0.0.1', process.env.RUST_RCON_PORT)
 
// Handle events:
rcon.on('connect', function() {
    if (debug) console.log('CONNECTED');
    
    const messageID = Math.floor(Math.random() * 9000) + 1000;

    // Run a command once connected:
    rcon.run('status', messageID)
})
rcon.on('disconnect', function() {
    if (debug) console.log('DISCONNECTED')
})
rcon.on('message', function(msg) {
        if (debug) console.log("MESSAGE:");
        if ( msg["identity"] != messageID )
                return;
        console.log(msg["message"]);
        rcon.disconnect();
        process.exit(0);
        rcon=null;
})
rcon.on('error', function(err) {
    console.log('ERROR:', err)
})
rcon.on('disconnect', function() {
        if (debug) console.log('DISCONNECTED')
        rcon = null
})
 
// Connect by providing the server's rcon.password:
rcon.connect(process.env.RUST_RCON_PASSWORD)
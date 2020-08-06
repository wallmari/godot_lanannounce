# godot_lanannounce
Simple LAN game announcement server/client. It deliberately doesn't try to
do the actual game server - it is assumed that the user already has something
in mind, and is just looking for a way for clients to find game hosts.

Each application using this should use a use a unique name, but multiple copies
of this server can safely be run on the same port on the same network -
commands intended for a different application are ignored.

## Components

The system comes in two parts:

### LANAnnounceServer

This component is responsible for broadcasting the existence of the server to
the network, and receiving requests to join.

#### Usage

    # Open a broadcaster on port 9000 (command channel port 9001) for "MyApp"
    var host = preload("res://addon/LANAnnounceServer.gd")
    var server = host.new("MyApp", 9000)
	server.connect("client_register", self, "client_registered_handler")
	server.connect("client_unknown_command", self, "command_handler")
	server.connect("log_message", self, "server_log_message_handler")
    server.start_announcing()

    # If you just want to stop announcements, but keep command channels open
    server.stop_announcing()

#### Signals

It can emit three signals:

##### client_register(ip_address)

A client has indicated that they want to join. The IP address of the client
is included in the signal, for use with whatever multiplayer engine the game
wishes to use

##### client_unknown_command(ip_address, command, payload)

The client sent a packet, in the right format, but containing a command that
the server doesn't understand. This signal can be used to handle application-specific commands from within the application, without editing the server code

##### log_message(message)

Informational messages from the server. This can safely be ignored if you
don't want to log them

### LANAnnounceClient

This component listens for broadcast announcements from servers, and informs
the application via signals

#### Usage

    # Open a broadcaster listener on port 9000 (command channel 9001) for "MyApp"
    var clientclass = preload("res://addon/LANAnnounceClient.gd")
    var client = clientclass.new("MyApp", 9000)
	client.connect("server_discovered", self, "server_discovered_handler")
	client.connect("server_shutdown", self, "server_shutdown_handler")
	client.connect("server_unknown_command", self, "server_unknown_command_handler")
	client.connect("log_message", self, "client_log_message_handler")

    # Start listening for broadcasts
    client.start_listening()

    # And when you're ready...
    client.stop_listening()

#### Signals

##### server_discovered(ip_address, port)

A server has announced its existence. This signal is emitted on all annoucement packets; it is the job of the application to de-duplicate them, and potentially remove servers if they haven't announced within an acceptable time frame.

##### server_shutdown(ip_address, port)

The server has announced that it has shut down, and is no longer appropriate to send messages to

##### server_unknown_command(ip_address, message, payload)

A command has been received from the given server that this code cannot process - the details are passed in the signal to allow the application to handle it

##### log_message(message)

Informational messages from the client handling code. This can safely be ignored if you don't want to log them

## Packet format

The packet format is quite simple - a newline separated set of at least three
fields:

1. Magic constant "GODOTGAMESERVER"
    Used to detect that the rest of the packet is going to be in a format
    we'll understand

2. Application/instance name
    A network-unique reference to the game host. This should include the app
    name, to allow multiple apps to co-exist on the same network

3. Command
    What type of message this packet contains

4. Payload (optional)
    Messages may contain additional data relevant to the message type.
    Payloads are treated as an opaque data block by this system

## Defined commands

Several messages are defined here, but the server component is able to send
custom messages, and the client will emit a signal containing any message it
doesn't recognise

### ANNOUNCE

Broadcast from the server, this announces the existence of the server to all
listeners. The payload contains the port number required for registration to
the server.

### SHUTDOWN

Broadcast from the server, this lets all listeners know that this server is
no longer accepting new registrations (existing registrations are outside of
the scope of this code - this message may be sent simply when the game host
has reached capacity)

### REGISTER

Sent from a client to a specific server, this is an indication that the client should be added to the host.
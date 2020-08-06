extends Node

# Signal for when a client wishes to REGISTER with the server
signal client_register(ip_address)

# Signal for when we receive a command we don't understand ourselves
# This lets something else handle the command, rather than having to bulk out
# this class with possibly app-specific commands
signal client_unknown_command(ip_address, command, payload)

# Signal to start the announcement broadcasts
signal start_announcing

# Signal to stop the announcement broadcasts
signal stop_announcing

# Signal for passing log messages
signal log_message(message)

# Magic header value, so we can tell packets are ours
const MAGIC_HEADER = "GODOTGAMESERVER"

# How often to send announcements, in seconds
const ANNOUNCE_FREQUENCY = 2.0

# App name to filter packets with/for
var m_app_name setget set_app_name, get_app_name

# UDP port to use for announcements
var m_announce_port setget set_announce_port, get_announce_port

# UDP port to use for game
var m_game_port setget set_game_port, get_game_port

var udp_broadcast : PacketPeerUDP
var udp_receiver : PacketPeerUDP
var broadcast_enabled = false
var ping_countdown = 0

func _init(app_name : String, announce_port : int, game_port : int = 0):
	m_app_name = app_name
	m_announce_port = announce_port
	if game_port == 0:
		m_game_port = announce_port + 1
	else:
		m_game_port = game_port
	udp_broadcast = PacketPeerUDP.new()
	# Set up the UDP port for broadcasting
	udp_broadcast.set_broadcast_enabled(true)
	var _e = udp_broadcast.set_dest_address("255.255.255.255", m_announce_port)
	udp_receiver = PacketPeerUDP.new()
	_e = udp_receiver.listen(m_game_port)

func _ready():
	# Set up the signal handlers
	var _e = self.connect("start_announcing", self, "_start_announcing")
	_e = self.connect("stop_announcing", self, "_stop_announcing")
	emit_signal("log_message", "Server started")

func _exit_tree():
	# Notify everyone that we're shutting down
	send_custom_command("SHUTDOWN", str(m_game_port))
	# And tidy up
	udp_broadcast.close()
	udp_receiver.close()
	emit_signal("log_message", "Server stopped")

func start_announcing():
	emit_signal("start_announcing")

func stop_announcing():
	emit_signal("stop_announcing")

func set_app_name(new_name : String):
	m_app_name = new_name

func get_app_name():
	return m_app_name

func set_announce_port(new_port : int):
	m_announce_port = new_port

func get_announce_port():
	return m_announce_port

func set_game_port(new_port : int):
	m_announce_port = new_port

func get_game_port():
	return m_announce_port

func send_custom_command(message: String, payload : String):
	var msg = MAGIC_HEADER + "\n" + m_app_name + "\n" + message + "\n" + payload
	var _e = udp_broadcast.put_packet(msg.to_ascii())
	
func _start_announcing():
	# We want an immediate annoucement
	ping_countdown = 0
	# Set our flag, to start sending annoucements
	broadcast_enabled = true
	emit_signal("log_message", "Server announcements started")

func _stop_announcing():
	# Clear the flag, to stop announcements
	broadcast_enabled = false
	emit_signal("log_message", "Server announcements stopped")

func _process(delta):
	# If we are announcing our existence...
	if broadcast_enabled == true:
		# Reduce the countdown to the next announcement
		ping_countdown -= delta
		
		# If we're overdue an announcement...
		if ping_countdown < 0:
			# Reset the timer
			ping_countdown = ANNOUNCE_FREQUENCY
			# Announce our app to the network
			send_custom_command("ANNOUNCE", str(m_game_port))
	
	# While we have incoming packets to process...
	while udp_receiver.get_available_packet_count() > 0:
		var packet = udp_receiver.get_packet()
		var header = packet.subarray(0, MAGIC_HEADER.length()-1).get_string_from_ascii()
		
		# If the packet doesn't have our magic header...
		if header != MAGIC_HEADER:
			emit_signal("log_message", "Invalid magic, ignoring this packet: '" + header + "' != '" + MAGIC_HEADER+"'")
			continue # Stop processing it
		
		# Split the packet into magic, app name, message, payload
		var msg = packet.get_string_from_ascii().split("\n", true, 4)
		
		# If there aren't enough fields to include a message type...
		if msg.size() < 3:
			emit_signal("log_message", "Insufficient data in the packet? Only " + msg.size() + " fields")
			# Ignore it
			continue
		
		# If the app name in the packet doesn't match ours...
		if msg[1] != m_app_name:
			emit_signal("log_message", "Packet's app name doesn't match ours! '" + msg[1] + "' != '" + m_app_name + "'")
			# Ignore it. It's someone else's problem :)
			continue
		
		match msg[2]:
			"ANNOUNCE":
				# An announcement of a server. We'll receive our own announcements,
				# so we won't do anything, but catching this stops it from falling
				# into the "Unknown message type" category :)
				var _doing = "nothing"
			"REGISTER":
				# The client is asking to register with the server. As this class
				# is only intended for discovery of the server, we'll emit a signal
				# with their IP address and let the caller decide how to handle
				# the game clients
				emit_signal("client_register", udp_receiver.get_packet_ip())
			"SHUTDOWN":
				# Another server on the network that's also using our broadcast port
				# is shutting down. Do we care? If not...
				var _doing = "nothing"
			_:
				# Okay, it's one of our messages, the app matches ours...but the
				# command is unknown 
				emit_signal("client_unknown_command", udp_receiver.get_packet_ip(), msg[2], msg[3])

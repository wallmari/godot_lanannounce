extends Node

# Magic header value, so we can tell packets are ours
const MAGIC_HEADER = "GODOTGAMESERVER"

# Signal sent when the listener receives an appropriate server announcement
signal server_discovered(ip_address, port)

# Signal sent when the listener receives an appropriate server shutdown message
signal server_shutdown(ip_address, port)

# Signal sent when an unrecognised message is received
signal server_unknown_command(ip_address, message, payload)

# Signal sent to start the listener process
signal start_listening

# Signal sent to stop the listener process
signal stop_listening

# Signal sent to log messages from this component
signal log_message(message)

# The name of the application we're interested in
var m_app_name

# The UDP port number of the game port
var m_port

# The UDP packet listener
var udp_receiver : PacketPeerUDP

func _init(app_name : String, port : int):
	m_app_name = app_name
	m_port = port
	udp_receiver = PacketPeerUDP.new()

func _exit_tree():
	# Tidy up
	udp_receiver.close()
	emit_signal("log_message", "Client listener stopped")

func start_listening():
	emit_signal("start_listening")

func stop_listening():
	emit_signal("stop_listening")

func register_with_server(ip_address : String, port : int):
	# Log the registration
	emit_signal("log_message", "Registering with " + ip_address + ":" + str(port))
	
	# Build and send a REGISTER message
	send_custom_command(ip_address, port, "REGISTER")

func send_custom_command(ip_address : String, port : int, command : String, payload : String = ""):
	# Build and send a REGISTER message
	var message = MAGIC_HEADER + "\n" + m_app_name + "\n" + command + "\n" + payload
	var _e = udp_receiver.set_dest_address(ip_address, port)
	_e = udp_receiver.put_packet(message.to_ascii())

# Called when the node enters the scene tree for the first time.
func _ready():
	var _e = self.connect("start_listening", self, "_start_listening")
	_e = self.connect("stop_listening", self, "_stop_listening")

func _start_listening():
	if udp_receiver.is_listening() == false:
		var _e = udp_receiver.listen(m_port)

func _stop_listening():
	emit_signal("log_message", "Stopping listening")
	udp_receiver.close()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# While we have received packets to process...
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
			"ANNOUNCE": # Server is announcing itself to the network
				emit_signal("server_discovered", udp_receiver.get_packet_ip(), msg[3].to_int())
			"SHUTDOWN": # Server is removing itself from the network
				emit_signal("server_shutdown", udp_receiver.get_packet_ip(), msg[3].to_int())
			_: # Any other server messages
				emit_signal("server_unknown_command", udp_receiver.get_packet_ip(), msg[2], msg[3])
				emit_signal("log_message", "Unknown message '" + msg[2] + "', payload: " + msg[3])

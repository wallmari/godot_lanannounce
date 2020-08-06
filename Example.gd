extends GridContainer

var host = preload("res://addon/LANAnnounceServer.gd")
var clientclass = preload("res://addon/LANAnnounceClient.gd")
var server
var client

func server_log_message(message : String):
	$"Panel/txt_log".insert_text_at_cursor("SERVER: " + message + "\n")

func client_log_message(message : String):
	$"Panel/txt_log".insert_text_at_cursor("CLIENT: " + message + "\n")

func scene_log_message(message : String):
	$"Panel/txt_log".insert_text_at_cursor("SCENE: " + message + "\n")

# ==============================================================================
# Server side

# "Start announcing" button
func _on_Button_pressed():
	if server != null:
		server.start_announcing()

# "Stop announcing" button
func _on_Button2_pressed():
	if server != null:
		server.stop_announcing()

func _on_btn_start_server_pressed():
	if server == null:
		server = host.new($"VBox/Panel/txt_app_name".text, $"VBox/Panel/txt_udp_port".text.to_int())
		server.connect("client_register", self, "client_registered")
		server.connect("client_unknown_command", self, "command_handler")
		server.connect("log_message", self, "server_log_message")

	if server.get_parent() == null:	
		get_tree().root.add_child(server)

func _on_btn_stop_server_pressed():
	if server != null:
		server.stop_announcing()
		get_tree().root.remove_child(server)
		server.free()
		server = null

# A packet has been received to register the client to the server. As this could
# be handled in a multitude of ways, this app doesn't do that :)
func client_registered(ip_address):
	scene_log_message("Processing registration from " + ip_address)
	# Here is where we'd add the client to whatever we're using to handle
	# the multiplayer data

# A message has been received that the broadcast server doesn't understand. Here
# we can deal with them
func command_handler(message, payload):
	# But for now, we just write the details to the console :)
	scene_log_message("Unknown message type: " + message)
	scene_log_message("Payload: " + payload)

# ==============================================================================
# Client side

func _on_btn_listen_pressed():
	scene_log_message("Listening for servers...")
	if client == null:
		client = clientclass.new($"VBox/Panel2/txt_client_app".text, $"VBox/Panel2/txt_client_port".text.to_int())
		client.connect("server_discovered", self, "server_discovered")
		client.connect("server_shutdown", self, "server_shutdown")
		client.connect("server_unknown", self, "server_unknown_command")
		client.connect("log_message", self, "client_log_message")
	
	if client.get_parent() == null:
		get_tree().root.add_child(client)
	
	client.start_listening()

func _on_btn_stop_pressed():
	if client != null:
		client.stop_listening()

func server_discovered(ip_address, port : int):
	# Note: this is not IPv6 safe, at all!
	var display_name = ip_address + ":" + str(port)
	
	scene_log_message("Server discovered at " + display_name)
	var list = $"VBox/Panel2/ItemList"
	var server_list : Dictionary = {}

	# If the list has any items in it already...
	if list.get_item_count() > 0:
		# Create a dictionary of the existing items, so we don't duplicate
		for x in range(list.get_item_count()):
			server_list[list.get_item_text(x)] = 1
	
	# If our new server isn't already in the list...
	if not server_list.has(display_name):
		# Add our item to the list
		$"VBox/Panel2/ItemList".add_item(display_name)
	
	# And we may as well sort it
	list.sort_items_by_text()

func server_shutdown(ip_address, port : int):
	# Note: this is not IPv6 safe, at all!
	var display_name = ip_address + ":" + str(port)
	
	scene_log_message("Server shutdown from " + display_name)
	var list = $"VBox/Panel2/ItemList"
	
	# Create a dictionary of the existing items, so we don't duplicate
	for x in range(list.get_item_count()):
		if list.get_item_text(x) == display_name:
			list.remove_item(x)
	
	# And we may as well sort it
	list.sort_items_by_text()

func server_unknown(ip_address, message, payload):
	var msg = "Unrecognised message from server " + ip_address + "\n"
	msg += "\tMessage type: " + message + "\n"
	msg += "\tPayload: " + payload
	scene_log_message(msg)

func _on_btn_register_pressed():
	var list = $"VBox/Panel2/ItemList"
	var selected = list.get_selected_items()
	
	# If nothing is selected...
	if selected.size() == 0:
		# Do nothing
		return
	
	# TODO: this is not IPv6 safe!
	var parts = list.get_item_text(selected[0]).split(":")	
	
	client.register_with_server(parts[0], parts[1].to_int())

func _on_btn_clear_pressed():
	$"VBox/Panel2/ItemList".clear()

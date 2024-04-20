extends Node2D

var request
var connection_count = 0
var request_count = 0
var stop = false
var is_siege = false

func _stop_all():
	stop = true
	is_siege = false

func _on_send_loop():
	stop = false
	is_siege = true
	connection_count = 0
	request_count = 0
	if not _are_inputs_set():
		$output/responseWindow.text = "Please fill all fields"
		return
	if int($input/connectionsEntry.text) < 1:
		$output/responseWindow.text = "Please enter a valid number of loops"
		return
	if $input/requestsEntry.text == "":
		$output/responseWindow.text = "Please enter a valid number of request"
		return
	var i = 0
	var loops = int($input/connectionsEntry.text)
	while i < loops:
		_make_http_connection()
		i+=1
		$output/loopsWindow.text = str(i)
		if stop:
			return
	is_siege = false

func _are_inputs_set() -> bool:
	var url = $input/targetEntry.text
	var port = $input/portEntry.text
	var method = $input/selectMethod.get_selected_id()
	var file = $input/fileEntry.text
	if url == "" or port == "" or file == "" or method == -1:
		return false
	return true
	

func _on_send_pressed():
	connection_count = 0
	request_count = 0
	stop = false
	if not _are_inputs_set():
		$output/responseWindow.text = "Please fill all fields"
		return
	_make_http_connection()

func _make_http_connection():
	var url = $input/targetEntry.text
	var file = $input/fileEntry.text
	var method
	var request_to_do
	match $input/selectMethod.get_selected_id():
		0:
			method = HTTPClient.METHOD_GET
		1:
			method = HTTPClient.METHOD_POST
		2:
			method = HTTPClient.METHOD_DELETE
		3:
			method = HTTPClient.METHOD_PUT
	var port = int($input/portEntry.text)
	var err = 0
	var http = HTTPClient.new() # Create the Client.
	var counter = 0
	
	err = http.connect_to_host(url, port)
	
	if err != OK:
		$output/responseWindow.text = "Failed to connect: " + str(err)
		return

# Wait until resolved and connected.
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		counter += 1
		$output/responseWindow.text = "Connecting... Tries: " + str(counter)
#		await get_tree().process_frame
		if stop:
			return

#	assert(http.get_status() == HTTPClient.STATUS_CONNECTED) # Check if the connection was made successfully.
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		$output/responseWindow.text = "Bad connection"
		return

	# Some headers

	var j = 0
	if not is_siege:
		request_to_do = 1
	else:
		request_to_do = int($input/requestsEntry.text)
	while j < request_to_do:
		var headers = [
			"User-Agent: Pirulo/1.0 (Godot)",
			"Accept: */*"
		]
		err = http.request(method, file, headers) # Request a page from the site (this one was chunked..)
		if err != OK:
			$output/responseWindow.text = "Failed to request: " + str(err)
			return
		counter = 0
		while http.get_status() == HTTPClient.STATUS_REQUESTING:
			# Keep polling for as long as the request is being processed.
			http.poll()
			counter += 1
			$output/responseWindow.text = "requesting... Tries: " + str(counter)
			await get_tree().process_frame
			if stop:
				return

	#	assert(http.get_status() == HTTPClient.STATUS_BODY or http.get_status() == HTTPClient.STATUS_CONNECTED) # Make sure request finished well.
		if http.get_status() != HTTPClient.STATUS_BODY and http.get_status() != HTTPClient.STATUS_CONNECTED:
			$output/responseWindow.text = "Failed to finish request: " + str(err)
			return
			
	#	print("response? ", http.has_response()) # Site might not have a response.

		if http.has_response():
			# If there is a response...

			headers = http.get_response_headers_as_dictionary() # Get response headers.
	#		print("code: ", http.get_response_code()) # Show response code.
	#		print("**headers:\\n", headers) # Show headers.

			# Getting the HTTP Body

	#		if http.is_response_chunked():
	#			# Does it use chunks?
	#			print("Response is Chunked!")
	#		else:
	#			# Or just plain Content-Length
	#			var bl = http.get_response_body_length()
	#			print("Response Length: ", bl)

			# This method works for both anyway

			var rb = PackedByteArray() # Array that will hold the data.

			while http.get_status() == HTTPClient.STATUS_BODY:
				# While there is body left to be read
				http.poll()
				# Get a chunk.
				var chunk = http.read_response_body_chunk()
				if chunk.size() == 0:
					await get_tree().process_frame
				else:
					rb = rb + chunk # Append to read buffer.
				if stop:
					return
			# Done!

	#		print("bytes got: ", rb.size())
			var text = rb.get_string_from_ascii()
	#		print("Text: ", text)

			$output/responseWindow.text = text
			j+=1
			request_count +=1
			$output/requestsWindow.text = str(request_count)

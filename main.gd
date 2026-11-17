extends Control

var refrenceutau: String = ""

@onready var pfp = $PFP


func _ready() -> void:
	$PopupPanel.visible = true


func _on_popup_ref_bank_enter_pressed() -> void:
	refrenceutau = $PopupPanel/VBoxContainer/HBoxContainer/LineEdit.text

	var char_path := refrenceutau.path_join("character.txt")
	if not FileAccess.file_exists(char_path):
		push_warning("No character.txt found in: " + refrenceutau)
		return

	var info := parse_character_txt(char_path)

	if not info.has("image"):
		push_warning("character.txt has no image= entry")
		return

	var img := Image.load_from_file(refrenceutau.path_join(info["image"]))
	if img == null:
		push_error("Failed to load image")
		return

	$Name.text = info.get("name", "Unknown")
	pfp.texture = ImageTexture.create_from_image(img)

	print("Files: ", DirAccess.get_files_at(refrenceutau))
	print("Subfolders: ", DirAccess.get_directories_at(refrenceutau))
	print("sample= value: ", info.get("sample", "<none>"))


		# Sample audio (optional)
	var sample: AudioStreamWAV = null

	if info.has("sample"):
		var sample_name: String = info["sample"].replace("\\_", "_")
		sample = load_wav(refrenceutau.path_join(sample_name))

	# Fallback: first .wav found anywhere in the bank
	if sample == null:
		var wav_path := find_first_wav(refrenceutau)
		if wav_path != "":
			print("Using sample: ", wav_path)
			sample = load_wav(wav_path)

	if sample == null:
		push_warning("Could not load any sample from: " + refrenceutau)
	else:
		$SamplePlayer.stream = sample
		
func find_first_wav(dir: String) -> String:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() == "wav":
			return dir.path_join(f)
	for d in DirAccess.get_directories_at(dir):
		var found := find_first_wav(dir.path_join(d))
		if found != "":
			return found
	return ""


# Reads key=value lines (name=, image=, sample=, ...) into a Dictionary
func parse_character_txt(path: String) -> Dictionary:
	var result := {}
	var text := read_text_auto(path)
	for line in text.split("\n"):
		line = line.strip_edges()
		var eq := line.find("=")
		if eq == -1:
			continue
		var key := line.substr(0, eq).strip_edges()
		var value := line.substr(eq + 1).strip_edges()
		result[key] = value

	return result


# Reads UTF-8 or Shift-JIS (CP932) text via iconv (Linux)
func read_text_auto(path: String) -> String:
	var out := []

	if OS.execute("iconv", ["-f", "UTF-8", "-t", "UTF-8", path], out) == 0 and out.size() > 0:
		return out[0]

	out.clear()
	if OS.execute("iconv", ["-f", "CP932", "-t", "UTF-8", path], out) == 0 and out.size() > 0:
		return out[0]

	var ascii := PackedByteArray()
	for b in FileAccess.get_file_as_bytes(path):
		if b < 128:
			ascii.append(b)
	return ascii.get_string_from_ascii()


# Minimal WAV loader: 16-bit PCM only
func load_wav(path: String) -> AudioStreamWAV:
	if not FileAccess.file_exists(path):
		return null

	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null

	var stream := AudioStreamWAV.new()
	var got_fmt := false
	var pos := 12

	while pos + 8 <= bytes.size():
		var id := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size := bytes.decode_u32(pos + 4)
		var body := pos + 8

		if id == "fmt ":
			var tag := bytes.decode_u16(body)
			var channels := bytes.decode_u16(body + 2)
			var bits := bytes.decode_u16(body + 14)
			if tag != 1 or bits != 16:
				push_warning("Only 16-bit PCM WAV is supported")
				return null
			stream.mix_rate = bytes.decode_u32(body + 4)
			stream.format = AudioStreamWAV.FORMAT_16_BITS
			stream.stereo = (channels == 2)
			got_fmt = true
		elif id == "data" and got_fmt:
			stream.data = bytes.slice(body, mini(body + size, bytes.size()))
			return stream

		pos = body + size + (size % 2)

	return null


func _on_popup_panel_close_requested() -> void:
	$PopupPanel.visible = false


func _on_sample_play_button_pressed() -> void:
	$SamplePlayer.play()


func _on_popup_done_pressed() -> void:
	$PopupPanel.visible = false

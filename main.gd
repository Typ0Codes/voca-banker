extends Control

var refrenceutau: String = "" 

@onready var pfp = $PFP



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$PopupPanel.visible = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


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

	var img_path := refrenceutau.path_join(info["image"])
	var img := Image.load_from_file(img_path)

	if img == null:
		push_error("Failed to load image: " + img_path)
		return
	
	$Name.text = info.get("name", "Unknown")

	pfp.texture = ImageTexture.create_from_image(img)



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

func _on_popup_panel_close_requested() -> void:
	$PopupPanel.visible = false

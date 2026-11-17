extends Control

const SETTINGS_PATH := "user://settings.cfg"

var refrenceutau := ""
var ref_info := {}       
var custom_info := {}    
var config := ConfigFile.new()

@onready var pfp = $PFP
@onready var recordbtn = $HBoxContainer/Record
@onready var refwavplayer = $RefWavPlayer
@onready var take_player: AudioStreamPlayer = $TakePlayer

@onready var char_dialog: Window = $CharDialog
@onready var name_edit: LineEdit = $CharDialog/VBoxContainer/NameEdit
@onready var image_edit: LineEdit = $CharDialog/VBoxContainer/ImageEdit
@onready var sample_edit: LineEdit = $CharDialog/VBoxContainer/SampleEdit
@onready var extra_edit: TextEdit = $CharDialog/VBoxContainer/ExtraEdit

var items: Array[String] = []
var index := 0
var output_dir := ""

var record_effect: AudioEffectRecord


func _ready() -> void:
	
	var bus_idx := AudioServer.get_bus_index("Record")
	if bus_idx == -1:
		push_error("No 'Record' audio bus. Add it in the Audio panel and save the layout.")
	else:
		record_effect = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectRecord
		if record_effect == null:
			push_error("The 'Record' bus needs a Record effect as its first effect.")

	
	config.load(SETTINGS_PATH)   
	var last: String = config.get_value("app", "last_ref", "")
	$PopupPanel/VBoxContainer/HBoxContainer/LineEdit.text = last

	if last != "" and DirAccess.dir_exists_absolute(last):
		$PopupPanel.visible = false
		load_bank(last)
	else:
		$PopupPanel.visible = true




func _on_popup_ref_bank_enter_pressed() -> void:
	load_bank($PopupPanel/VBoxContainer/HBoxContainer/LineEdit.text)


func _on_play_ref_audio_pressed() -> void:
	refwavplayer.play()


func _on_next_pressed() -> void:
	go_to(index + 1)


func _on_prev_pressed() -> void:
	go_to(index - 1)


func _on_record_pressed() -> void:
	if items.is_empty() or record_effect == null:
		return

	if record_effect.is_recording_active():
		record_effect.set_recording_active(false)
		var rec := record_effect.get_recording()
		if rec == null:
			return
		var out := take_path(items[index])
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		rec.save_to_wav(out)
		show_item()
	else:
		take_player.stop()
		record_effect.set_recording_active(true)
		recordbtn.text = "Stop"


func _on_playback_pressed() -> void:
	if take_player.stream == null:
		push_warning("No take recorded for this item yet")
		return
	take_player.play()


func _on_char_button_pressed() -> void:
	if refrenceutau == "":
		push_warning("Load a reference bank first")
		return
	name_edit.text = custom_info.get("name", "")
	image_edit.text = custom_info.get("image", "")
	sample_edit.text = custom_info.get("sample", "")
	extra_edit.text = custom_info.get("extra", "")
	char_dialog.popup_centered()


func _on_save_char_button_pressed() -> void:
	custom_info = {
		"name": name_edit.text.strip_edges(),
		"image": image_edit.text.strip_edges(),
		"sample": sample_edit.text.strip_edges(),
		"extra": extra_edit.text,
	}
	write_character_txt()
	save_progress()
	char_dialog.hide()


func _on_popup_panel_close_requested() -> void:
	$PopupPanel.visible = false


func _on_sample_play_button_pressed() -> void:
	$SamplePlayer.play()


func _on_popup_done_pressed() -> void:
	$PopupPanel.visible = false




func load_bank(path: String) -> void:
	refrenceutau = path.strip_edges().trim_suffix("/")
	if not DirAccess.dir_exists_absolute(refrenceutau):
		push_warning("Folder not found: " + refrenceutau)
		return

	output_dir = refrenceutau + "_new"

	items = collect_wavs(refrenceutau)
	items.sort()
	if items.is_empty():
		push_warning("No wav files found in: " + refrenceutau)

	ref_info = {}
	var char_path := refrenceutau.path_join("character.txt")
	if FileAccess.file_exists(char_path):
		ref_info = parse_character_txt(char_path)
	show_reference_character()
	load_reference_sample()

	var saved = config.get_value(bank_key(), "character", null)
	if saved is Dictionary:
		custom_info = saved
	else:
		custom_info = {"name": ref_info.get("name", ""), "image": "", "sample": "", "extra": ""}

	var saved_index: int = config.get_value(bank_key(), "index", 0)
	index = clampi(saved_index, 0, maxi(items.size() - 1, 0))
	show_item()
	save_progress()


func bank_key() -> String:
	return "bank_" + refrenceutau.md5_text()


func save_progress() -> void:
	if refrenceutau == "":
		return
	config.set_value("app", "last_ref", refrenceutau)
	config.set_value(bank_key(), "index", index)
	config.set_value(bank_key(), "character", custom_info)
	config.save(SETTINGS_PATH)


func show_reference_character() -> void:
	$Name.text = ref_info.get("name", "Unknown")
	var image_name: String = ref_info.get("image", "")
	if image_name != "":
		var img := Image.load_from_file(refrenceutau.path_join(image_name))
		if img != null:
			pfp.texture = ImageTexture.create_from_image(img)


func load_reference_sample() -> void:
	var sample: AudioStreamWAV = null

	if ref_info.has("sample"):
		var sample_name: String = ref_info["sample"].replace("\\_", "_")
		sample = load_wav(refrenceutau.path_join(sample_name))

	if sample == null:
		var wav_path := find_first_wav(refrenceutau)
		if wav_path != "":
			sample = load_wav(wav_path)

	if sample != null:
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




func write_character_txt() -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)

	var lines: PackedStringArray = []

	var bank_name: String = custom_info.get("name", "")
	if bank_name != "":
		lines.append("name=" + bank_name)

	var img_src: String = custom_info.get("image", "")
	if img_src != "" and FileAccess.file_exists(img_src):
		var img_file := img_src.get_file()
		DirAccess.copy_absolute(img_src, output_dir.path_join(img_file))
		lines.append("image=" + img_file)

	var sample_rel: String = custom_info.get("sample", "")
	if sample_rel != "":
		lines.append("sample=" + sample_rel)

	var extra: String = custom_info.get("extra", "").strip_edges()
	if extra != "":
		lines.append(extra)

	var text := "\r\n".join(lines) + "\r\n"

	
	var tmp := OS.get_user_data_dir().path_join("character_tmp.txt")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Could not write temp file: " + tmp)
		return
	f.store_string(text)
	f.close()

	var final_path := output_dir.path_join("character.txt")
	var out := []
	if OS.execute("iconv", ["-f", "UTF-8", "-t", "CP932", "-o", final_path, tmp], out) != 0:
		DirAccess.copy_absolute(tmp, final_path)
		push_warning("Saved character.txt as UTF-8 (iconv unavailable or text not representable in Shift-JIS)")

	DirAccess.remove_absolute(tmp)




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




func collect_wavs(root: String, rel: String = "") -> Array[String]:
	var found: Array[String] = []
	var dir := root.path_join(rel)

	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() == "wav":
			found.append(rel.path_join(f))

	for d in DirAccess.get_directories_at(dir):
		found.append_array(collect_wavs(root, rel.path_join(d)))

	return found


func take_path(rel: String) -> String:
	return output_dir.path_join(rel)


func show_item() -> void:
	if items.is_empty():
		$ItemLabel.text = "No wav files found"
		return
	var rel := items[index]
	var done := FileAccess.file_exists(take_path(rel))
	$ItemLabel.text = "%d / %d   %s%s" % [index + 1, items.size(), rel, "   (recorded)" if done else ""]
	refwavplayer.stream = load_wav(refrenceutau.path_join(rel))
	take_player.stream = load_wav(take_path(rel))
	recordbtn.text = "Record"


func go_to(new_index: int) -> void:
	if items.is_empty():
		return
	if record_effect != null and record_effect.is_recording_active():
		return
	refwavplayer.stop()
	take_player.stop()
	index = clampi(new_index, 0, items.size() - 1)
	show_item()
	save_progress()

extends Node

const MANIFEST_URL := "https://raw.githubusercontent.com/ffuxyxfyxhcocyocg-art/OPEN-WORLD-ANDROID/main/updates/manifest.json"
const MAX_PACK_BYTES := 64 * 1024 * 1024
const PACK_PATH := "user://game-update.pck"
const TEMP_PATH := "user://game-update.pck.tmp"

func _ready() -> void:
    await _apply_updates()
    get_tree().change_scene_to_file("res://scenes/world.tscn")

func _apply_updates() -> void:
    if FileAccess.file_exists(PACK_PATH):
        ProjectSettings.load_resource_pack(PACK_PATH, true)
    var request_node := HTTPRequest.new()
    request_node.timeout = 8.0
    request_node.body_size_limit = MAX_PACK_BYTES
    add_child(request_node)
    var err := request_node.request(MANIFEST_URL, ["Cache-Control: no-cache"])
    if err != OK:
        return
    var result: Array = await request_node.request_completed
    if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 200:
        return
    var manifest_bytes: PackedByteArray = result[3]
    var manifest = JSON.parse_string(manifest_bytes.get_string_from_utf8())
    if not manifest is Dictionary:
        return
    var version := int(manifest.get("version", 0))
    if version < 1 or version <= _local_version():
        return
    var url := str(manifest.get("pck_url", ""))
    var expected := str(manifest.get("sha256", "")).to_lower()
    if not url.begins_with("https://github.com/ffuxyxfyxhcocyocg-art/OPEN-WORLD-ANDROID/releases/download/") or expected.length() != 64:
        return
    request_node.timeout = 30.0
    err = request_node.request(url, ["Cache-Control: no-cache"])
    if err != OK:
        return
    result = await request_node.request_completed
    if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 200:
        return
    var bytes: PackedByteArray = result[3]
    if bytes.is_empty() or bytes.size() > MAX_PACK_BYTES:
        return
    var hashing := HashingContext.new()
    if hashing.start(HashingContext.HASH_SHA256) != OK:
        return
    hashing.update(bytes)
    if hashing.finish().hex_encode().to_lower() != expected:
        return
    var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if file == null:
        return
    file.store_buffer(bytes)
    file.flush()
    file.close()
    var absolute_pack := ProjectSettings.globalize_path(PACK_PATH)
    var absolute_temp := ProjectSettings.globalize_path(TEMP_PATH)
    DirAccess.remove_absolute(absolute_pack)
    if DirAccess.rename_absolute(absolute_temp, absolute_pack) != OK:
        return
    if not ProjectSettings.load_resource_pack(PACK_PATH, true):
        return
    var version_file := FileAccess.open("user://game_update_version.txt", FileAccess.WRITE)
    if version_file:
        version_file.store_string(str(version))
        version_file.close()

func _local_version() -> int:
    if not FileAccess.file_exists("user://game_update_version.txt"):
        return 0
    var file := FileAccess.open("user://game_update_version.txt", FileAccess.READ)
    if file == null:
        return 0
    var version := int(file.get_as_text().strip_edges())
    file.close()
    return version

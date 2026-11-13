extends Node

const MANIFEST_URL := "https://raw.githubusercontent.com/ffuxyxfyxhcocyocg-art/OPEN-WORLD-ANDROID/main/content/manifest.json"
const MAX_DOWNLOAD_BYTES := 8 * 1024 * 1024

func fetch_config() -> Dictionary:
    var cached := _read_cached_config()
    var manifest_request := HTTPRequest.new()
    manifest_request.timeout = 8.0
    add_child(manifest_request)
    var request_error := manifest_request.request(MANIFEST_URL, ["Cache-Control: no-cache"])
    if request_error != OK:
        manifest_request.queue_free()
        return cached
    var manifest_result: Array = await manifest_request.request_completed
    manifest_request.queue_free()
    if manifest_result[0] != HTTPRequest.RESULT_SUCCESS or manifest_result[1] != 200:
        return cached
    var manifest_bytes: PackedByteArray = manifest_result[3]
    var manifest_text := manifest_bytes.get_string_from_utf8()
    var manifest = JSON.parse_string(manifest_text)
    if not manifest is Dictionary:
        return cached
    var remote_version := int(manifest.get("version", 0))
    if remote_version < 1 or remote_version <= _read_local_version():
        return cached
    var content_url := str(manifest.get("content_url", ""))
    var expected_hash := str(manifest.get("sha256", "")).to_lower()
    if not content_url.begins_with("https://raw.githubusercontent.com/") or expected_hash.length() != 64:
        return cached
    var content_request := HTTPRequest.new()
    content_request.timeout = 12.0
    content_request.body_size_limit = MAX_DOWNLOAD_BYTES
    add_child(content_request)
    request_error = content_request.request(content_url, ["Cache-Control: no-cache"])
    if request_error != OK:
        content_request.queue_free()
        return cached
    var content_result: Array = await content_request.request_completed
    content_request.queue_free()
    if content_result[0] != HTTPRequest.RESULT_SUCCESS or content_result[1] != 200:
        return cached
    var bytes: PackedByteArray = content_result[3]
    var hashing := HashingContext.new()
    if hashing.start(HashingContext.HASH_SHA256) != OK:
        return cached
    hashing.update(bytes)
    if hashing.finish().hex_encode().to_lower() != expected_hash:
        return cached
    var parsed = JSON.parse_string(bytes.get_string_from_utf8())
    if not parsed is Dictionary:
        return cached
    var settings = parsed.get("world_settings", {})
    if not settings is Dictionary:
        return cached
    var file := FileAccess.open("user://world.json.tmp", FileAccess.WRITE)
    if file == null:
        return cached
    file.store_buffer(bytes)
    file.flush()
    file.close()
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://world.json"))
    if DirAccess.rename_absolute(ProjectSettings.globalize_path("user://world.json.tmp"), ProjectSettings.globalize_path("user://world.json")) != OK:
        return cached
    var version_file := FileAccess.open("user://world_version.txt", FileAccess.WRITE)
    if version_file:
        version_file.store_string(str(remote_version))
        version_file.close()
    return settings

func _read_local_version() -> int:
    if not FileAccess.file_exists("user://world_version.txt"):
        return 0
    var file := FileAccess.open("user://world_version.txt", FileAccess.READ)
    if file == null:
        return 0
    var value := int(file.get_as_text().strip_edges())
    file.close()
    return value

func _read_cached_config() -> Dictionary:
    if not FileAccess.file_exists("user://world.json"):
        return {}
    var file := FileAccess.open("user://world.json", FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if not parsed is Dictionary:
        return {}
    var settings = parsed.get("world_settings", {})
    return settings if settings is Dictionary else {}


const PACK_MANIFEST_URL := "https://raw.githubusercontent.com/ffuxyxfyxhcocyocg-art/OPEN-WORLD-ANDROID/main/updates/manifest.json"
const MAX_PACK_BYTES := 512 * 1024 * 1024

func fetch_game_pack() -> bool:
    var manifest_request := HTTPRequest.new()
    manifest_request.timeout = 20.0
    add_child(manifest_request)
    var err := manifest_request.request(PACK_MANIFEST_URL, ["Cache-Control: no-cache"])
    if err != OK:
        manifest_request.queue_free()
        return false
    var manifest_result: Array = await manifest_request.request_completed
    manifest_request.queue_free()
    if manifest_result[0] != HTTPRequest.RESULT_SUCCESS or manifest_result[1] != 200:
        return false
    var manifest = JSON.parse_string((manifest_result[3] as PackedByteArray).get_string_from_utf8())
    if not manifest is Dictionary:
        return false
    var version := int(manifest.get("version", 0))
    var pack_url := str(manifest.get("pck_url", ""))
    var expected_hash := str(manifest.get("sha256", "")).to_lower()
    if version < 1 or version <= _read_pack_version():
        return false
    if not pack_url.begins_with("https://github.com/ffuxyxfyxhcocyocg-art/OPEN-WORLD-ANDROID/releases/download/") or expected_hash.length() != 64:
        return false

    var pack_request := HTTPRequest.new()
    pack_request.timeout = 180.0
    pack_request.body_size_limit = MAX_PACK_BYTES
    pack_request.download_chunk_size = 262144
    add_child(pack_request)
    err = pack_request.request(pack_url, ["Cache-Control: no-cache"])
    if err != OK:
        pack_request.queue_free()
        return false
    var pack_result: Array = await pack_request.request_completed
    pack_request.queue_free()
    if pack_result[0] != HTTPRequest.RESULT_SUCCESS or pack_result[1] != 200:
        return false
    var bytes: PackedByteArray = pack_result[3]
    if bytes.is_empty() or bytes.size() > MAX_PACK_BYTES:
        return false
    var hashing := HashingContext.new()
    if hashing.start(HashingContext.HASH_SHA256) != OK:
        return false
    hashing.update(bytes)
    if hashing.finish().hex_encode().to_lower() != expected_hash:
        return false

    var folder := ProjectSettings.globalize_path("user://updates")
    if DirAccess.make_dir_recursive_absolute(folder) != OK and not DirAccess.dir_exists_absolute(folder):
        return false
    var final_path := ProjectSettings.globalize_path("user://updates/game-update.pck")
    var temp_path := final_path + ".tmp"
    var file := FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_buffer(bytes)
    file.flush()
    file.close()
    if FileAccess.file_exists(final_path):
        DirAccess.remove_absolute(final_path)
    if DirAccess.rename_absolute(temp_path, final_path) != OK:
        return false
    if not ProjectSettings.load_resource_pack(final_path, true):
        return false
    var version_file := FileAccess.open("user://updates/pack_version.txt", FileAccess.WRITE)
    if version_file == null:
        return false
    version_file.store_string(str(version))
    version_file.close()
    return true

func _read_pack_version() -> int:
    if not FileAccess.file_exists("user://updates/pack_version.txt"):
        return 0
    var file := FileAccess.open("user://updates/pack_version.txt", FileAccess.READ)
    if file == null:
        return 0
    var version := int(file.get_as_text().strip_edges())
    file.close()
    return version

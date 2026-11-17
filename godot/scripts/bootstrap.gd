extends Node

func _ready() -> void:
    # O pacote remoto so e aplicado se ja tiver sido baixado e validado.
    var updater_script: Script = preload("res://scripts/remote_updater.gd")
    var updater: Node = updater_script.new()
    updater.load_cached_pack()
    updater.free()

    # Carregue a cena explicitamente antes de trocar. Isso evita uma troca
    # silenciosa para uma cena invalida e facilita detectar falhas no log.
    var world: PackedScene = load("res://scenes/world.tscn") as PackedScene
    if world == null:
        push_error("OPEN WORLD: nao foi possivel carregar scenes/world.tscn")
        return
    get_tree().call_deferred("change_scene_to_packed", world)

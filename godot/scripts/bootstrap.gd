extends Node

func _ready() -> void:
    # Carregue o pacote live salvo antes de abrir qualquer cena do jogo.
    # Assim, atualizações baixadas na sessão anterior entram em vigor ao reabrir.
    var updater = preload("res://scripts/remote_updater.gd").new()
    updater.load_cached_pack()
    updater.free()

    # A cena abre imediatamente; a busca por atualizações ocorre dentro do mundo.
    get_tree().change_scene_to_file("res://scenes/world.tscn")

extends Node

func _ready() -> void:
    # Abra o mundo imediatamente. A atualização live é verificada depois
    # que a cena 3D já estiver visível, para evitar tela azul na inicialização.
    get_tree().change_scene_to_file("res://scenes/world.tscn")

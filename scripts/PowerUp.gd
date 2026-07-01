extends Area2D

@onready var sprite: Sprite2D = $Sprite2D

var frame_map = {
	"double_jump": 6,
	"invincible": 5,
	"speed": 4,
	"rapid_fire": 3,
	"spike_mode": 2,
	"earthquake": 1,
	"platform_flip": 0
}

func _ready() -> void:
	# O PowerUpManager configura essas 'metas' antes de colocar o item na tela
	if has_meta("powerup_type"):
		var type = get_meta("powerup_type")
		
		# Muda o desenho do sprite para o item correspondente
		if frame_map.has(type):
			sprite.frame = frame_map[type]
			
	# Cria a animação de flutuar (bobbing)
	var tween = create_tween().set_loops()
	tween.tween_property(self, "position:y", position.y - 8, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", position.y, 0.6).set_trans(Tween.TRANS_SINE)
	
	# Conecta a colisão diretamente na função do PowerUpManager (que é o "Pai" deste nó)
	body_entered.connect(func(body):
		if get_parent().has_method("_on_pickup_body_entered"):
			get_parent()._on_pickup_body_entered(self, body)
	)

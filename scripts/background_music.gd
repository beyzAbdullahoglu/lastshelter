extends AudioStreamPlayer

# Autoloaded so the track keeps playing across scene changes (start screen, restarts).
const MUSIC: AudioStreamMP3 = preload("res://audio/background_music.mp3")
const MUSIC_VOLUME_DB := -20.0


func _ready() -> void:
	var music := MUSIC.duplicate() as AudioStreamMP3
	music.loop = true
	stream = music
	volume_db = MUSIC_VOLUME_DB
	process_mode = Node.PROCESS_MODE_ALWAYS
	play()

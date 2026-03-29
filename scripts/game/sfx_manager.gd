extends Node

var _players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS: int = 8

func _ready() -> void:
	for i in range(MAX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)

func _get_free_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	return _players[0]

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var player := _get_free_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

func play_merge() -> void:
	var stream := _make_tone(523.25, 0.08)  # C5
	play_sfx(stream, -6.0, 1.0)
	# Second note slightly delayed via pitch trick
	var stream2 := _make_tone(659.25, 0.12)  # E5
	play_sfx(stream2, -6.0, 1.0)

func play_spawn() -> void:
	var stream := _make_tone(392.0, 0.1)  # G4 pop
	play_sfx(stream, -8.0, 1.2)

func play_tap() -> void:
	var stream := _make_tone(440.0, 0.05)  # A4 short click
	play_sfx(stream, -10.0, 1.5)

func play_energy_refill() -> void:
	var stream := _make_tone(587.33, 0.15)  # D5 shimmer
	play_sfx(stream, -8.0, 1.0)

func play_task_complete() -> void:
	# Rising arpeggio feel
	var stream := _make_tone(523.25, 0.2)  # C5
	play_sfx(stream, -4.0, 1.0)
	var stream2 := _make_tone(659.25, 0.2)  # E5
	play_sfx(stream2, -4.0, 1.0)
	var stream3 := _make_tone(783.99, 0.3)  # G5
	play_sfx(stream3, -4.0, 1.0)

func play_sell() -> void:
	var stream := _make_tone(880.0, 0.08)  # A5 coin
	play_sfx(stream, -8.0, 1.3)

func play_error() -> void:
	var stream := _make_tone(220.0, 0.15)  # A3 low buzz
	play_sfx(stream, -6.0, 0.8)

func _make_tone(frequency: float, duration: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit mono

	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var envelope: float = 1.0 - (float(i) / float(num_samples))
		envelope = envelope * envelope  # Quadratic fade
		var sample_value: float = sin(TAU * frequency * t) * envelope
		# Add slight harmonics for richness
		sample_value += sin(TAU * frequency * 2.0 * t) * envelope * 0.3
		sample_value += sin(TAU * frequency * 3.0 * t) * envelope * 0.1
		var sample_int: int = clampi(int(sample_value * 16000.0), -32768, 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

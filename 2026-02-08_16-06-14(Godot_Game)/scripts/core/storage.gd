extends RefCounted


const SAVE_PATH = "user://save.cfg"
const SAVE_SECTION = "player"
const SAVE_KEY_LAST_DECK = "last_deck"


func save_last_deck(deck: Array) -> bool:
	var cfg = ConfigFile.new()
	var load_err = cfg.load(SAVE_PATH)
	if load_err != OK and load_err != ERR_FILE_NOT_FOUND:
		push_warning("Failed to load existing save before write: %s" % error_string(load_err))

	cfg.set_value(SAVE_SECTION, SAVE_KEY_LAST_DECK, deck.duplicate(true))
	var save_err = cfg.save(SAVE_PATH)
	if save_err != OK:
		push_warning("Failed to save last deck: %s" % error_string(save_err))
		return false

	return true


func load_last_deck() -> Array:
	var cfg = ConfigFile.new()
	var load_err = cfg.load(SAVE_PATH)
	if load_err != OK:
		return []

	var saved = cfg.get_value(SAVE_SECTION, SAVE_KEY_LAST_DECK, [])
	if saved is Array:
		return (saved as Array).duplicate(true)

	return []

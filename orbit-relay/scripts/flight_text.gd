extends RefCounted

const MESSAGES := {
	"LINK_TITLE": ["Видеоканал", "Video link"],
	"LINK_SHORTCUT": ["Связь", "Comms"],
	"LINK_CONNECTING": ["Настройка канала", "Connecting"],
	"LINK_OPEN": ["Приём", "Receiving"],
	"LINK_CLOSE": ["Завершить связь", "End transmission"],
	"LINK_RECEIPT": ["Ответ", "Response"],
	"CAMERA_EXTERIOR": ["Снаружи", "Chase"],
	"CAMERA_COCKPIT": ["Кабина", "Cockpit"],
	"CAMERA_REAR": ["Назад", "Rear"],
	"CAMERA_OBSERVER": ["Обзор", "Observer"],
	"CAMERA_MISSILE": ["Ракета", "Missile"],
	"CAMERA_NEXT": ["Следующий ракурс «%s» (F1)", "Next camera: %s (F1)"],
	"CAMERA_LOCK_REQUIRED": ["Нужны ракетная телеметрия и активная ракета", "Requires missile telemetry and an active missile"],
	"AIM_LOCK": ["Захват", "Lock"],
	"AIM_LOCK_TOOLTIP": ["Захватить корабль у прицела (.)", "Lock a ship near the reticle (.)"],
	"AIM_LOCK_EMPTY": ["Подведите прицел к доступной цели.", "Bring the reticle onto a lockable target."],
	"COMBAT_EVASIVE": ["уклоняется", "evading"],
	"NAV_TITLE": ["Объекты системы", "System objects"],
	"NAV_SHORTCUT": ["Цели", "Targets"],
	"NAV_CLOSE": ["Закрыть", "Close"],
	"NAV_LIST": ["К целям", "Targets"],
	"NAV_NO_COMPUTER": ["Список целей доступен с навигационным компьютером.", "Install a navigation computer to use the target list."],
	"NAV_BEARING": ["Пеленг %+.0f° · угол %+.0f°", "Bearing %+.0f° · elevation %+.0f°"],
	"NAV_LABELS_ON": ["Подписи вкл.", "Labels on"],
	"NAV_LABELS_OFF": ["Подписи выкл.", "Labels off"],
	"NAV_GUIDE_ON": ["Коридор вкл.", "Guide on"],
	"NAV_GUIDE_OFF": ["Коридор выкл.", "Guide off"],
	"NAV_SHIPS_ON": ["Корабли вкл.", "Ships on"],
	"NAV_SHIPS_OFF": ["Корабли выкл.", "Ships off"],
	"SCANNER": ["Сканер", "Scanner"],
	"SCANNER_NOSE": ["НОС", "BOW"],
	"SCANNER_RANGE": ["%d м", "%d m"],
	"SCANNER_NONE": ["В пределах сканера нет кораблей.", "No ships in scanner range."],
	"SCANNER_PICK": ["Выберите контакт в списке.", "Select a contact."],
	"SCANNER_ALTITUDE": ["%d м · высота %+.0f м", "%d m · altitude %+.0f m"],
	"SCANNER_MAPPER": ["Досье доступно с радаром-картографом.", "Fit a radar mapper to read the dossier."],
	"SCANNER_LOCK": ["Взять на прицел", "Lock target"],
	"SCANNER_CLEAR": ["Снять захват", "Clear lock"],
	"SCANNER_LOCKED": ["Захват · %s", "Lock · %s"],
	"SCANNER_DETAIL": ["%s · %.1f м/с · корпус %.0f%%", "%s · %.1f m/s · hull %.0f%%"],
	"SCANNER_RAIDER": ["Рейдер", "Raider"],
	"SCANNER_CONVOY": ["Конвой", "Convoy"],
	"SCANNER_TRADER": ["Транспорт", "Transport"],
	"SCANNER_PATROL": ["Патруль", "Patrol"],
	"SCANNER_RELAY": ["Ретранслятор", "Relay"],
	"SCANNER_SHIP": ["Судно", "Vessel"],
}

static var _installed := false
static var _language := 0


static func set_language(language: int) -> void:
	if not _installed:
		for index in range(2):
			var catalogue := Translation.new()
			catalogue.locale = "ru" if index == 0 else "en"
			for key: String in MESSAGES:
				catalogue.add_message(key, MESSAGES[key][index])
			TranslationServer.add_translation(catalogue)
		_installed = true
	_language = clampi(language, 0, 1)
	var locale := "ru" if _language == 0 else "en"
	if TranslationServer.get_locale() != locale:
		TranslationServer.set_locale(locale)


static func text(key: String) -> String:
	if not _installed:
		set_language(_language)
	return TranslationServer.translate(key)


static func field(entry: Dictionary, key: String) -> String:
	var fallback := str(entry.get(key, ""))
	return str(entry.get(key + "_en", fallback)) if _language == 1 else fallback

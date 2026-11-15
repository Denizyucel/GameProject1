# Görev kaydı: açık ve biten görevleri tutar, her değişiklikte changed sinyali gönderir (HUD görev listesini
# günceller). main.gd açılışta "Gorevler" adıyla ekler; görevler QuestLog.active üzerinden her yerden ilerletilir.
# Bir görev: kimlik, başlık, ilerleme / hedef (ör. 2 / 5), bitti mi. Hedef 0 ise sayaçsız görevdir (tek adım).

class_name QuestLog
extends Node

signal changed
signal completed(id: String)

static var active: QuestLog # sahnedeki görev kaydı (yoksa null; ara sahnede yok)

var quests := {} # kimlik → {"title", "progress", "goal", "done"}
var order: Array[String] = [] # görevlerin açılış sırası (listede bu sırayla görünür)


func _enter_tree() -> void:
	active = self


func _exit_tree() -> void:
	if active == self:
		active = null


## Görevi aç (açıksa bir şey yapmaz). goal: kaç adımda biter; 0 = sayaçsız
func start(id: String, title: String, goal := 0) -> void:
	if quests.has(id):
		return
	quests[id] = {"title": title, "progress": 0, "goal": goal, "done": false}
	order.append(id)
	changed.emit()


## Görevi bir adım ilerlet; hedefe varınca biter
func advance(id: String) -> void:
	if not quests.has(id) or quests[id]["done"]:
		return
	quests[id]["progress"] += 1
	if quests[id]["progress"] >= quests[id]["goal"]:
		finish(id)
	else:
		changed.emit()


## Görevin başlığını değiştir (zincir görevlerde bir sonraki adımı anlatmak için)
func retitle(id: String, title: String) -> void:
	if quests.has(id) and not quests[id]["done"]:
		quests[id]["title"] = title
		changed.emit()


func finish(id: String) -> void:
	if not quests.has(id) or quests[id]["done"]:
		return
	quests[id]["done"] = true
	changed.emit()
	completed.emit(id)


func is_open(id: String) -> bool:
	return quests.has(id) and not quests[id]["done"]


func is_done(id: String) -> bool:
	return quests.has(id) and quests[id]["done"]


## HUD için satırlar: [metin, bitti mi]
func lines() -> Array:
	var result := []
	for id in order:
		var quest: Dictionary = quests[id]
		var text: String = quest["title"]
		if quest["goal"] > 0:
			text += "  %d / %d" % [mini(quest["progress"], quest["goal"]), quest["goal"]]
		result.append([text, quest["done"]])
	return result

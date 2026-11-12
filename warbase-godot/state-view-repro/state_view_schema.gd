class_name WBStateViewReproSchema
extends RefCounted

class ProbePlayer extends Colyseus.Schema:
	static func definition() -> Array:
		return [
			Colyseus.Schema.Field.new("name", Colyseus.Schema.STRING),
			Colyseus.Schema.Field.new("publicValue", Colyseus.Schema.STRING),
			Colyseus.Schema.Field.new("ownerSecret", Colyseus.Schema.STRING),
		]

class RoomState extends Colyseus.Schema:
	static func definition() -> Array:
		return [
			Colyseus.Schema.Field.new("players", Colyseus.Schema.MAP, ProbePlayer),
			Colyseus.Schema.Field.new("protocol", Colyseus.Schema.STRING),
		]

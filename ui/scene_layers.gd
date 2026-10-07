extends RefCounted

enum Depth { FAR, MIDDLE, NEAR }

class DrawingLayer extends Node2D:
	var renderer: Callable
	var depth: int

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		renderer.call(self, depth)

static func install(scene: Node2D, renderer: Callable) -> void:
	for depth in 3:
		var layer := DrawingLayer.new()
		layer.name = ["FarLayer", "MiddleLayer", "NearLayer"][depth]
		layer.depth = depth
		layer.renderer = renderer
		layer.z_index = [-30, -20, -10][depth]
		scene.add_child(layer)

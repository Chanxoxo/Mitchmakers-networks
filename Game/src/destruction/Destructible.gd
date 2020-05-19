extends Node2D

export var viewport_destruction_nodepath : NodePath
export var collision_holder_node_path : NodePath

var world_size : Vector2

var collision_holder : Node2D
var _to_cull : Array

var _image_republish_texture := ImageTexture.new()

var _parent_material : Material
var _destruction_threads := Array()
var _viewport_destruction_node : Node

func _ready():
	add_to_group("destructibles")
	
	collision_holder = get_node(collision_holder_node_path)
	world_size = (get_parent() as Sprite).get_rect().size
	_parent_material = get_parent().material
	_viewport_destruction_node = get_node(viewport_destruction_nodepath)
	
	# Match our destruction viewport to the regular viewport.
	# If we didn't do this we'd need to either hardcode a viewport size
	$Viewport.set_size(get_viewport_rect().size)
	
	# Passing 0 to duplicate, as we don't want to duplicate scripts/signals etc
	# We don't use 8 since we're going to delete our duplicate nodes after first render anyway
	var dup = get_parent().duplicate(0) as Node2D
	_to_cull.append(dup)
	# Shrink to match the ratio of our destruction viewport
	dup.scale = _world_to_viewport_scale(dup.scale)
	# Then reposition, so we're in the right spot
	dup.position = _world_to_viewport(dup.position)

	# Add to the viewport, so that our destructible viewport has our starting point
	$Viewport.add_child(dup)
	
	# Force the destruction texture rebuild
	rebuild_texture()
	$CullTimer.start()
	
	rebuild_collisions_from_image()


func _exit_tree():
	for thread in _destruction_threads:
		thread.wait_to_finish()


func destroy(position : Vector2, radius : float):
	var viewport_position = _world_to_viewport(position)
	
	# Collision rebuild thread!
	var thread := Thread.new()
	var error = thread.start(self, "rebuild_collisions_from_geometry", [position, radius])
	if error != OK:
		print("Error creating destruction thread: ", error)
	_destruction_threads.push_back(thread)
	
	# This stuff does the bad-idea rebuild using images
	_viewport_destruction_node.reposition(viewport_position, radius / 2)

	rebuild_texture()

	# Wait until all viewports have re-rendered before pushing our viewport to the destruction shader.
	yield(VisualServer, "frame_post_draw")
	republish_sprite()


func _cull_foreground_duplicates():
	for dup in _to_cull:
		dup.queue_free()
	_to_cull = Array()


func _process(_delta):
	# Debug
	OS.set_window_title(" | fps: " + str(Engine.get_frames_per_second()))


func rebuild_texture():
	# Force re-render to update our target viewport
	$Viewport.render_target_update_mode = Viewport.UPDATE_ONCE


# Improved collision rebuilding!
func rebuild_collisions_from_geometry(arguments : Array):
	var position : Vector2 = arguments[0]
	var radius : float = arguments[1]

	var nb_points = 8
	var points_arc = PoolVector2Array()
	points_arc.push_back(position)
	
	for i in range(nb_points + 1):
		var angle_point = deg2rad(i * 360 / nb_points)
		points_arc.push_back(position + Vector2(cos(angle_point), sin(angle_point)) * radius * 2)

	for collision_polygon in collision_holder.get_children():
		var clipped_polygons = Geometry.clip_polygons_2d(collision_polygon.polygon, points_arc)
		
		# If the clip failed, we're almost certainly trying to delete the last few
		# remnants of an 'island'
		if clipped_polygons.size() == 0:
			collision_polygon.queue_free()
		
		for i in range(clipped_polygons.size()):
			var clipped_collision = clipped_polygons[i]
			
			# Ignore clipped polygons that are too small to actually create
			# These are awkward single or two-point floaters.
			# If we can't at least make a triangle from it, we don't care about it
			if clipped_collision.size() < 3:
				continue
			
			# God knows why, but creating a PoolVector2Array from the Geometry Array fails
			# ie, PoolVector2Array(Geometry.clip_polygons_2d(points_arc, collision_polygon.polygon))
			# Doesn't give you a PoolVector2Array with all the points!
			var points = PoolVector2Array()
			# So we'll iterate through and manually copy them ourselves :(
			for point in clipped_collision:
				points.push_back(point)
			
			# Update the existing polygon if possible
			if i == 0:
				collision_polygon.call_deferred("set", "polygon", points)
				
			else:
				# Otherwise, our clipping created independent islands!
				# We'll need to add a CollisionPolygon for each of them
				var collider := CollisionPolygon2D.new()
				collider.polygon = points
				collision_holder.call_deferred("add_child", collider)


func rebuild_collisions_from_image():
	# Wait for all viewports to re-render before we build our image
	yield(VisualServer, "frame_post_draw")
	
	# Create bitmap from the Viewport (which projects into our sprite)
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha($Sprite.texture.get_data())
	
	# DEBUG:
	#$Sprite.get_texture().get_data().save_png("res://screenshots/debug.png")
	#print("Saved")

	# This will generate polygons for the given coordinate rectangle within the bitmap
	# In our case, our given coordinates are the entire image.
	var polygons = bitmap.opaque_to_polygons(Rect2(Vector2(0,0), bitmap.get_size()))
	
	# Delete all previous polygons
	for child in collision_holder.get_children():
		child.queue_free()
	
	# Now create a collision polygon for each polygon returned
	# For the most part there will probably only be one.... unless you have islands
	# And we'll add them as children of our DynamicTexture
	for polygon in polygons:
		var collider := CollisionPolygon2D.new()

		# Remap our points from the dynamic texture (which is small)
		# To our world, which might be more than a screen wide.
		# Depending on the size of our dynamic texture viewport, we'll get a different resolution
		# of collidability.
		# This can be much less fine-grained than our display!
		var newpoints := Array()
		for point in polygon:
			# Remap to world position
			newpoints.push_back(_viewport_to_world(point))
		collider.polygon = newpoints # Scaling example. Otherwise just use polygon
		collision_holder.add_child(collider)
	
	# Here's where viewport_destruction_nodepaths get wild
	# We need to multiply the foreground sprite against our destruction sprite
	# So that the foreground only shows where our destruction sprite is not alpha
	republish_sprite()


func republish_sprite() -> void:
	# Assume the image has changed, so we'll need to update our ImageTexture
	_image_republish_texture.create_from_image($Sprite.texture.get_data())

	# If our parent has the proper src/destruction/parent_material shader
	# We can set our destruction_mask parameter against it, 
	# which will carve out our destruction map!
	if _parent_material != null:
		_parent_material.set_shader_param("destruction_mask", _image_republish_texture)


func _viewport_to_world(var point : Vector2) -> Vector2:
	var dynamic_texture_size = $Viewport.get_size()
	return Vector2(
				((point.x + get_viewport_rect().position.x) / dynamic_texture_size.x) * world_size.x,
				((point.y + get_viewport_rect().position.y) / dynamic_texture_size.y) * world_size.y
			)


func _world_to_viewport(var point : Vector2) -> Vector2:
	var dynamic_texture_size = $Viewport.get_size()
	return Vector2(
				(point.x / world_size.x) * dynamic_texture_size.x + get_viewport_rect().position.x,
				(point.y / world_size.y) * dynamic_texture_size.y + get_viewport_rect().position.y
			)


func _world_to_viewport_scale(var original_scale : Vector2) -> Vector2:
	var dynamic_texture_size : Vector2 = $Viewport.get_size()
	var x_scale = ((100.0 / world_size.x) * dynamic_texture_size.x) / 100.0
	var y_scale = ((100.0 / world_size.y) * dynamic_texture_size.y) / 100.0
	return Vector2(original_scale.x * x_scale, original_scale.y * y_scale)

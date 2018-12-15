extends "res://scenes/base_world.gd"

func init_world(world_construct):
	.init_world(world_construct)
	
	$Car/Driver.remote_path = world_construct.get_node("Player").get_path()


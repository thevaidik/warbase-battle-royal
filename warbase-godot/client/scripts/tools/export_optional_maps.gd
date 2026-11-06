extends SceneTree
## Pack original map scenes and their imported dependencies for on-demand Web loading.
var _files := {}
var _uids := {}
func _initialize() -> void: call_deferred("run")
func collect(path: String) -> void:
	if _files.has(path):return
	_files[path]=true
	var uid:=ResourceLoader.get_resource_uid(path)
	if uid>=0:_uids[ResourceUID.id_to_text(uid)]=path
	if FileAccess.file_exists(path+".import"):
		_files.erase(path)
		_files[path+".import"]=true
		var config:=ConfigFile.new();assert(config.load(path+".import")==OK)
		for imported: String in config.get_value("deps","dest_files",[]):_files[imported]=true
		if config.has_section_key("remap","uid"):_uids[str(config.get_value("remap","uid"))]=path
	for dependency: String in ResourceLoader.get_dependencies(path):
		var pieces:=dependency.split("::")
		var resource_path:=String(pieces[pieces.size()-1])
		if not resource_path.begins_with("res://"):
			var id:=ResourceUID.text_to_id(String(pieces[0]))
			if ResourceUID.has_id(id):resource_path=ResourceUID.get_id_path(id)
		assert(resource_path.begins_with("res://"),"Unresolved dependency: "+dependency)
		collect(resource_path)
func run() -> void:
	var directory:=ProjectSettings.globalize_path("res://candidate-web-dist")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("output="):directory=argument.trim_prefix("output=")
	assert(DirAccess.make_dir_recursive_absolute(directory)==OK)
	var manifest:={}
	var maps:Dictionary={"football":"res://assets/maps/football.glb"}
	var authoring:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/restored-map-authoring.json"))
	for id:String in authoring:maps[id]="res://assets/maps/restored/"+id+".scn"
	for map_id:String in maps:
		_files.clear();_uids.clear()
		var scene_path:String=maps[map_id]
		collect(scene_path)
		if map_id=="football":
			collect("res://assets/maps/football_0.png")
			collect("res://assets/maps/football_backfaces.res")
			_files["res://assets/maps/Football-LICENSE.txt"]=true
		var temporary:=directory.path_join("map-"+map_id+".pck")
		var packer:=PCKPacker.new();assert(packer.pck_start(temporary)==OK)
		var paths:Array=_files.keys();paths.sort()
		for path:String in paths:
			assert(packer.add_file(path,ProjectSettings.globalize_path(path))==OK,"Missing map dependency: "+path)
		assert(packer.flush()==OK)
		var digest:=FileAccess.get_sha256(temporary)
		var filename:="map-"+map_id+"-"+digest.left(16)+".pck"
		var destination:=directory.path_join(filename)
		if FileAccess.file_exists(destination):DirAccess.remove_absolute(temporary)
		else:assert(DirAccess.rename_absolute(temporary,destination)==OK)
		var file:=FileAccess.open(destination,FileAccess.READ)
		manifest[map_id]={"file":filename,"sha256":digest,"bytes":file.get_length(),"uids":_uids.duplicate(),"root":scene_path}
		print("OPTIONAL_MAP_PACK ",map_id," bytes=",file.get_length()," resources=",paths.size())
	var output:=FileAccess.open(directory.path_join("optional-maps.json"),FileAccess.WRITE);output.store_string(JSON.stringify(manifest))
	quit()

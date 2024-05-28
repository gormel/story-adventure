const ecs = @import("zig-ecs");

pub const EditorScene = struct { };
pub const EditorObject = struct { };
pub const ListedEditorObject = struct { button_entity: ecs.Entity };
pub const SelectedEditorObject = struct {};
pub const DisplayedOnComponentInstancePanel = struct {};

pub const ComponentPanel = struct {};
pub const ComponentPanelReady = struct {};
pub const GameObjectPanel = struct {};
pub const GameObjectPanelReady = struct {};
pub const GameObjectButton = struct { entity: ecs.Entity };
pub const NewEntityButton = struct {};
pub const NewEntityButtonReady = struct {};
pub const ComponentInstancePanel = struct {};
pub const ComponentInstancePanelReady = struct {};
pub const ComponentInstanceButton = struct { entity: ecs.Entity, component_idx: usize };
pub const EditComponentWindow = struct {};
pub const EditComponentWindowReady = struct { list_entity: ecs.Entity };
pub const EditComponentWindowRow = struct {};
pub const EditComponentWindowRowResource = struct { memory: []const []const u8 };
pub const EditComponentFieldInput = struct { field_offset: i32 };
pub const SetEditingComponent = struct { entity: ecs.Entity, source_btn_entity: ecs.Entity, component_idx: usize };
pub const EditingComponent = struct { entity: ecs.Entity, component_idx: usize };
pub const ConfirmEditComponentButton = struct { window_entity: ecs.Entity };
pub const DeleteEditComponentButton = struct { window_entity: ecs.Entity, source_btn_entity: ecs.Entity };
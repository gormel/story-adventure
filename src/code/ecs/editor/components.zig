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
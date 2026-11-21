# Godot scene authoring

- Author stable interfaces and node hierarchies in editable `.tscn` scenes. Save layout, styling, default values and static signal connections in the scene.
- Reuse components by instancing `PackedScene` resources. Keep shared themes and styles in `.tres` resources.
- Keep GDScript focused on behavior, state and runtime orchestration. Instantiate scenes from code when the user or runtime data determines what appears or how many instances are needed.
- Create UI nodes directly in GDScript only when their structure genuinely depends on runtime data and scene instancing cannot reasonably express it.

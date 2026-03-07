# Project Notes

## UI Quality
- Prefer native-feeling macOS visuals over flat placeholder blocks.
- Avoid large undifferentiated gray surfaces unless they are intentionally subtle and layered.
- Use `Material`, system background colors, and restrained gradients before inventing custom heavy styling.
- Keep padding tight and proportional to the window size.
- Default to calm contrast, clear typography, and a single accent color instead of noisy palettes.
- When refining UI, improve hierarchy, spacing, color, and window chrome together rather than in isolation.

## Style Reference (DropZoneView)
- **Materials:** Use `.ultraThinMaterial` for primary surfaces with a subtle shadow (`color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 10, y: 4`) for depth.
- **Colors:** Prefer semantic colors like `Color.accentColor`, `.primary`, and `.secondary`. Avoid hardcoded RGB values.
- **Borders:** Use `.strokeBorder` with `Color.primary.opacity(0.1)` and subtle dashing (`dash: [6, 4]`) for interactive zones.
- **Iconography:** Use SF Symbols with `.hierarchical` rendering and `symbolEffect` (e.g., `.bounce`, `.variableColor`) to provide interactive feedback.
- **Components:** Wrap metadata or secondary info in capsule tags with `.quaternary.opacity(0.5)` backgrounds for a clean, modern layout.

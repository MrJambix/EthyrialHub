-- ═══════════════════════════════════════════════════════════════════════════
--  WHITELISTED ADDON API  —  MENU (ImGui Settings Panel)
--  Namespace: core.menu.*
--  Category:  Configuration Widgets, Keybinds, Settings UI
-- ═══════════════════════════════════════════════════════════════════════════
--
--  Build addon settings panels using ImGui widgets. These render inside
--  the Hub's settings menu when the user opens the plugin config tab.
--  Register your menu drawing via core.register_on_render_menu_callback().
--
-- ───────────────────────────────────────────────────────────────────────────

---@class MenuAPI

--- Add a checkbox widget.
---@param label string  unique label
---@param default boolean
---@return boolean current_value
-- core.menu.checkbox(label, default)

--- Add an integer slider.
---@param label string
---@param min number
---@param max number
---@param default number
---@return number current_value
-- core.menu.slider_int(label, min, max, default)

--- Add a float slider.
---@param label string
---@param min number
---@param max number
---@param default number
---@return number current_value
-- core.menu.slider_float(label, min, max, default)

--- Add a combobox / dropdown.
---@param label string
---@param items string  pipe-separated items "A|B|C"
---@param default number  0-based index
---@return number selected_index
-- core.menu.combobox(label, items, default)

--- Begin a collapsible tree node.
---@param label string
---@return boolean is_open
-- core.menu.tree_node(label)

--- Add a clickable button.
---@param label string
---@return boolean clicked
-- core.menu.button(label)

--- Read a checkbox value without rendering it.
---@param label string
---@return boolean value
-- core.menu.get_checkbox(label)

--- Programmatically set a checkbox value.
---@param label string
---@param value boolean
-- core.menu.set_checkbox(label, value)

--- Read a float slider value without rendering it.
---@param label string
---@return number value
-- core.menu.get_slider_float(label)

--- Add a keybind widget.
---@param label string
---@param default_key number  virtual key code
---@return number current_key
-- core.menu.keybind(label, default_key)

--- Is the keybind key currently held down?
---@param label string
---@return boolean
-- core.menu.is_keybind_active(label)

--- Is any key currently pressed?
---@param key number  virtual key code
---@return boolean
-- core.menu.is_key_pressed(key)

--- Was the key just pressed this frame (edge-triggered)?
---@param key number  virtual key code
---@return boolean
-- core.menu.is_key_just_pressed(key)

-- ┌─────────────────────────────────────────────────────────────┐
-- │  core.imgui.*  —  Direct ImGui Widgets (Advanced)          │
-- └─────────────────────────────────────────────────────────────┘
--
--  For custom floating windows outside the settings panel.
--  Render these from core.register_on_render_callback().
--

--- Begin a new ImGui window.
---@param title string
---@return boolean is_open
-- core.imgui.begin_window(title)

--- End the current ImGui window.
-- core.imgui.end_window()

--- Draw text.
---@param text string
-- core.imgui.text(text)

--- Draw colored text.
---@param r number 0-1 @param g number 0-1 @param b number 0-1 @param a number 0-1
---@param text string
-- core.imgui.text_colored(r, g, b, a, text)

--- Add a checkbox.
---@param label string
---@param checked boolean
---@return boolean new_value, boolean changed
-- core.imgui.checkbox(label, checked)

--- Add a button.
---@param label string
---@return boolean clicked
-- core.imgui.button(label)

--- Add an integer slider.
---@param label string
---@param value number
---@param min number
---@param max number
---@return number new_value, boolean changed
-- core.imgui.slider_int(label, value, min, max)

--- Add a float slider.
---@param label string
---@param value number
---@param min number
---@param max number
---@return number new_value, boolean changed
-- core.imgui.slider_float(label, value, min, max)

--- Add a color picker (RGB).
---@param label string
---@param r number @param g number @param b number
---@return number r, number g, number b, boolean changed
-- core.imgui.color_edit3(label, r, g, b)

--- Add a color picker (RGBA).
---@param label string
---@param r number @param g number @param b number @param a number
---@return number r, number g, number b, number a, boolean changed
-- core.imgui.color_edit4(label, r, g, b, a)

--- Add a horizontal separator line.
-- core.imgui.separator()

--- Place next widget on the same line.
-- core.imgui.same_line()

--- Add vertical spacing.
-- core.imgui.spacing()

--- Set size of the next window.
---@param w number @param h number
-- core.imgui.set_next_window_size(w, h)

--- Set position of the next window.
---@param x number @param y number
-- core.imgui.set_next_window_pos(x, y)

--- Add a text input field.
---@param label string
---@param text string
---@return string new_text, boolean changed
-- core.imgui.input_text(label, text)

--- Add a combo dropdown.
---@param label string
---@param current number  0-based index
---@param items string  null-separated items
---@return number new_index, boolean changed
-- core.imgui.combo(label, current, items)

--- Add a progress bar.
---@param fraction number  0.0 – 1.0
---@param text? string  overlay text
-- core.imgui.progress_bar(fraction, text)

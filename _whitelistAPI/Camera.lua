-- ═══════════════════════════════════════════════════════════════════════════
--  WHITELISTED ADDON API  —  CAMERA
--  Namespace: core.camera.*
--  Category:  Camera Position, Rotation, Zoom
-- ═══════════════════════════════════════════════════════════════════════════
--
--  Read and control camera distance, angle, pitch, and zoom limits.
--
-- ───────────────────────────────────────────────────────────────────────────

---@class CameraAPI

--- Get raw camera data "x,y,z,dist,angle,pitch".
---@return string csv
-- core.camera.get()

--- Get parsed camera table.
---@return table cam  {x, y, z, distance, angle, pitch}
-- core.camera.get_parsed()

--- Get camera distance from player.
---@return number distance
-- core.camera.distance()

--- Get camera horizontal angle (rotation, radians).
---@return number angle
-- core.camera.angle()

--- Get camera vertical pitch (radians).
---@return number pitch
-- core.camera.pitch()



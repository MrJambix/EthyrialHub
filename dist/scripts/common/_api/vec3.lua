--[[
╔══════════════════════════════════════════════════════════════╗
║                    Vec3 — 3D Vector Library                   ║
║                                                              ║
║  Pure-Lua 3D vector type with full linear algebra support.   ║
║  Mirrors the C++ Ethyrial::Vec3 in api/vec3.h and extends   ║
║  it with rotation, projection, and angle utilities.          ║
║                                                              ║
║  Usage:                                                      ║
║    local Vec3 = require("common/_api/vec3")                  ║
║    local a = Vec3(1, 2, 3)                                   ║
║    local b = Vec3(4, 5, 6)                                   ║
║    print(a + b)          -- Vec3(5, 7, 9)                    ║
║    print(a:dot(b))       -- 32                               ║
║    print(a:cross(b))     -- Vec3(-3, 6, -3)                  ║
║    print(a:normalized()) -- unit vector                      ║
║                                                              ║
║  Coordinate system (matches game engine):                    ║
║    X = right,  Y = up,  Z = forward                         ║
║    Yaw 0° = +Z (north), rotates clockwise in XZ plane       ║
╚══════════════════════════════════════════════════════════════╝
]]

---@class Vec3
---@field x number
---@field y number
---@field z number
local Vec3 = {}
Vec3.__index = Vec3

local sqrt  = math.sqrt
local sin   = math.sin
local cos   = math.cos
local atan2 = math.atan2 or math.atan
local acos  = math.acos
local abs   = math.abs
local floor = math.floor
local pi    = math.pi
local EPSILON = 1e-6

-- ═══════════════════════════════════════════════════════════════
--  Construction
-- ═══════════════════════════════════════════════════════════════

---@param x number|table|nil  X component, or {x,y,z} table
---@param y number|nil        Y component
---@param z number|nil        Z component
---@return Vec3
function Vec3.new(x, y, z)
    if type(x) == "table" then
        return setmetatable({ x = x.x or x[1] or 0, y = x.y or x[2] or 0, z = x.z or x[3] or 0 }, Vec3)
    end
    return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, Vec3)
end

setmetatable(Vec3, {
    __call = function(_, x, y, z) return Vec3.new(x, y, z) end
})

function Vec3.zero()    return Vec3.new(0, 0, 0) end
function Vec3.one()     return Vec3.new(1, 1, 1) end
function Vec3.up()      return Vec3.new(0, 1, 0) end
function Vec3.down()    return Vec3.new(0, -1, 0) end
function Vec3.forward() return Vec3.new(0, 0, 1) end
function Vec3.back()    return Vec3.new(0, 0, -1) end
function Vec3.right()   return Vec3.new(1, 0, 0) end
function Vec3.left()    return Vec3.new(-1, 0, 0) end

--- Build a direction vector from yaw (horizontal angle) and pitch (vertical).
--- Yaw 0 = +Z, rotates clockwise. Pitch 0 = horizontal, positive = up.
--- Both angles in degrees.
---@param yaw_deg number
---@param pitch_deg number|nil  Defaults to 0 (horizontal)
---@return Vec3  Unit direction vector
function Vec3.from_angles(yaw_deg, pitch_deg)
    local yaw   = math.rad(yaw_deg)
    local pitch = math.rad(pitch_deg or 0)
    local cp = cos(pitch)
    return Vec3.new(
        sin(yaw) * cp,
        sin(pitch),
        cos(yaw) * cp
    )
end

--- Build a flat (XZ plane) direction vector from a yaw angle in degrees.
---@param yaw_deg number
---@return Vec3  Unit vector on the XZ plane (y=0)
function Vec3.from_yaw(yaw_deg)
    local yaw = math.rad(yaw_deg)
    return Vec3.new(sin(yaw), 0, cos(yaw))
end

-- ═══════════════════════════════════════════════════════════════
--  Arithmetic metamethods
--
--  These implement the vector space axioms from linear algebra:
--    - Closure under addition and scalar multiplication
--    - Associativity, commutativity of addition
--    - Distributivity of scalar multiplication
-- ═══════════════════════════════════════════════════════════════

function Vec3.__add(a, b)
    return Vec3.new(a.x + b.x, a.y + b.y, a.z + b.z)
end

function Vec3.__sub(a, b)
    return Vec3.new(a.x - b.x, a.y - b.y, a.z - b.z)
end

function Vec3.__mul(a, b)
    if type(a) == "number" then
        return Vec3.new(a * b.x, a * b.y, a * b.z)
    elseif type(b) == "number" then
        return Vec3.new(a.x * b, a.y * b, a.z * b)
    end
    return Vec3.new(a.x * b.x, a.y * b.y, a.z * b.z)
end

function Vec3.__div(a, b)
    if type(b) == "number" then
        return Vec3.new(a.x / b, a.y / b, a.z / b)
    end
    return Vec3.new(a.x / b.x, a.y / b.y, a.z / b.z)
end

function Vec3.__unm(a)
    return Vec3.new(-a.x, -a.y, -a.z)
end

function Vec3.__eq(a, b)
    return abs(a.x - b.x) < EPSILON and abs(a.y - b.y) < EPSILON and abs(a.z - b.z) < EPSILON
end

function Vec3.__tostring(v)
    return string.format("Vec3(%.3f, %.3f, %.3f)", v.x, v.y, v.z)
end

function Vec3.__len(v)
    return v:length()
end

-- ═══════════════════════════════════════════════════════════════
--  Core linear algebra operations
-- ═══════════════════════════════════════════════════════════════

--- Inner product (dot product).
--- Geometrically: a . b = |a||b|cos(theta)
--- Used for projection, angle calculation, and testing orthogonality.
---@param b Vec3
---@return number
function Vec3:dot(b)
    return self.x * b.x + self.y * b.y + self.z * b.z
end

--- Cross product.  a x b produces a vector perpendicular to both a and b.
--- |a x b| = |a||b|sin(theta).  Follows right-hand rule.
---@param b Vec3
---@return Vec3
function Vec3:cross(b)
    return Vec3.new(
        self.y * b.z - self.z * b.y,
        self.z * b.x - self.x * b.z,
        self.x * b.y - self.y * b.x
    )
end

--- Squared length (avoids sqrt — use for comparisons).
---@return number
function Vec3:length_sq()
    return self.x * self.x + self.y * self.y + self.z * self.z
end

--- Euclidean length (L2 norm): ||v|| = sqrt(x^2 + y^2 + z^2)
---@return number
function Vec3:length()
    return sqrt(self:length_sq())
end

--- 2D length in the XZ plane (ignores Y / height).
---@return number
function Vec3:length_2d()
    return sqrt(self.x * self.x + self.z * self.z)
end

--- Unit vector (same direction, length 1).
--- Returns zero vector if length is near zero.
---@return Vec3
function Vec3:normalized()
    local len = self:length()
    if len < EPSILON then return Vec3.zero() end
    return self / len
end

--- Normalize in the XZ plane only, preserving Y.
---@return Vec3
function Vec3:normalized_2d()
    local len = self:length_2d()
    if len < EPSILON then return Vec3.new(0, self.y, 0) end
    return Vec3.new(self.x / len, self.y, self.z / len)
end

--- Distance to another point.
---@param b Vec3|table
---@return number
function Vec3:distance_to(b)
    return (self - Vec3.new(b)):length()
end

--- 2D distance (XZ plane) to another point.
---@param b Vec3|table
---@return number
function Vec3:distance_to_2d(b)
    local dx = self.x - (b.x or b[1] or 0)
    local dz = self.z - (b.z or b[3] or 0)
    return sqrt(dx * dx + dz * dz)
end

-- ═══════════════════════════════════════════════════════════════
--  Interpolation & projection
-- ═══════════════════════════════════════════════════════════════

--- Linear interpolation: a + t*(b - a)
---@param b Vec3
---@param t number  0..1
---@return Vec3
function Vec3:lerp(b, t)
    return self + (b - self) * t
end

--- Scalar projection of self onto direction vector b.
--- Returns signed length of the shadow of self on b.
---@param b Vec3
---@return number
function Vec3:scalar_project(b)
    local blen = b:length()
    if blen < EPSILON then return 0 end
    return self:dot(b) / blen
end

--- Vector projection of self onto b.
--- The component of self that lies along b.
---@param b Vec3
---@return Vec3
function Vec3:project(b)
    local d = b:dot(b)
    if d < EPSILON then return Vec3.zero() end
    return b * (self:dot(b) / d)
end

--- Reflect self across a surface with the given normal.
---@param normal Vec3  Surface normal (should be unit length)
---@return Vec3
function Vec3:reflect(normal)
    return self - normal * (2 * self:dot(normal))
end

-- ═══════════════════════════════════════════════════════════════
--  Angles & rotation
-- ═══════════════════════════════════════════════════════════════

--- Angle between two vectors in radians (0..pi).
---@param b Vec3
---@return number  Radians
function Vec3:angle_to(b)
    local la, lb = self:length(), b:length()
    if la < EPSILON or lb < EPSILON then return 0 end
    local d = self:dot(b) / (la * lb)
    d = math.max(-1, math.min(1, d))
    return acos(d)
end

--- Angle between two vectors in degrees.
---@param b Vec3
---@return number  Degrees
function Vec3:angle_to_deg(b)
    return math.deg(self:angle_to(b))
end

--- Yaw angle (horizontal heading) of this vector in degrees.
--- 0 = +Z, 90 = +X, 180 = -Z, 270 = -X.
---@return number  0..360
function Vec3:yaw()
    local a = math.deg(atan2(self.x, self.z))
    if a < 0 then a = a + 360 end
    return a
end

--- Pitch angle (vertical tilt) of this vector in degrees.
--- 0 = horizontal, positive = looking up.
---@return number  -90..90
function Vec3:pitch()
    local flat = self:length_2d()
    return math.deg(atan2(self.y, flat))
end

--- Rotate this vector around the Y axis by the given angle in degrees.
--- Positive angle = clockwise when viewed from above (matches game yaw).
---@param deg number
---@return Vec3
function Vec3:rotate_y(deg)
    local rad = math.rad(deg)
    local c, s = cos(rad), sin(rad)
    return Vec3.new(
        self.x * c + self.z * s,
        self.y,
       -self.x * s + self.z * c
    )
end

--- Rotate this vector around an arbitrary axis by angle_deg degrees.
--- Uses Rodrigues' rotation formula.
---@param axis Vec3   Rotation axis (will be normalized)
---@param angle_deg number
---@return Vec3
function Vec3:rotate_around(axis, angle_deg)
    local k = axis:normalized()
    local rad = math.rad(angle_deg)
    local c, s = cos(rad), sin(rad)
    return self * c + k:cross(self) * s + k * (k:dot(self) * (1 - c))
end

-- ═══════════════════════════════════════════════════════════════
--  Utility
-- ═══════════════════════════════════════════════════════════════

--- Flatten to the XZ plane (set Y = 0).
---@return Vec3
function Vec3:flat()
    return Vec3.new(self.x, 0, self.z)
end

--- Return a copy with Y set to the given value.
---@param y number
---@return Vec3
function Vec3:with_y(y)
    return Vec3.new(self.x, y, self.z)
end

--- Component-wise min.
---@param b Vec3
---@return Vec3
function Vec3:min(b)
    return Vec3.new(math.min(self.x, b.x), math.min(self.y, b.y), math.min(self.z, b.z))
end

--- Component-wise max.
---@param b Vec3
---@return Vec3
function Vec3:max(b)
    return Vec3.new(math.max(self.x, b.x), math.max(self.y, b.y), math.max(self.z, b.z))
end

--- Clamp each component between lo and hi vectors.
---@param lo Vec3
---@param hi Vec3
---@return Vec3
function Vec3:clamp(lo, hi)
    return self:max(lo):min(hi)
end

--- Is this vector approximately zero?
---@return boolean
function Vec3:is_zero()
    return self:length_sq() < EPSILON * EPSILON
end

--- Unpack into three return values.
---@return number, number, number
function Vec3:unpack()
    return self.x, self.y, self.z
end

--- Convert to a plain table (for passing to core APIs).
---@return table  {x=number, y=number, z=number}
function Vec3:to_table()
    return { x = self.x, y = self.y, z = self.z }
end

--- Clone this vector.
---@return Vec3
function Vec3:clone()
    return Vec3.new(self.x, self.y, self.z)
end

return Vec3

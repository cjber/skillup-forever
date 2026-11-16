---@meta

---@class SkillUpDyadic
---@field digits integer[] Little-endian base-65536 nonnegative integer, owned and immutable by convention.
---@field exponent integer Exact binary exponent; zero has empty digits.

---@class SkillUpDyadicArithmetic
---@field Number fun(value: number): SkillUpDyadic
---@field Add fun(a: SkillUpDyadic, b: SkillUpDyadic): SkillUpDyadic
---@field Subtract fun(a: SkillUpDyadic, b: SkillUpDyadic): SkillUpDyadic Nonnegative difference only.
---@field Multiply fun(a: SkillUpDyadic, b: SkillUpDyadic): SkillUpDyadic
---@field Compare fun(a: SkillUpDyadic, b: SkillUpDyadic): integer Exact comparison, -1, 0 or 1.
---@field Bounds fun(value: SkillUpDyadic): number, number Outward enclosure, possibly infinite upper bound.

---@class SkillUpDyadicProducer
---@field Create fun(limbLimit: integer, tick: fun()): SkillUpDyadicArithmetic Exhaustion raises an error for the job's unknown boundary.

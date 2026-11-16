local _, ns = ...
local Dyadic = {}
ns.Dyadic = Dyadic

-- Nonnegative exact binary rationals: little-endian base-2^16 integer times
-- 2^exponent. Each multiply/carry stays below 2^33, exactly representable in Lua.
local BASE = 65536
local MINIMUM = 2 ^ -1074
local EXPONENT_LIMIT = 2 ^ 52 - 1
-- Check BEFORE addition: testing integer-ness after binary64 rounding would
-- already have lost the exponent bit that exact comparison depends on.
local function Exponent(a, b)
	if (b > 0 and a > EXPONENT_LIMIT - b) or (b < 0 and a < -EXPONENT_LIMIT - b) then
		error("exact arithmetic exponent budget exhausted", 0)
	end
	return a + b
end

---@param limbLimit integer
---@param tick fun()
---@return SkillUpDyadicArithmetic
function Dyadic.Create(limbLimit, tick)
	assert(
		type(limbLimit) == "number" and limbLimit >= 1 and limbLimit < math.huge and limbLimit == math.floor(limbLimit)
	)
	assert(type(tick) == "function")
	local function Budget(count)
		if count > limbLimit then
			error("exact arithmetic limb budget exhausted", 0)
		end
		tick()
	end
	---@param digits integer[]
	---@param exponent integer
	---@return SkillUpDyadic
	local function Normalize(digits, exponent)
		while digits[#digits] == 0 do
			digits[#digits] = nil
			tick()
		end
		if #digits == 0 then
			return { digits = {}, exponent = 0 }
		end
		local first = 1
		while digits[first] == 0 do
			first = first + 1
			tick()
		end
		if first > 1 then
			local compact = {}
			for i = first, #digits do
				compact[#compact + 1] = digits[i]
				tick()
			end
			digits, exponent = compact, Exponent(exponent, 16 * (first - 1))
		end
		while digits[1] % 2 == 0 do
			local carry = 0
			for i = #digits, 1, -1 do
				local value = carry * BASE + digits[i]
				digits[i], carry = math.floor(value / 2), value % 2
				tick()
			end
			exponent = Exponent(exponent, 1)
			if digits[#digits] == 0 then
				digits[#digits] = nil
			end
		end
		return { digits = digits, exponent = exponent }
	end
	---@param value number
	---@return SkillUpDyadic
	local function Number(value)
		assert(type(value) == "number" and value >= 0 and value < math.huge, "finite nonnegative number required")
		if value == 0 then
			return { digits = {}, exponent = 0 }
		end
		local fraction, exponent = math.frexp(value)
		local integer, digits = fraction * 2 ^ 53, {}
		while integer > 0 do
			Budget(#digits + 1)
			digits[#digits + 1] = integer % BASE
			integer = math.floor(integer / BASE)
		end
		return Normalize(digits, exponent - 53)
	end
	---@param value SkillUpDyadic
	---@param exponent integer
	---@return integer[]
	local function Align(value, exponent)
		if #value.digits == 0 then
			return {}
		end
		local shift = value.exponent - exponent
		local whole, factor = math.floor(shift / 16), 2 ^ (shift % 16)
		Budget(#value.digits + whole + (factor > 1 and 1 or 0))
		local out, carry = {}, 0
		for i = 1, whole do
			out[i] = 0
			tick()
		end
		for i, digit in ipairs(value.digits) do
			local total = digit * factor + carry
			out[i + whole], carry = total % BASE, math.floor(total / BASE)
			tick()
		end
		if carry > 0 then
			out[#out + 1] = carry
		end
		return out
	end
	---@param a SkillUpDyadic
	---@param b SkillUpDyadic
	---@return integer
	local function Compare(a, b)
		if #a.digits == 0 or #b.digits == 0 then
			return #a.digits == #b.digits and 0 or (#a.digits == 0 and -1 or 1)
		end
		local function Top(value)
			local high, bits = value.digits[#value.digits], 0
			while high > 0 do
				high, bits = math.floor(high / 2), bits + 1
				tick()
			end
			return Exponent(value.exponent, 16 * (#value.digits - 1) + bits)
		end
		local atop, btop = Top(a), Top(b)
		if atop ~= btop then
			return atop < btop and -1 or 1
		end
		local exponent = math.min(a.exponent, b.exponent)
		local left, right = Align(a, exponent), Align(b, exponent)
		for i = math.max(#left, #right), 1, -1 do
			local l, r = left[i] or 0, right[i] or 0
			tick()
			if l ~= r then
				return l < r and -1 or 1
			end
		end
		return 0
	end
	---@param a SkillUpDyadic
	---@param b SkillUpDyadic
	---@return SkillUpDyadic
	local function Add(a, b)
		if #a.digits == 0 then
			return b
		elseif #b.digits == 0 then
			return a
		end
		local exponent = math.min(a.exponent, b.exponent)
		local left, right = Align(a, exponent), Align(b, exponent)
		local out, carry = {}, 0
		for i = 1, math.max(#left, #right) do
			local total = (left[i] or 0) + (right[i] or 0) + carry
			Budget(i)
			out[i], carry = total % BASE, math.floor(total / BASE)
		end
		if carry > 0 then
			Budget(#out + 1)
			out[#out + 1] = carry
		end
		return Normalize(out, exponent)
	end
	---@param a SkillUpDyadic
	---@param b SkillUpDyadic
	---@return SkillUpDyadic
	local function Subtract(a, b)
		if #b.digits == 0 then
			return a
		end
		assert(Compare(a, b) >= 0, "nonnegative difference required")
		local exponent = math.min(a.exponent, b.exponent)
		local left, right = Align(a, exponent), Align(b, exponent)
		local out, borrow = {}, 0
		for i = 1, #left do
			local total = left[i] - (right[i] or 0) - borrow
			out[i], borrow = total % BASE, total < 0 and 1 or 0
			tick()
		end
		return Normalize(out, exponent)
	end
	---@param a SkillUpDyadic
	---@param b SkillUpDyadic
	---@return SkillUpDyadic
	local function Multiply(a, b)
		if #a.digits == 0 or #b.digits == 0 then
			return { digits = {}, exponent = 0 }
		end
		Budget(#a.digits + #b.digits)
		local out = {}
		for i, l in ipairs(a.digits) do
			local carry = 0
			for j, r in ipairs(b.digits) do
				local k = i + j - 1
				local total = (out[k] or 0) + l * r + carry
				out[k], carry = total % BASE, math.floor(total / BASE)
				tick()
			end
			out[i + #b.digits] = carry
		end
		return Normalize(out, Exponent(a.exponent, b.exponent))
	end
	---@param value SkillUpDyadic
	---@return number lower
	---@return number upper
	local function Bounds(value)
		local lower, upper = 0, 0
		for i, digit in ipairs(value.digits) do
			if digit > 0 then
				local power = Exponent(value.exponent, 16 * (i - 1))
				if power > 1023 then
					return 0, math.huge
				end
				-- Avoid passing out-of-range C integer exponents to ldexp. The
				-- positive underflow is enclosed by the minimum-subnormal widening.
				-- A base-2^16 digit can contribute 16 bits above its exponent.
				local term = power < -1090 and 0 or math.ldexp(digit, power)
				if term == math.huge then
					return 0, math.huge
				end
				local error = term * 2 ^ -50 + MINIMUM
				local l, u = lower + math.max(0, term - error), upper + term + error
				lower = math.max(0, l - (l * 2 ^ -50 + MINIMUM))
				upper = u + (u * 2 ^ -50 + MINIMUM)
			end
			tick()
		end
		return lower, upper
	end
	return { Number = Number, Add = Add, Subtract = Subtract, Multiply = Multiply, Compare = Compare, Bounds = Bounds }
end

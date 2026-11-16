local ns = {}
assert(loadfile("Core/Dyadic.lua"))("SkillUpForever", ns)
local checks, work = 0, 0
local function Check(value, why)
	checks = checks + 1
	assert(value, why)
end
local exact = ns.Dyadic.Create(512, function()
	work = work + 1
end)
local n, add, sub, mul, cmp = exact.Number, exact.Add, exact.Subtract, exact.Multiply, exact.Compare
local one, zero, tiny = n(1), n(0), n(2 ^ -1000)
local sum = add(one, tiny)
Check(cmp(sum, one) == 1, "finite policy arithmetic must preserve 1 + 2^-1000 > 1")
Check(cmp(sub(sum, one), tiny) == 0, "subtraction recovers a distant probability bit")
Check(cmp(mul(sum, sub(one, tiny)), one) == -1, "exact product retains the 2^-2000 difference")
Check(cmp(sub(one, mul(sum, sub(one, tiny))), mul(tiny, tiny)) == 0, "exact cancellation identity")
Check(cmp(add(n(0.1), n(0.2)), n(0.3)) == 1, "input binary64 probabilities remain their exact dyadic values")
local underflow = mul(n(2 ^ -1074), n(0.5))
Check(cmp(underflow, zero) == 1, "positive probability below binary64 range is retained")
local low, high = exact.Bounds(underflow)
Check(low == 0 and high > 0, "publication encloses positive underflow")
low, high = exact.Bounds(sum)
Check(low <= 1 and high > 1, "publication encloses the distant low bit")
low, high = exact.Bounds(zero)
Check(low == 0 and high == 0, "zero publishes exactly")
Check(cmp(mul(zero, sum), zero) == 0 and cmp(add(zero, tiny), tiny) == 0, "zero identities")
for i = 1, 40 do
	local a, b = i * 7919, (41 - i) * 1543
	Check(cmp(add(n(a), n(b)), n(a + b)) == 0, "integer addition")
	Check(cmp(mul(n(a), n(b)), n(a * b)) == 0, "integer multiplication with carries")
	Check(cmp(sub(n(a + b), n(a)), n(b)) == 0, "integer subtraction with borrow")
	local lower, upper = exact.Bounds(mul(n(a), n(b)))
	Check(lower <= a * b and upper >= a * b, "integer outward bounds")
end
Check(cmp(n(2 ^ 1023), n(2 ^ 1022)) == 1, "comparison avoids unnecessary wide alignment")
local overflow = mul(n(2 ^ 1023), n(4))
low, high = exact.Bounds(overflow)
Check(low == 0 and high == math.huge, "unpublishable overflow has a conservative enclosure")
local limited = ns.Dyadic.Create(8, function() end)
local ok, reason = pcall(limited.Add, limited.Number(1), limited.Number(2 ^ -1000))
Check(not ok and reason == "exact arithmetic limb budget exhausted", "limb exhaustion is explicit, never truncation")
ok = pcall(n, -1)
Check(not ok, "negative costs rejected")
ok = pcall(n, 0 / 0)
Check(not ok, "NaN rejected")
ok = pcall(n, math.huge)
Check(not ok, "infinite inputs rejected")
ok = pcall(sub, tiny, one)
Check(not ok, "negative difference rejected")
local stopped = false
local interrupted = ns.Dyadic.Create(512, function()
	if stopped then
		error("cancelled", 0)
	end
end)
stopped = true
ok, reason = pcall(interrupted.Number, 1)
Check(not ok and reason == "cancelled", "arithmetic work remains cancellable")
Check(work > 1000, "limb work is charged to the job")
local exponential = ns.Dyadic.Create(8, function() end)
local descending = exponential.Number(0.5)
local guarded, message = pcall(function()
	for _ = 1, 53 do
		descending = exponential.Multiply(descending, descending)
	end
end)
Check(
	not guarded and message == "exact arithmetic exponent budget exhausted",
	"negative exponent growth must stop before integer rounding"
)
local ascending = exponential.Number(2)
guarded, message = pcall(function()
	for _ = 1, 53 do
		ascending = exponential.Multiply(ascending, ascending)
	end
end)
Check(
	not guarded and message == "exact arithmetic exponent budget exhausted",
	"positive exponent growth must stop before integer rounding"
)
local deep = exponential.Number(0.5)
for _ = 1, 40 do
	deep = exponential.Multiply(deep, deep)
end
low, high = exponential.Bounds(deep)
Check(low == 0 and high > 0, "very small exact exponents avoid ldexp integer conversion overflow")
local subnormalLimb = mul(n(65535 * 2 ^ -1074), n(0.5))
low, high = exact.Bounds(subnormalLimb)
local rounded = (65535 * 2 ^ -1074) * 0.5
Check(low <= rounded and high >= rounded, "multi-bit subnormal limbs must retain their full magnitude")
print("dyadic_spec: " .. checks .. " checks passed")

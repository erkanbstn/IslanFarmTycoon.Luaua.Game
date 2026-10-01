--!strict
return function(rules: any, policy: any)
	for _, value in { 0, -5, 0.5, 0 / 0, math.huge, 1e12 + 1, "10", {}, true } do
		assert(not rules.validAmount(value), "invalid transfer amounts must be rejected")
	end
	assert(rules.validAmount(1) and rules.validAmount(1e12), "amount bounds are inclusive")
	for _, value in { 0, -1, 1.5, 0 / 0, math.huge, "1", {}, 2 ^ 53 + 2 } do
		assert(not rules.validUserId(value), "invalid target ids must be rejected")
	end
	assert(rules.validUserId(11641916529), "large real UserIds are valid")

	local ok, why = rules.check(100, 0, 100)
	assert(ok and why == nil, "sending the whole balance is allowed")
	ok, why = rules.check(100, 0, 101)
	assert(not ok and why ~= nil, "cannot send more than the balance")
	ok, why = rules.check(1e15, rules.CASH_CAP - 5, 6)
	assert(not ok and why ~= nil, "receiver cash cap is enforced")
	ok = rules.check(1e15, rules.CASH_CAP - 5, 5)
	assert(ok, "filling the receiver exactly to the cap is allowed")

	-- Yönetici hedef eylemleri
	for _, action in { "giveCash", "takeCash", "setTargetCash", "inspect", "kickPlayer" } do
		assert(policy.validTargetAction(action), `{action} must be a target action`)
	end
	for _, action in { "setCash", "addCash", "teleport", "", 1, {}, nil } do
		assert(not policy.validTargetAction(action), "self/unknown actions are not target actions")
	end
	assert(
		policy.validTargetUserId(42) and not policy.validTargetUserId(0) and not policy.validTargetUserId("42"),
		"target ids are positive integers"
	)
	print("transfer: amount/target validation, balance and cap rules, admin target actions passed")
end

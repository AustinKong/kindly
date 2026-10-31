extends GdUnitTestSuite

const Buffer = preload("res://utilities/circular_buffer.gd")


func test_wrapped_contents_survive_growth_at_both_ends() -> void:
	var buffer := Buffer.new(3)
	for value in [1, 2, 3]:
		buffer.push_back(value)
	buffer.pop_front()
	buffer.pop_front()
	buffer.push_back(4)
	buffer.push_back(5)
	buffer.push_back(6)
	assert_array(buffer.to_array()).is_equal([3, 4, 5, 6])
	buffer.push_front(2)
	buffer.push_front(1)
	buffer.push_front(0)
	assert_array(buffer.to_array()).is_equal([0, 1, 2, 3, 4, 5, 6])
	assert_int(buffer.pop_back()).is_equal(6)
	assert_int(buffer.pop_front()).is_equal(0)


func test_negative_indices_and_snapshot_storage() -> void:
	var buffer := Buffer.new()
	for value in [1, 2, 3]:
		buffer.push_back(value)
	buffer.set_at(-1, 9)
	var snapshot := buffer.to_array()
	snapshot[0] = 99
	assert_int(buffer.at(-3)).is_equal(1)
	assert_int(buffer.at(-1)).is_equal(9)
	assert_array(buffer.to_array()).is_equal([1, 2, 9])


func test_pop_and_clear_release_references_and_allow_reuse() -> void:
	var buffer := Buffer.new()
	for operation in ["pop_front", "pop_back", "clear"]:
		var marker := RefCounted.new()
		var reference: WeakRef = weakref(marker)
		buffer.push_back(marker)
		marker = null
		buffer.call(operation)
		assert_that(reference.get_ref()).is_null()
	buffer.push_back(null)
	assert_int(buffer.size()).is_equal(1)
	assert_that(buffer.pop_back()).is_null()
	assert_bool(buffer.is_empty()).is_true()


func test_mixed_operations_match_an_array_model() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123456
	for capacity in [1, 3, 8]:
		var buffer := Buffer.new(capacity)
		var model: Array = []
		for iteration in range(200):
			var value := rng.randi_range(-100, 100)
			match rng.randi_range(0, 4):
				0:
					buffer.push_front(value)
					model.push_front(value)
				1:
					buffer.push_back(value)
					model.push_back(value)
				2:
					assert_that(buffer.pop_front()).is_equal(null if model.is_empty() else model.pop_front())
				3:
					assert_that(buffer.pop_back()).is_equal(null if model.is_empty() else model.pop_back())
				4:
					if not model.is_empty():
						buffer.set_at(-1, value)
						model[-1] = value
			assert_array(buffer.to_array()).append_failure_message("capacity=%d, iteration=%d" % [capacity, iteration]).is_equal(model)

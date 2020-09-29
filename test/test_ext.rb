# Core ext methods

class Object < BasicObject
  def stub_ivar(name, value = nil)
    instance_variable_set(name, value)
    yield
    remove_instance_variable(name)
  end

  def get_reset_ivar(name)
    yield
    instance_variable_get(name).tap { remove_instance_variable(name) }
  end
end

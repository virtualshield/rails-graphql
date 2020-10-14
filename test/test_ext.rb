# Core ext methods

class Object < BasicObject
  def stub_ivar(name, value = nil)
    instance_variable_set(name, value)
    yield
    remove_instance_variable(name)
  end

  def stub_cvar(name, value = nil)
    class_variable_set(name, value)
    yield
    remove_class_variable(name)
  end

  def stub_const(name, value)
    if (preset = const_defined?(name))
      old_value = const_get(name)
      remove_const(name)
    end

    const_set(name, value)
    yield
    remove_const(name)

    const_set(name, old_value) if preset
  end

  def get_reset_ivar(name, *extra, &block)
    instance_variable_set(name, extra.first) if extra.any?
    instance_exec(&block)

    instance_variable_get(name).tap do
      remove_instance_variable(name) if instance_variable_defined?(name)
    end
  end

  def get_reset_cvar(name, *extra, &block)
    class_variable_set(name, extra.first) if extra.any?
    instance_exec(&block)

    class_variable_get(name).tap do
      remove_class_variable(name) if instance_variable_defined?(name)
    end
  end
end

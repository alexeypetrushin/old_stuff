class ClassType
	class << self
		def initial_value m, e
			nil
#			e.instance_variable_set m.ivname, nil
		end			
		
		def initialize_copy m, e, c
			value_copy = e.instance_variable_get(m.ivname)
			c[m.ivname] = value_copy
		end
		
		def write_back c, e, m
			value = c[m.ivname]
			value.should! :be_a, [NilClass, Module, Class]
			e.instance_variable_set m.ivname, value
		end
		
		def load m, e, storage	
			row = storage[:entities_content][:entity_id => e.entity_id, :name => m.name.to_s]
			
			raise LoadError unless row and row[:class] == "CLASS"			
			value = row[:value]
			value = eval(value, TOPLEVEL_BINDING, __FILE__, __LINE__) if value
			e.instance_variable_set m.ivname, value
		end
		
		def persist c, entity_id, m, storage				
			value = c[m.ivname]
			value = value.name if value
			storage[:entities_content].insert(
														:entity_id => entity_id, 
														:name => m.name.to_s,
														:value => value,
														:class => "CLASS"
			)			
		end
		
		def validate_type value
			value == nil or value.is_a?(Module) or value.is_a?(Class)
		end
	end
end
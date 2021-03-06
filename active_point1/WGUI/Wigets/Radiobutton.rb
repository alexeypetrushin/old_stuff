class Radiobutton < Core::InputWiget
	attr_reader :selected, :values
	
	def initialize values = [], selected = nil
		@values = values
		@selected = selected if selected
	end
	
	def update_value value
		@selected = value
	end
	
	def selected= value				
		return if @selected == value
		@selected = value
		refresh
	end
	
	def values= values		
		return if @values == values
		@values = values
		refresh
	end
end
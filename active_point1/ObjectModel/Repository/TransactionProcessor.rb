class TransactionProcessor
	inherit Log
	
	def initialize repository, transaction
		@repository, @transaction = repository, transaction
	end		
	
	def check_outdated
		outdated = []
		@transaction.copies.each do |om_id, c| 
			next if c.new?
			e = @repository.by_id(om_id)
			outdated << om_id if c.om_version != e.om_version				
		end
		raise_without_self OutdatedError.new(outdated), "Outdated Entities: ['#{outdated.join('\', \'')}']", ObjectModel unless outdated.empty?
	end
	
	def write_back
		@transaction.copies.each do |om_id, copy| 
			next if copy.deleted?
			entity = @transaction.resolve om_id
			AnEntity::EntityType.write_back copy, entity
		end
	end
	
	def persist		
		@transaction.copies.each do |om_id, copy| 
			entity = @transaction.resolve om_id
			if copy.deleted?
				AnEntity::EntityType.delete entity, @repository.storage					
			else
				AnEntity::EntityType.persist copy, entity, @repository.storage
			end
		end					
	end
end
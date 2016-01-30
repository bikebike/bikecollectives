module ApplicationHelper
	
	def yield_or_default(section, default = '')
		content_for?(section) ? content_for(section) : default
	end
end

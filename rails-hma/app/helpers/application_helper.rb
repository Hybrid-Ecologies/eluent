module ApplicationHelper
	def bglyph icon, options={}
		"<span class='#{options[:class]} glyphicon glyphicon-#{icon}' type='#{options[:type]}' title='#{options[:title]}'></span>".html_safe
	end
	def active_class link_path
		current_page?(link_path) ? "active" : ""
	end

end

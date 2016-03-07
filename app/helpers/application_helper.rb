module ApplicationHelper
	
	def yield_or_default(section, default = '')
		content_for?(section) ? content_for(section) : default
	end

	def location_lookup(address)
		# get rid of any newlines
		location = Geocoder.search(params[:organization][:location].gsub(/[\n\r]+/, ', '))

		return nil unless location

		street_number = ""
		street_address = ""
		l = {
			:latitude => location.first.geometry['location']['lat'],
			:longitude => location.first.geometry['location']['lng']
		}
		location.first.address_components.each do | a |
			street_number   = a['long_name']  if a['types'].include? 'street_number'
			street_address  = a['short_name'] if a['types'].include? 'route'
			l[:city]        = a['long_name']  if a['types'].include? 'locality'
			l[:territory]   = a['short_name'] if a['types'].include? 'administrative_area_level_1'
			l[:country]     = a['short_name'] if a['types'].include? 'country'
			l[:postal_code] = a['short_name'] if a['types'].include? 'postal_code'
		end
		l[:street] = [street_number, street_address].compact.join(' ') if street_address
		return l
	end

	def location_html(location)
		return _location_html(([location.city,
				I18n.t("geography.subregions.#{location.country}.#{location.territory}"),
				I18n.t("geography.countries.#{location.country}")] - [""]).compact.join(', '),
			location.street)
	end

	def enter_location_html
		return _location_html 'City, Region, Country', 'Street address'
	end

	def username_html(user)
		user.firstname || user.username || "<span class=\"no-value\">#{user.email}</span>".html_safe
	end

	def user_link(user_or_email)
		user = user_or_email.is_a?(User) ? user_or_email : User.find_by_email(user_or_email)
		return user_or_email.split('@').first unless user.present?
		name = user_name(user)
		org = user_org(user)
		return name unless org
		org_link = link_to(org.name, view_organization_path(slug: org.slug))
		"#{name} of #{org_link}".html_safe
	end

	def user_name(user)
		email = user.is_a?(User) ? user.email : user
		name = user.is_a?(User) ? user.firstname || user.username : nil
		return name || email.split('@').first
	end

	def photo_credit(email)
		user = User.find_by_email(email)
		org = user_org(user)
		org.present? ? "Photo by #{user_name(user)} of #{org.name}" : "Photo by #{user_name(user)}"
	end

	def user_org(user)
		return nil unless user.present?
		relation = Organization.joins(:user_organization_relationships).
			where(
				'user_organization_relationships.user_id' => user.id,
				'user_organization_relationships.relationship' => :administrator).
			where('COALESCE(status, \'open\') != \'hidden\'').
			order(updated_at: :asc).first
		return relation.present? ? relation : nil
	end

	def sanitize_html(html)
		(ActionController::Base.helpers.sanitize html, tags: %w(br p h3 h4 blockquote ol ul li b strong i em u strike a img), attributes: %w(href src)).html_safe
	end

	def country_name(location)
		I18n.t("geography.countries.#{location.country}")
	end

	def territory_name(location)
		I18n.t("geography.subregions.#{location.country}.#{location.territory.mb_chars.normalize(:kd).gsub(/[^x00-\x7F]/n, '').to_s.upcase}")
	end

	def org_email_html(email)
		"<h3>Organization email:</h3><div class=\"email\">#{email || '(unknown)'}</div>".html_safe
	end

	def popup_dlg(id, link_title, dlg_title, attributes = {}, &block)
		doc = Nokogiri::HTML::DocumentFragment.parse('')
		trigger = Nokogiri::XML::Node.new((attributes[:type] || 'a'), doc)
		trigger.set_attribute('href', attributes[:href] || '#')
		trigger.set_attribute('data-dlg', "#{id.to_s}-dlg")
		trigger.set_attribute('class', attributes[:class]) if attributes[:class]
		trigger.set_attribute('id', attributes[:id]) if attributes[:id]
		trigger.add_child(Nokogiri::HTML.fragment(link_title))

		@_popup_dlgs ||= {}
		@_popup_dlgs[id] = {
			title: dlg_title,
			content: block_given? ? capture(&block) : ''
		}

		return trigger.to_html.html_safe
	end

	def render_dlgs
		dlgs = ''
		@_popup_dlgs ||= {}
		@_popup_dlgs.each do |id, properties|
			dlgs += "<div id=\"#{id.to_s}-dlg\" class=\"popup-dlg\">" + 
				"<div class=\"dlg-inner\">" +
					"<h3>#{properties[:title]}</h3>" +
					properties[:content] +
				"</div></div>"
		end
		return dlgs.html_safe
	end

	def popup_dlg_actions(actions)
		actions[:cancel] ||= 'Cancel'

		actions_html = ''
		actions.each do |key, value|
			if value.is_a? Hash
				actions_html += _create_element_from_hash value
			else
				actions_html += "<button class=\"#{key}\">#{value}</button>"
			end
		end

		return "<div class=\"actions\">#{actions_html}</div>".html_safe
	end

	private

	def _location_html(city_country, street_address)
		return "<h3>#{city_country}</h3>#{street_address}".html_safe
	end

	def _create_element_from_hash(hash)
		doc = Nokogiri::HTML::DocumentFragment.parse('')
		element = Nokogiri::XML::Node.new('div', doc)

		hash.each do | key, value |
			case key.to_sym
				when :type
					element.name = value
				when :content
					element.content = value
				else
					element.set_attribute(key.to_s, value)
			end
		end

		element.to_html
	end

end

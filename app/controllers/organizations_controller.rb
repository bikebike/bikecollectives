include ApplicationHelper
require 'uri'
require 'organization'

class OrganizationsController < ApplicationController
	# GET /organizations
	def index
		organizations = Organization.all
		@organizations = Hash.new
		@data = Hash.new
		countries = Hash.new
		territories = Hash.new
		@orgs = organizations
		organizations.each do | organization |
			if organization.locations.size > 0
				organization.locations.each do | location |
					
					# if the latitde and logitude are missing try re-saving the object to update it
					location.save! if location.latitude.blank? || location.longitude.blank?

					country_name = I18n.t("geography.countries.#{location.country}")
					@organizations[country_name] ||= Hash.new
					@data[country_name] ||= Hash.new

					if location.territory.present?
						territory_name = I18n.t("geography.subregions.#{location.country}.#{location.territory}")
						@organizations[country_name][territory_name] ||= Hash.new
						@organizations[country_name][territory_name][location.city] ||= Array.new
						@organizations[country_name][territory_name][location.city] << organization

						# if we are still missing the latitude and logitude, skip this organization
						if location.latitude.present? && location.longitude.present?
							@data[country_name][territory_name] ||= Hash.new
							@data[country_name][territory_name][location.city] ||= {lat: location.latitude, lon: location.longitude, id: location.slugify}
						end
					else
						@organizations[country_name][location.city] ||= Array.new
						@organizations[country_name][location.city] << organization

						@data[country_name][location.city] ||= {lat: location.latitude, lon: location.longitude, id: location.slugify} if location.latitude.present? && location.longitude.present?
					end
				end
			end
		end
	end

	def view
		@organization = Organization.find_by!(slug: params[:slug])
		@location = @organization.location
		#ssss
	end

end

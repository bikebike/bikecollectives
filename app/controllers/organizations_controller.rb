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
		@can_add_organization = logged_in?
		organizations.each do | organization |
			if organization.locations.size > 0 && organization.visible_to?(current_user)
				organization.locations.each do | location |
					
					# if the latitde and logitude are missing try re-saving the object to update it
					location.save! if location.latitude.blank? || location.longitude.blank?

					country_name = country_name(location)
					@organizations[country_name] ||= Hash.new
					@data[country_name] ||= Hash.new

					if location.territory.present?
						territory_name = territory_name(location)
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
		return do_404 unless @organization.visible_to?(current_user)

		@location = @organization.location
		@editable_address = ([@location.street,
			[
				@location.city,
				@location.territory && @location.country ? territory_name(@location) : nil,
				@location.country ? country_name(@location) : nil,
			].compact.join(', '), @location.postal_code] - [nil, '']).join("\n")
		@validate_path = @update_path = save_organization_path(id: @organization.id)
		@is_new = false
		@can_edit = @organization.administrator?(current_user)
		@can_become_admin = logged_in? && @organization.user_releationship(current_user).blank?
		@requires_approval = @organization.users.present? && @organization.users.size > 0
		@statuses = [
			['Hidden', :hidden],
			['Opening Soon', :new],
			['In Operation', :open],
			['Shut Down', :shut]
		]
	end

	def create
		return do_403 unless logged_in?
		@organization = Organization.new
		@location = nil
		@editable_address = nil
		@validate_path = validate_organization_field_path
		@update_path = save_new_organization_path
		@is_new = true
		
		render :view
	end

	def save
		organization = params[:id] ? Organization.find(params[:id]) : Organization.new
		
		return do_403 unless organization.administrator?(current_user)

		response = { }

		if params[:organization]
			response = validate_fields(organization)
		end

		if request.xhr?
			render :json => response
		else
			redirect_to view_organization_url(slug: organization.slug)
		end
	end
	
	def administrate
		organization = Organization.find(params[:id])
		return do_403 unless logged_in? && (organization.users.blank? || organization.users.size < 1)
		
		UserOrganizationRelationship.create(
				:organization_id => organization.id,
				:user_id         => current_user.id,
				:relationship    => :administrator
			)

		redirect_to view_organization_url(slug: organization.slug)
	end
	
	def add_administrator
		organization = Organization.find(params[:id])
		return do_403 unless logged_in? && organization.administrator?(current_user)
		
		user = User.find_by_email(params[:email]) || User.create(email: params[:email])

		unless organization.administrator?(user)
			
			UserOrganizationRelationship.create(
					:organization_id => organization.id,
					:user_id         => user.id,
					:relationship    => :administrator
				)

			# send an email to all administrators
			UserMailer.send_mail :add_administrator do
				{
					:args => [ user, organization ]
				}
			end
		end

		redirect_to view_organization_url(slug: organization.slug)
	end
	
	def leave
		organization = Organization.find(params[:id])
		do_403 unless logged_in?
		
		UserOrganizationRelationship.delete_all(
				:organization_id => organization.id,
				:user_id         => current_user.id
			)

		redirect_to view_organization_url(slug: organization.slug)
	end

	def request_access
		organization = Organization.find(params[:id])

		# don't do anything if the user is not logged in or any type of relationship already exists
		return do_403 unless logged_in? && organization.user_releationship(current_user).blank?
		
		# create the request
		UserOrganizationRelationship.create(
				:organization_id => organization.id,
				:user_id         => current_user.id,
				:relationship    => :request
			)

		# send an email to all administrators
		UserMailer.send_mail :request_org_access do
			{
				:args => [ current_user, organization, params[:request][:message] ]
			}
		end
		redirect_to view_organization_url(slug: organization.slug)
	end

	def access_response
		organization = Organization.find(params[:id])
		user = User.find(params[:user_id])

		return do_403 unless organization.administrator?(current_user)
		return do_404 unless organization.requested?(user)

		case params[:state].to_sym
		when :approved
			relationship = UserOrganizationRelationship.where(
					:organization_id => organization.id,
					:user_id => user.id
				).first
			relationship.relationship = :administrator
			relationship.save!

			# notify the user that their request has been approved
			UserMailer.send_mail :request_org_access_approved do
				{
					:args => [ user, organization ]
				}
			end
		when :denied
			UserOrganizationRelationship.delete_all(
					:organization_id => organization.id,
					:user_id => user.id
				)
		else
			return do_404
		end
		redirect_to view_organization_url(slug: organization.slug)
	end

	def validate
		response = { }

		if params[:organization]
			response = validate_fields
		end

		if request.xhr?
			render :json => response
		else
			redirect_to view_organization_url(slug: organization.slug)
		end
	end

	private

	def validate_fields(organization = nil)
		response = { }
		modified = false
		newOrg = organization.present? && organization.id.blank?

		if params[:organization][:cover] && organization
			organization.cover = params[:organization][:cover]
			organization.save! unless newOrg
			response['organization[cover]'] = organization.cover.full.url
		end

		if params[:organization][:avatar] && organization
			organization.avatar = params[:organization][:avatar]
			organization.save! unless newOrg
			response['organization[avatar]'] = organization.avatar.url
		end

		if params[:organization][:name]
			modified = true
			response['organization[name]'] = params[:organization][:name]
			organization.name = response['organization[name]'] if organization
		end

		if params[:organization][:info]
			modified = true
			response['organization[info]'] = sanitize_html(params[:organization][:info])
			organization.info = response['organization[info]'] if organization
		end

		if params[:organization][:email_address]
			modified = true
			response['organization[email_address]'] = org_email_html(params[:organization][:email_address])
			organization.email_address = params[:organization][:email_address]
		end

		if params[:organization][:status]
			modified = true
			response['organization[status]'] = params[:organization][:status]
			organization.status = params[:organization][:status]
		end

		if params[:organization][:location]
			location = location_lookup(params[:organization][:location])
			if location.nil?
				response[:error] = 'Invalid address, please reformat and try again'
			elsif organization
				if organization.locations.present?
					organization.locations.first.update_attributes(location)
				else
					organization.locations << Location.create(location)
					modified = true
				end
				response['organization[location]'] = location_html(organization.locations.first)
			else
				response['organization[location]'] = location_html(Location.new(location))
			end
		end
		organization.save! if organization && (modified || response[:error].blank?)

		if newOrg
			response['newUrl'] = view_organization_path(slug: organization.slug)
		end

		return response
	end

end

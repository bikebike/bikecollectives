include ApplicationHelper

class UserController < ApplicationController
	def account
		# right now only viewing your own account is available but we should prepare for
		# when we want viewing other user accounts to be made available
		@user = current_user
		@can_edit = true
	end

	def update
		user = current_user
		user.firstname = params[:name] if params[:name]
		user.save!
		
		redirect_to my_account_url
	end
end

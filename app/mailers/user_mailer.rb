class UserMailer < ActionMailer::Base
	add_template_helper(ApplicationHelper)
	include LinguaFrancaHelper

	default from: "Bike Collective Network <noreply@bikecollectives.org>"

	def email_confirmation(confirmation)
		@confirmation = confirmation
		@host = UserMailer.default_url_options[:host]
		mail to: confirmation.user.email,
			 subject: (_'email.subject.confirm_email','Please confirm your email address')
	end

	def request_org_access(requester, organization, message)
		@host = UserMailer.default_url_options[:host]
		
		@requester = requester
		@organization = organization
		@message = message
		
		mail to: all_emails(organization.administrators),
			 subject: (_'email.subject.user_admin_request',"New administrator request from #{requester.firstname || requester.email}", vars: {name_or_email: requester.firstname || requester.email})
	end

	def request_org_access_approved(requester, organization)
		@host = UserMailer.default_url_options[:host]
		
		@requester = requester
		@organization = organization
		
		mail to: get_email_with_name(requester),
			 subject: (_'email.subject.user_admin_request_approved', "Your request to become an administrator has been approved")
	end

	def add_administrator(admin, organization)
		@host = UserMailer.default_url_options[:host]
		
		@admin = admin
		@organization = organization
		
		mail to: get_email_with_name(admin),
			 subject: (_'email.subject.add_administrator', "You have become an administrator of an organization")
	end

	def report_problem_email(message, user_or_email)
		@host = UserMailer.default_url_options[:host]
		
		@message = message
		
		mail to: 'goodgodwin@hotmail.com',
			 from: user_or_email.is_a?(User) ? get_email_with_name(user_or_email) : user_or_email,
			 subject: (_'email.subject.report_problem', "A new issue has been reported"),
			 body: message,
			 content_type: "text/plain"
	end

	private

		def get_email_with_name(user)
			# make sure emails don't go out to actual users in devo but make sure we know who it was supposed to go to
			#dev_email = 'michael.allen.godwin@gmail.com'
			dev_email = 'goodgodwin@hotmail.com' # I should probably make this an environment variable so allow more people to work on this
			email = Rails.env.development? ? dev_email.gsub('@', "+#{user.email.gsub(/@/, '_at_').gsub(/\./, '_')}@") : user.email
			user.firstname ? "#{user.firstname} <#{email}>" : email
		end

		def all_emails(users)
			emails = []
			users.each do | user |
				emails << get_email_with_name(user)
			end
			return emails
		end

end

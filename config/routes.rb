Rails.application.routes.draw do
	get   'wiki' => redirect("https://w.bikecollectives.org"), as: :wiki
	get   'github' => redirect("https://github.com/bikebike/bikecollectives"), as: :github
	
	get   'organizations' => 'organizations#index', as: :organizations
	patch 'organizations/-/validate' => 'organizations#validate', as: :validate_organization_field
	get   'organizations/-/create' => 'organizations#create', as: :create_organization
	get   'organizations/:slug' => 'organizations#view', as: :view_organization
	patch 'organizations/-/save' => 'organizations#save', as: :save_new_organization
	patch 'organizations/:id/save' => 'organizations#save', as: :save_organization
	get   'organizations/:id/administrate' => 'organizations#administrate', as: :administrate_organization
	post  'organizations/:id/add-administrator' => 'organizations#add_administrator', as: :add_administrator
	get   'organizations/:id/leave' => 'organizations#leave', as: :leave_organization
	post  'organizations/:id/request-access' => 'organizations#request_access', as: :request_access
	get   'organizations/:id/access/:user_id/:state' => 'organizations#access_response', as: :access_response, :constraints => { :state => /(approved|denied)/ }
	
	get   'opportunities' => 'application#opportunities', as: :opportunities
	get   'privacy' => 'application#privacy', as: :privacy
	get   'info' => 'application#site_info', as: :site_info
	post  'info/report' => 'application#report_problem', as: :report_problem
	get   'account' => 'user#account', as: :my_account
	post  'account/-/update' => 'user#update', as: :update_my_account
	
	get   'thethinktank' => 'application#thinktank', as: :thinktank_home
	match 'thethinktank/:url' => 'application#thinktank', as: :thinktank_page, constraints: { url: /.*/ }, via: [:get, :post]

	root  'application#home', as: :home
end

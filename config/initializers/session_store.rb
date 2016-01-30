# store sessions in the database
if Rails.env == 'production' || Rails.env == 'preview'
	BikeCollectives::Application.config.session_store :active_record_store, :domain => :all
else
	BikeCollectives::Application.config.session_store :active_record_store
end

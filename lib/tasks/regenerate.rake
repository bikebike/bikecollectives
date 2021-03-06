namespace :regenerate do
	desc "Regenerates images"

	task conference_posters: :environment do
		Conference.all.each { |m| m.poster.recreate_versions! }
	end

	task organization_avatars: :environment do
		Organization.all.each {|m| m.avatar.recreate_versions!}
	end

	task conference_covers: :environment do
		Conference.all.each {|m| m.cover.recreate_versions!}
	end

	task organization_covers: :environment do
		Organization.all.each {|m| m.cover.recreate_versions!}
	end

	task all: :environment do
		CarrierWave.clean_cached_files!
		if Object.const_defined?('Conference')
			puts 'Regenerating Conference images'
			Conference.all.each { |m| m.poster.recreate_versions! }
			Conference.all.each {|m| m.cover.recreate_versions!}
		end
		puts 'Regenerating Organizaion images'
		if Object.const_defined?('Organization')
			Organization.all.each {|m| m.avatar.recreate_versions!}
			Organization.all.each {|m| m.cover.recreate_versions!}
		end
	end
end

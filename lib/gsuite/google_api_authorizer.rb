require 'google/api_client/client_secrets'
require 'tempfile'
require 'google/apis/admin_directory_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'

require 'fileutils'

module Gsuite
	class GoogleApiAuthorizer
		if ENV['FETCH_ENVS_FROM_REMOTE_URL'] == 'true'
			CLIENT_ID = Google::Auth::ClientId.from_hash(JSON.parse(ENV['GOOGLE_AUTH_CONFIG']))
		else
			if Rails.env.development? || Rails.env.test?
				CLIENT_SECRETS_PATH = ('client_secret.json')
			else
				CLIENT_SECRETS_PATH = File.join(Dir.home, 'www/sapling/shared/config', 'client_secret.json')
			end
			CLIENT_ID = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
		end

    CREDENTIALS_PATH = File.join(Dir.home, '.credentials', "admin-directory_v1-ruby-sapling.yaml")

    SCOPE = [Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_USER]
    OUGROUPS = [Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_ORGUNIT_READONLY,Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_GROUP_MEMBER,Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_GROUP_READONLY]

		def get_authorizer(company)
			FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))
			token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
      scope  = company.google_groups_feature_flag ? (SCOPE + OUGROUPS) : SCOPE
	  	authorizer = Google::Auth::UserAuthorizer.new(CLIENT_ID, scope, token_store, '/api/v1/oauth2callback')

			authorizer
		end

	end
end

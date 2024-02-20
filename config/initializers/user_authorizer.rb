# Copyright 2014, Google Inc
## Adding more action to process credentials from table instead file name
require "uri"
require "multi_json"
require "googleauth/signet"
require "googleauth/user_refresh"

module Google
  module Auth
    
    class UserAuthorizer

      def get_credentials_from_relation(object, user_id)
        return nil if !object.google_credential
        if object.google_credential.credentials.class == Hash
          account_credential = object.google_credential.credentials
        else
          account_credential = JSON.parse(object.google_credential.credentials)
        end
        if account_credential.fetch("client_id", @client_id.id) != @client_id.id
          raise format(MISMATCHED_CLIENT_ID_ERROR,
            account_credential["client_id"], @client_id.id)
        end

        credentials = UserRefreshCredentials.new(
          client_id:     @client_id.id,
          client_secret: @client_id.secret,
          scope:         account_credential["scope"] || @scope,
          access_token:  account_credential["access_token"],
          refresh_token: account_credential["refresh_token"],
          expires_at:    account_credential.fetch("expiration_time_millis", 0) / 1000
        )
        scope ||= @scope
        return monitor_credentials_relation(object, user_id, credentials) if credentials.includes_scope? scope
        nil
      end 

      def store_credentials_relation(object, user_id, credentials)
        json = {client_id:        credentials.client_id,
          access_token:           credentials.access_token,
          refresh_token:          credentials.refresh_token,
          scope:                  credentials.scope,
          expiration_time_millis: credentials.expires_at.to_i * 1000}
        object.read_and_store_google_credentials json
        credentials
      end

      def monitor_credentials_relation(object, user_id, credentials)
        credentials.on_refresh do |cred|
          store_credentials_relation(object, user_id, cred)
        end
        credentials
      end

      def get_and_store_credentials_from_code_relation(object, options = {})
        credentials = get_credentials_from_code_rel(object, options)
        store_credentials_relation(object, options[:user_id], credentials)
      end

      def get_credentials_from_code_rel(object, options = {})
        user_id = options[:user_id]
        code = options[:code]
        scope = options[:scope] || @scope
        base_url = options[:base_url]
        credentials = UserRefreshCredentials.new(
          client_id:     @client_id.id,
          client_secret: @client_id.secret,
          redirect_uri:  redirect_uri_for(base_url),
          scope:         scope
        )
        credentials.code = code
        credentials.fetch_access_token!({})
        monitor_credentials_relation(object, user_id, credentials)
      end


      def revoke_authorization_from_relation(object, user_id)
        credentials = get_credentials_from_relation(object, user_id)
        if credentials
          begin
            object.google_credential.destroy
          ensure
            credentials.revoke!
          end
        end
        nil
      end

    end
  end
end
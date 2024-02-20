require 'google/apis/sheets_v4'
class AuthorizeGsheetCredentials
  if ENV['FETCH_ENVS_FROM_REMOTE_URL'] == 'true'
    CLIENT_ID = Google::Auth::ClientId.from_hash(JSON.parse(ENV['GOOGLE_SHEETS_CONFIG']))
  else
    if Rails.env.development? || Rails.env.test?
      CLIENT_SECRETS_PATH = ('client_secret_gsheet.json')
    else
      CLIENT_SECRETS_PATH = File.join(Dir.home, 'www/sapling/shared/config', 'client_secret_gsheet.json')
    end
    CLIENT_ID = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
  end
  CREDENTIALS_PATH = File.join(Dir.home, '.credentials',
                   "gsheet_v4-ruby-sapling.yaml")
  SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS

  def self.get_authorizer
    FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))
    token_store = Google::Auth::Stores::FileTokenStore.new(
                  file: CREDENTIALS_PATH)
    authorizer = Google::Auth::UserAuthorizer.new(
                  CLIENT_ID, SCOPE, token_store, '/api/v1/gsheet_oauth2callback'
                  )
    authorizer
  end
end

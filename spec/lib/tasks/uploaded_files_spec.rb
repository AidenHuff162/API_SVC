require 'rails_helper'

describe 'uploaded_files' do
  before :all do
    Rake.application = Rake::Application.new
    Rake.application.rake_require 'lib/tasks/uploaded_files', [Rails.root.to_s]
    Rake::Task.define_task :environment
  end

  describe 'uploaded_files:remove_expired' do
    it 'removes expired uploaded files' do
      task = Rake::Task['uploaded_files:remove_expired']
      relation = double(:relation, destroy_all: true)
      allow(UploadedFile).to receive(:expired).and_return(relation)

      task.invoke

      expect(relation).to have_received(:destroy_all)
    end
  end
end

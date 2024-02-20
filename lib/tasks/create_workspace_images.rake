namespace :create_workspace_images do
  task create: :environment do
    Dir.entries('app/assets/images/workspace').each do |filename|
      next if file_invalid?(filename)
      
      if filename == 'replacement'
        Dir.entries('app/assets/images/workspace/replacement').each do |filename|
          next if file_invalid?(filename)

          WorkspaceImage.create_workspace_image('app/assets/images/workspace/replacement/', filename)
        end
      else
        WorkspaceImage.create_workspace_image('app/assets/images/workspace/', filename)
      end
    end
  end
  
  private

  def file_invalid?(filename)
    filename == '.' || filename == '..'
  end

end

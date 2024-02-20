require 'zip'

Zip.setup do |zip|
  zip.on_exists_proc = true
  zip.continue_on_exists_proc = true
end

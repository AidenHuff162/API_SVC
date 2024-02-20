namespace :default_email_templates do
  task fix_default_templates: :environment do
    EmailTemplate.where(is_default: true).update_all(is_default: false)
  end

  task create_default_templates: :environment do
    Company.find_each do |company|
      et = company.email_templates.new
      et.email_to = '<p><br></p>'
      et.subject = '<p>Welcome to <span class="token" contenteditable="false" unselectable="on" data-name="Company Name">Company Name</span>!</p>'
      et.bcc = '<p><br></p>'
      et.cc = '<p><br></p>'
      et.description = '<p>Hi&nbsp;<span class="token" contenteditable="false" unselectable="on" data-name="Preferred/ First Name">Preferred/ First Name</span>&zwnj;,</p><p><br></p><p>We&#8217;re so excited you&#8217;re joining <span class="token" contenteditable="false" unselectable="on" data-name="Company Name">Company Name</span>!</p><p><br></p><p>At the bottom of this email is an invitation to our one-stop People Operations shop, Sapling. Your first step in Sapling is preboarding. Once you log in to Sapling, you&#8217;ll be able to accomplish the following:</p><p></p><ul><li><b>Take a peek at our culture and values.</b> We want you to learn our story and what makes <span class="token" contenteditable="false" unselectable="on" data-name="Company Name">Company Name</span> such a great place!</li><li><b>Upload your profile photo.</b> This is your time to shine and show <span class="token" contenteditable="false" unselectable="on" data-name="Company Name">Company Name</span> your smiling face.</li><li><b>Complete your preboarding.</b> We&#8217;re going to ask you a few questions to make sure we have everything we need to get you up and running.</li><li><b>Complete any documents.</b> You&#8217;ll find some important documents to sign toward the end of preboarding.</li></ul><p><br></p><p>That&#8217;s it! Keep an eye on your inbox as we&#8217;ll be sending another email a few days before your start date on <span class="token" contenteditable="false" unselectable="on" data-name="Start Date">Start Date</span>.</p><p><br></p><p>Cheers,</p><p><br></p><p><span class="token" contenteditable="false" unselectable="on" data-name="Company Name">Company Name</span></p>'
      et.email_type = 'invitation'
      et.name = '<p>Onboarding Template</p>'
      et.schedule_options['set_onboard_cta'] = true
      et.save
    end
  end
end

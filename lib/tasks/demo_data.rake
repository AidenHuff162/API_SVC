namespace :demo_data do
  task :upload, [:name, :domain, :subdomain] => :environment do |task, args|
    AdminUser.create!(
      email: 'admin@example.com',
      password: 'password',
      password_confirmation: 'password'
    ) unless AdminUser.exists?

    company = Company.create!(name: args.name, domain: args.domain, subdomain: args.subdomain)

    team = company.teams.create(name: 'Sapling Template')
    location = company.locations.create(name: 'Sapling Template')

    user = company.users.create!(
      first_name: 'Sapling',
      last_name: 'Template',
      email: "sapling_template@#{args.domain}",
      password: ENV['USER_PASSWORD'],
      personal_email: "sapling_template.personal@#{args.domain}",
      title: 'Head of Operations',
      role: :account_owner,
      state: :registered,
      team: team,
      location: location,
      start_date: Date.yesterday
    )

    user.create_profile!

    super_user = company.users.create!(
      first_name: 'Super',
      last_name: 'User',
      email: "super_user@#{args.domain}",
      password: ENV['USER_PASSWORD'],
      personal_email: "super_user.personal@#{args.domain}",
      title: 'Super User',
      role: :account_owner,
      state: :active,
      current_stage: User.current_stages[:registered],
      start_date: 31.days.ago,
      super_user: true
    )

    super_user.create_profile!

    workstreams = [
      'Office, Hardware and Systems',
      'New Manager Onboarding',
      'Team and Culture',
      'Compliance',
      'Full-time Employee (Australia Team)',
      'Full-time Employee Forms (US Team)',
      'Policies and Procedures',
      'Engineering Onboarding',
      'Marketing Onboarding',
      'Product Onboarding',
      'Sales Onboarding'
    ]

    workstream_tasks = [
      [
        {name: "Help new-hire setup voicemail", description: "Make sure landline and cell phone voicemail are updated.", position: 1, deadline_in: 0, owner_id: user.id},
        {name: "Add new Employee to Slack", description: "Add new Empoyee to Slack team and relevant channels", position: 2, deadline_in: -7, owner_id: user.id},
        {name: "Set-up new hire Email Signature", description: "Ensure consistent with rest of team. If there is any differences, Andy's is the source of truth", position: 3, deadline_in: 0, owner_id: user.id},
        {name: "Set up Computer Hardware and Monitor", description: "Make sure the new hire has their Macbook and Monitor ready to go on the first day.", position: 4, deadline_in: -7, owner_id: user.id},
        {name: "Swipe Pass / Office Keys", description: "Make sure the new hire is all set on getting in/out of the office.", position: 5, deadline_in: 0, owner_id: user.id},
        {name: "Company Swag", description: "Deck your new coworker out with company gear on day one.", position: 6, deadline_in: -7, owner_id: user.id},
        {name: "Set-up Email Groups", description: "Make sure the new hire has access to any department or team email threads.", position: 7, deadline_in: -7, owner_id: user.id},
        {name: "Enure New Hire has changed Linkedin", description: "Ensure Title and Company Description meet branding requirements.  Pro Tip - invite them to connect on Linkedin to make them feel welcome.", position: 8, deadline_in: 0, owner_id: user.id},
        {name: "First Day Orientation", description: "Learn about the office environment and get the inside scoop on the neighborhood.", position: 9, deadline_in: 0, owner_id: user.id},
        {name: "Ensure employee has been added to Intranet", description: "Add into intranet account.", position: 10, deadline_in: -7, owner_id: user.id},
        {name: "Ensure access is given to shared drive", description: "Add into Google Drive account", position: 11, deadline_in: -7, owner_id: user.id}
      ],
      [
        {name: "Complete anti-bias training", description: nil, position: 1, deadline_in: -15, owner_id: user.id},
        {name: "Setup in Concur for expensing", description: nil, position: 2, deadline_in: 7, owner_id: user.id},
        {name: "Sign travel and entertainment policy", description: nil, position: 3, deadline_in: 0, owner_id: user.id},
        {name: "Create login into Recruitment System", description: nil, position: 4, deadline_in: 7, owner_id: user.id},
        {name: "Organize business cards", description: nil, position: 5, deadline_in: -7, owner_id: user.id}
      ],
      [
        {name: "Photo Session", description: "Schedule a time to get a company photo of the new hire.", position: 1, deadline_in: 0, owner_id: user.id},
        {name: "Buddy allocation", description: "Be sure the new hire has a great mentor and buddy within their team.", position: 2, deadline_in: -7, owner_id: user.id},
        {name: "Welcome Basket", description: "Send New Hire Welcome Basket", position: 3, deadline_in: 0, owner_id: user.id},
        {name: "First Day Lunch with Teammate", description: "Make sure the new hire goes for lunch with someone on their first day", position: 4, deadline_in: 0, owner_id: user.id},
        {name: "Onboarding Questionaire", description: "Send New Hire post onboarding quiestionaire", position: 5, deadline_in: 15, owner_id: user.id},
        {name: "Welcome SMS", description: "SMS the day before they start. Something friendly like\n\n\"Can't wait to have you in tomorrow.  Reminder we start at 830am and every day is casual day!\"", position: 6, deadline_in: -7, owner_id: user.id}
      ],
      [
        {name: "Ensure signed NDA & IP Policy", description: nil, position: 1, deadline_in: 0, owner_id: user.id},
        {name: "Compliance Training", description: "Learn about what it takes to keep our customers safe and how we stay diligent.", position: 2, deadline_in: -7, owner_id: user.id},
        {name: "Payroll & Benefits", description: "Ensure correct Payroll details and direct deposit forms", position: 3, deadline_in: -7, owner_id: user.id}
      ],
      [
        {name: "Tax File Declaration Form", description: "Ensure TFN is completed", position: 1, deadline_in: -1, owner_id: user.id},
        {name: "Super Choice Form", description: "Ensure Super Choice form is completed", position: 2, deadline_in: -1, owner_id: user.id},
        {name: "Fair Work Information Statement", description: "Ensure FW Info Statement is emailed or left on new-hires desk for day 1.", position: 3, deadline_in: -1, owner_id: user.id},
        {name: "Personal Information Form", description: nil, position: 4, deadline_in: 7, owner_id: user.id},
        {name: "Emergency Contact Form", description: "Ensure Emergency Information/Next of Kin Form is completed.", position: 5, deadline_in: 2, owner_id: user.id},
        {name: "Banking Details Form", description: nil, position: 6, deadline_in: 3, owner_id: user.id},
        {name: "Salary Sacrelsifice Form", description: nil, position: 7, deadline_in: 3, owner_id: user.id},
        {name: "Novated Lease Form", description: nil, position: 8, deadline_in: 3, owner_id: user.id}
      ],
      [
        {name: "W-4", description: "Ensure W-4 Form is completed", position: 1, deadline_in: 0, owner_id: user.id},
        {name: "I-9", description: "Ensure I-9 Form is completed", position: 2, deadline_in: 0, owner_id: user.id},
        {name: "Veteran Status Information", description: "Offer Veteran Status form for completion.", position: 3, deadline_in: 0, owner_id: user.id},
        {name: "Emergency Contact Form", description: "Ensure Emergency Information/Next of Kin Form is completed.", position: 4, deadline_in: 0, owner_id: user.id},
        {name: "Direct Deposit Form and Cancelled Check", description: "Ensure Direct Deposit Form accurately completed and submitted for first payroll.", position: 5, deadline_in: 0, owner_id: user.id},
        {name: "Benefits Application", description: "Ensure Benefits and co-dependants have been correctly processed and added to PEO.", position: 6, deadline_in: 7, owner_id: user.id}
      ],
      [
        {name: "Code of Conduct and Ethics", description: nil, position: 1, deadline_in: 0, owner_id: user.id},
        {name: "Dress Code", description: nil, position: 2, deadline_in: -7, owner_id: user.id},
        {name: "Confidentiality and IP Assignment", description: nil, position: 3, deadline_in: -7, owner_id: user.id},
        {name: "Electronic Communications Policy", description: nil, position: 4, deadline_in: -7, owner_id: user.id},
        {name: "Company Expense Policy", description: nil, position: 5, deadline_in: -7, owner_id: user.id},
        {name: "Vacation Policy", description: "Discuss with new-hire in person on day 1", position: 6, deadline_in: 0, owner_id: user.id},
        {name: "Sick Leave Policy", description: nil, position: 7, deadline_in: 7, owner_id: user.id},
        {name: "FMLA/ Leaves of Absence Policy", description: nil, position: 8, deadline_in: -7, owner_id: user.id},
        {name: "Overtime Policy", description: nil, position: 9, deadline_in: 7, owner_id: user.id},
        {name: "Working Hours Policy", description: nil, position: 10, deadline_in: 7, owner_id: user.id},
        {name: "Travel Policy", description: nil, position: 11, deadline_in: 7, owner_id: user.id},
        {name: "Health and Safety Policy", description: nil, position: 12, deadline_in: 7, owner_id: user.id},
        {name: "Security Procedure", description: nil, position: 13, deadline_in: 7, owner_id: user.id},
        {name: "Visitors and Pets Policy", description: nil, position: 14, deadline_in: 7, owner_id: user.id}
        ],
      [
        {name: "Add to GitHub", description: nil, position: 1, deadline_in: 0, owner_id: user.id},
        {name: "Add to Dribbble", description: nil, position: 2, deadline_in: 0, owner_id: user.id},
        {name: "Add to Pivotal", description: nil, position: 3, deadline_in: 0, owner_id: user.id},
        {name: "Provide access to internal development drive", description: nil, position: 4, deadline_in: 0, owner_id: user.id},
        {name: "Introduction to tech and infrastructure", description: nil, position: 5, deadline_in: 2, owner_id: user.id},
        {name: "Add to Heroku", description: nil, position: 6, deadline_in: 0, owner_id: user.id},
        {name: "Add to Circle CI", description: nil, position: 7, deadline_in: 0, owner_id: user.id},
        {name: "Add to Bitbucket", description: nil, position: 8, deadline_in: 7, owner_id: user.id}
      ],
      [
        {name: "Enable Hubspot login credentials", description: nil, position: 1, deadline_in: -7, owner_id: user.id},
        {name: "Introduction to Customer Acquisition Channels", description: nil, position: 2, deadline_in: 7, owner_id: user.id},
        {name: "Introduction to Content Strategy", description: nil, position: 3, deadline_in: 7, owner_id: user.id},
        {name: "Introduction to Partnerships", description: nil, position: 4, deadline_in: 7, owner_id: user.id},
        {name: "Enable access to Trello", description: "The marketing team uses Trello as the system of record for partnership opportunities and content marketing calendar.", position: 5, deadline_in: 0, owner_id: user.id}
      ],
      [
        {name: "Enable access to Pivotal Tracker", description: "Pivotal Tracker is our Product management tool where we write user stories for new features", position: 1, deadline_in: 2, owner_id: user.id},
        {name: "Set-up Invision credentials for prototypes", description: "We use Invision for prototyping new features for our awesome customers.", position: 2, deadline_in: 2, owner_id: user.id},
        {name: "Learn Target Customer Personas", description: "We use a fictional company and some key personas in our product development", position: 3, deadline_in: 7, owner_id: user.id},
        {name: "Arrange lunch meeting with VP Product", description: "Make sure Dave (VP Product) has met with the new hire in their first 2 weeks in the role.  \n\nHave Dave run through his 45minute Product ppt.", position: 4, deadline_in: 14, owner_id: user.id}
      ],
      [
        {name: "Setup Account in YesWare", description: nil, position: 1, deadline_in: 1, owner_id: user.id},
        {name: "Setup SalesForce Credentials", description: "SalesForce.com needs to be created as the core CRM used by the Sales Team.", position: 2, deadline_in: 0, owner_id: user.id},
        {name: "Shadow AE on 5 customer calls", description: nil, position: 3, deadline_in: 0, owner_id: user.id},
        {name: "Add to Sales Playbook repo", description: nil, position: 4, deadline_in: 0, owner_id: user.id},
        {name: "Setup account with NewVoiceMedia", description: nil, position: 5, deadline_in: -3, owner_id: user.id}
      ]
    ]

    workstreams.each_with_index do |name, index|
      position = index + 1
      workstream = company.workstreams.create(name: name, position: position)

      workstream.tasks.create! workstream_tasks[index]
    end

    roadmaps = [
      'Business Analyst',
      'SDR',
      'Onboarding Template',
      'Customer Success',
      'Customer Acquisition',
      'Software Engineer',
      'Product Designer',
      'Product Manager',
      'AE'
    ]

    roadmap_milestones = [
      [],
      [
        {name: "Company Overview", description: "* Who we are / why we're here / where we're going?\n* What matters in a SAAS business\n* The Rocketship Circle of Life\n* Facilitated Intros\n    --> Office Tour (WH&S Compliant), Desk Setup/New Photos, Photo Time -- Say Cheese!\n    --> Pool Room Welcome to Rocketship Inc. Meet the Founders Presentation. Org Chart.", position: 1, deadline_in: 2, feedback_link: nil},
        {name: "Platform Overview", description: "* Verticals\n* Clients\n* Case Studies\n* Pool Room Ad Tech Video", position: 2, deadline_in: 3, feedback_link: nil},
        {name: "Build Your Own Stack", description: "* Hands on workshop", position: 3, deadline_in: 5, feedback_link: nil},
        {name: "Product Team", description: "* Team/Roles\n* Product Roadmap\n* Competitive Landscape\n* Pool Room Product Section\n* Pool Room Technology Section\n* Pool Room Rocketship University", position: 4, deadline_in: 5, feedback_link: nil},
        {name: "Sales", description: "* Team / Roles\n* Process / Workflow (lead to close)\n* Salesforce CRM\n* Pro to Platform and Benefits of multi-year subscription\n* Latest Pitch Deck\n* Hero Clients -- 30 second pitches\n* Pool Room Sales Section", position: 5, deadline_in: 9, feedback_link: nil},
        {name: "Customer Success and Support", description: "* Team/Roles\n* Customer Success\n* Customer Support\n* Raising Tickets\n* Escalation\n* Knowledge Base", position: 6, deadline_in: 10, feedback_link: nil},
        {name: "Marketing", description: "* Team/Roles\n* Strategy\n* Marketing Calendar/Initiatives\n* Pool Room Marketing Section", position: 7, deadline_in: 12, feedback_link: nil},
        {name: "Rocketship Solutions", description: "* Team/Roles\n* Processes (SOW)\n* Dedicated Solutions/PM\n* Campaign Live Calendar\n* Pool Room Rocketship Solutions", position: 8, deadline_in: 14, feedback_link: nil},
        {name: "People and Culture", description: "* Review Processes\n* Cultural Initiatives \n* Events", position: 9, deadline_in: 21, feedback_link: nil},
        {name: "Your Role", description: "* JD and KPIs\n* Reporting Lines / Key Relationships\n* Why we're investing in this role\n* What success looks like\n* Probation Pathways (3-6mo goals)", position: 10, deadline_in: 30, feedback_link: nil}
      ],
      [
        {name: "Recruitment, Expectations and Purpose", description: "https//sapling.typeform.com/to/tyGEPU", position: 1, deadline_in: 7, feedback_link: nil},
        {name: "Orientation and Onboarding", description: "https//sapling.typeform.com/to/xmUiQf", position: 2, deadline_in: 30, feedback_link: nil},
        {name: "Teamwork and Productivity", description: "https//sapling.typeform.com/to/gBZ2z4", position: 3, deadline_in: 60, feedback_link: nil},
        {name: "Scaling Success", description: "https//sapling.typeform.com/to/DKS5yR", position: 4, deadline_in: 90, feedback_link: nil},
        {name: "Onboarding Road-Map", description: "Transitions are critical times when small differences in you’re a actions can have disproportionate impacts on results. Your Onboarding Road-Map will help you build momentum in your new role.\n\nToday is when the ramping-up process starts. During these first days, get accustomed to the software you'll be using, start with small projects and make sure you have clear goals to achieve. \n\nStarting a new job can be tough. But having a clearly laid out plan helps to understand what you need to learn, when you'll learn it and how you're going to accomplish each goal. \n\nBest of Luck", position: 5, deadline_in: 0, feedback_link: nil}
      ],
      [
        {name: "1", description: "1", position: 1, deadline_in: 7, feedback_link: nil},
        {name: "2", description: "2", position: 2, deadline_in: 30, feedback_link: nil}
      ],
      [],
      [
        {name: "1", description: "X", position: 1, deadline_in: 7, feedback_link: nil},
        {name: "2", description: "Test", position: 2, deadline_in: 20, feedback_link: nil}
      ],
      [],
      [],
      []
    ]

    roadmaps.each_with_index do |name, index|
      roadmap = team.roadmaps.create(name: name)

      roadmap.milestones.create! roadmap_milestones[index]
    end
  end
end

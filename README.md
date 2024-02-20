
# Sapling
Sapling is a HR application for mid-sized companies to automate and elevate their employee experience, with deep integrations with all the google applications your team already knows and loves.

## System Requirements

* Ruby version  2.7.4
* Rails version  4.2.7.1
* PostgreSQL 9.5
* MongoDB v3.2 (Only for analytics data reporting)
     * Installing mondoDB on local box
        * (https://docs.mongodb.com/v3.2/administration/install-community/)
        * or Sapling wiki (https://saplinghr.atlassian.net/wiki/spaces/ENGINEERIN/pages/278396929/Install+MongoDB+locally-Ubuntu+Mac) 
* Redis (`https://www.digitalocean.com/community/tutorials/how-to-install-and-use-redis`)
* Image Magick (`https://github.com/ImageMagick/ImageMagick`)

## Getting Started
* Add your ssh keys in your Git Profile
* Clone repo and open project folder from terminal
    * `git clone git@github.com:sapling-hr/api-svc.git`
    * cd `api-svc`
* Run `bundle install` to install all dependencies
* Setup development  environment (https://saplinghr.atlassian.net/wiki/spaces/TB/pages/1031241966/How+to+setup+Dev+Env)
* Update Application.yml with your postgres keys
* Add `127.0.0.1 rocketship.sapling.localhost` in `hosts` file
* Start sidekiq `sidekiq`
* Setup database
    *  Run `RAILS_ENV=development rake db:create`
    *  Run `RAILS_ENV=development rake db:migrate`
    *  Run `RAILS_ENV=development rake db:seed`
* Run server `rails s -b 0.0.0.0`

## Built With

* [Sidekiq][1]
* [Devise][2]
* [Attr-Encrypted][3]

## Integrations
* [Bugsnag][4]
* [NewRelic][5]
* [Algolia][6]
* [HelloSign][7]
* [Bamboo Hr][8]
* [Namely][9]
* [Paylocity][10]
* [ADP-WFN][11]
* [Gsuite][12]
* [Lever][13]
* [Google Auth][14]
* [GreenHouse][15]
* [SmartRecruiters][16]
* [Workable][17]
* [Slack][18]
## How to Run Test Suite
Test cases are written using `rspec` and `capabara`. All the test cases are tested by `CircleCi` for every branch that is pushed to Sapling's github repository.

Anyone how want to run it localy can use following process:
1. To prepare test database run this:
    * `rake db:test:prepare`
2. To run all the test cases use this:
    * `rspec`

## Services
* CloudFlare
* Puma
* Nginx
* CloudClimate
* CircleCi
* Google-SSO
* One-Login

## Search Engines
* Algolia

## Jobs Queues
* Sidekiq
* Whenever

##
## Deployment Instructions
### Following are the steps to add new ssh key to any server:

1.  Open ssh folder ~/.ssh
2.  Open id_rsa.pub file
3.  Copy content of public file
4.  Go  to the project Sapling folder from terminal
5.  Login to the server ssh deployer@<server-ip>
6.  Open ssh folder using command cd .ssh
7.  Open authorized_keys file using command nano authorized_keys
8.  Add new key at the end of file
9.  Save the file and now server can be accessed using new key
### To Run Deployment

##### Requirement
* [Capistrano][19]
##### Commands
* `cap <environment> deploy`


## Best Practices
Recommended guide for development
* [Style Guide][20]

  [1]: https://sidekiq.org/
  [2]: https://github.com/plataformatec/devise
  [3]: https://github.com/attr-encrypted/attr_encrypted
  [4]: https://www.bugsnag.com/
  [5]: https://newrelic.com/
  [6]: https://www.algolia.com
  [7]: https://www.hellosign.com
  [8]: https://www.bamboohr.com
  [9]: https://www.namely.com/
  [10]: https://www.paylocity.com/
  [11]: https://www.adp.com/video/WorkforceNow-demo.aspx
  [12]: https://gsuite.google.com/
  [13]: https://www.lever.co/integrations
  [14]: https://richonrails.com/articles/google-authentication-in-ruby-on-rails/
  [15]: http://www.greenhouse.io/partners
  [16]: https://www.smartrecruiters.com/
  [17]: https://www.workable.com
  [18]: https://help.lever.co/hc/en-us/articles/206344605
  [19]: https://github.com/capistrano/capistrano
  [20]: https://github.com/bbatsov/ruby-style-guide

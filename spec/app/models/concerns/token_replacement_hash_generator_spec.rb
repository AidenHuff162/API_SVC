require 'rails_helper'

RSpec.describe TokenReplacementHashGenerator, type: :concern do
  describe 'get tokens hash' do
    before(:all) do
      company =  create(:company, subdomain: 'tokenreplacement')
      @user = create(:user, company: company)
      paperwork_request = create(:paperwork_request, :request_skips_validate, user: @user)
      @token_hash = paperwork_request.getTokensHash(paperwork_request.user)
    end
    
    it 'should match Hire name' do
      expect(@token_hash["Hire Name"]).to eq(@user.full_name)
    end

    it 'should match hire full name' do
      expect(@token_hash["Hire Full Name"]).to eq(@user.full_name)
    end

    it 'should match hire first name' do
      expect(@token_hash["First Name"]).to eq(@user.first_name)
    end

    it 'should match hire preferred name' do
      expect(@token_hash["Hire Preferred/ First Name"]).to eq(@user.preferred_name)
    end

    it 'should match hire last name' do
      expect(@token_hash["Hire Last Name"]).to eq(@user.last_name)
    end

    it 'should match hire personal email' do
      expect(@token_hash["Hire Email"]).to eq(@user.personal_email)
    end

    it 'should match hire title' do
      expect(@token_hash["Hire Title"]).to eq(@user.title)
    end

    it 'should match hire location' do
      expect(@token_hash["Hire Location"]).to eq(@user.location&.name || '')
    end

    it 'should match hire Start Date' do
      expect(@token_hash["Hire Start Date"]).to eq(with_company_format(@user.start_date, @company))
    end

    it 'should match name' do
      expect(@token_hash["Name"]).to eq(@user.full_name)
    end

    it 'should match full name' do
      expect(@token_hash["Full Name"]).to eq(@user.full_name)
    end

    it 'should match first name' do
      expect(@token_hash["First Name"]).to eq(@user.first_name)
    end

    it 'should match preferred name' do
      expect(@token_hash["Preferred/ First Name"]).to eq(@user.preferred_name)
    end

    it 'should match last name' do
      expect(@token_hash["Last Name"]).to eq(@user.last_name)
    end

    it 'should match Company email' do
      expect(@token_hash["Company Email"]).to eq(@user.email)
    end

    it 'should match personal email' do
      expect(@token_hash["Personal Email"]).to eq(@user.personal_email)
    end

    it 'should match Job Title' do
      expect(@token_hash["Job Title"]).to eq(@user.title)
    end

    it 'should match location' do
      expect(@token_hash["Location"]).to eq(@user.location&.name || '')
    end

    it 'should match Start Date' do
      expect(@token_hash["Start Date"]).to eq(with_company_format(@user.start_date, @company))
    end

    it 'should match user Current Start Date' do
      expect(@token_hash["Current Start Date"]).to eq(with_company_format(@user.start_date, @company))

    end

    it 'should match user Access Permission' do
      expect(@token_hash["Access Permission"]).to eq(@user.user_role&.name || '')
    end
  end
  
  private
 
   def with_company_format(date, company)
     TimeConversionService.new(company).perform(date) rescue ' '
   end
end

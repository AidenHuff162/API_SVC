# require 'rails_helper'

# RSpec.describe CompanyForm, type: :model do
#   subject(:form) { CompanyForm.new(attributes_for(:company)) }

#   describe 'Validation' do
#     describe 'Name' do
#       it { is_expected.to validate_presence_of(:name) }
#     end

#     describe 'Time Zone' do
#       it do
#         is_expected.to validate_inclusion_of(:time_zone)
#           .in_array(ActiveSupport::TimeZone.us_zones.map(&:name))
#       end
#     end

#     describe 'Subdomain' do
#       it { is_expected.to validate_presence_of(:subdomain) }

#       it 'is not allowed to create with same subdomain' do
#         create(:company, subdomain: form.subdomain)

#         form.valid?

#         expect(form.errors[:subdomain]).to include('has already been taken')
#       end

#       it 'not allows reserved values' do
#         form.subdomain = 'www'
#         is_expected.not_to be_valid
#       end

#       it 'not allows values that starts with hyphen' do
#         form.subdomain = '-pam'
#         is_expected.not_to be_valid
#       end

#       it 'not allows values that ends with hyphen' do
#         form.subdomain = 'pam-'
#         is_expected.not_to be_valid
#       end

#       it 'not allows uri values with protocol' do
#         form.subdomain = 'https://example.com'
#         expect(form).not_to be_valid
#       end

#       it 'not allows uri values with port' do
#         form.subdomain = 'example.com:3000'
#         is_expected.not_to be_valid
#       end

#       it 'not allows uri values with path' do
#         form.subdomain = 'example.com/some_resource'
#         is_expected.not_to be_valid
#       end
#     end

#     describe 'Company values' do
#       it 'saves company values' do
#         form.company_values = [attributes_for(:company_value)]

#         form.save

#         expect(Company.first.company_values.count).to eq(1)
#       end

#       it 'removes company values if company value is in relation' do
#         company_value = create(:company_value)
#         form = CompanyForm.new(attributes_for(:company, id: company_value.company.id))
#         form.company_values = [
#           attributes_for(:company_value, id: company_value.id, _destroy: 1)
#         ]

#         form.save

#         is_expected.to be_valid
#         expect(CompanyValue).not_to be_any
#       end

#       it 'doesnt remove company values if company value isnt in relation' do
#         company_value = create(:company_value)
#         form.company_values = [
#           attributes_for(:company_value, id: company_value.id, _destroy: 1)
#         ]

#         form.save

#         is_expected.to be_valid
#         expect(company_value.reload).to be_present
#       end

#       it 'not allows with invalid company value' do
#         form.company_values = [attributes_for(:company_value, name: '')]

#         is_expected.not_to be_valid
#       end
#     end

#     describe 'Milestones' do
#       it 'saves milestones' do
#         form.milestones = [attributes_for(:milestone, milestone_image: attributes_for(:milestone_image))]

#         form.save

#         is_expected.to be_valid
#         expect(Company.first.milestones.count).to eq(1)
#       end

#       it 'not allows with invalid milestone' do
#         form.milestones = [attributes_for(:milestone, milestone_image: nil)]

#         is_expected.to be_valid
#       end
#     end

#     describe 'Display logo image' do
#       it 'saves display logo image' do
#         form.display_logo_image = attributes_for(:display_logo_image, :for_rocketship)

#         form.save

#         expect(Company.first.display_logo_image.file).to be_present
#       end
#     end

#     describe 'Landing page image' do
#       it 'saves langing page image' do
#         form.landing_page_image = attributes_for(:landing_page_image)

#         form.save

#         expect(Company.first.landing_page_image.file).to be_present
#       end
#     end
#   end
# end

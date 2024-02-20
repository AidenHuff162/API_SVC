require 'rails_helper'

RSpec.describe CustomFieldOption, type: :model do
  let(:company){ FactoryGirl.create(:company)}
  let(:gender) { FactoryGirl.create(:custom_field, name: 'Gender A', section: 'personal_info', field_type: 'mcq', company: company) }
  let(:female) { FactoryGirl.create(:custom_field_option, option: 'female', position: 0, custom_field: gender)}
  let(:male) { FactoryGirl.create(:custom_field_option, option: 'male', position: 1, custom_field: gender)}

  describe 'Associations' do
    it { is_expected.to belong_to(:owner).class_name('User') }
    it { is_expected.to belong_to(:custom_field) }
    it { is_expected.to have_many(:custom_field_values) }
    it { is_expected.to have_many(:users) }
    it { is_expected.to have_many(:unscoped_users) }
    it { should accept_nested_attributes_for(:custom_field_values).allow_destroy(true) }
  end

  describe 'Validation' do
    it "should raise error for name uniqueness" do
      female.option = male.option
      expect{female.save!}.to raise_error(ActiveRecord::RecordInvalid , /is already in use./)
    end

    it "should not raise error for name uniqueness" do
      female.option = "other"
      expect(female.save!).to eq(true)
    end
  end

  describe "get custom field option" do
    it "should return Custom Field Option with name" do
      expect(CustomFieldOption.get_custom_field_option(gender, female.option).id).to eq(female.id)
    end

    it "should not return Custom Field Option with new name" do
      expect(CustomFieldOption.get_custom_field_option(gender, "other")).to eq(nil)
    end
  end

  describe "create custom field option" do
    it "should return Custom Field Option" do
      expect(CustomFieldOption.create_custom_field_option(company, gender.name, female.option).id).to eq(female.id)
    end

    it "should create new Custom Field Option" do
      res = CustomFieldOption.create_custom_field_option(company, gender.name, "other")
      expect(res.option).to eq("other")
    end
  end
end

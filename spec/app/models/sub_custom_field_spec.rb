require 'rails_helper'

RSpec.describe SubCustomField, type: :model do
  describe 'associations' do
  	it{should belong_to(:custom_field)}
  	it{should have_many(:custom_field_values).dependent(:destroy)}
  	it{should accept_nested_attributes_for(:custom_field_values)}
  end
  describe 'enum' do
  	it do
      should define_enum_for(:field_type).
      with(short_text: 0, long_text: 1, multiple_choice: 2, confirmation: 3, mcq: 4, social_security_number: 5, date: 6, address: 7, coworker: 8, multi_select: 9, number: 10, social_insurance_number: 11)
    end
  end
  describe 'helper methods' do
  	let(:company){ create(:company) }
  	let(:nick){ create(:nick, company: company)}
  	let(:custom_field){ create(:custom_field, company: company) }
  	let(:sub_custom_field){ create(:sub_custom_field, custom_field: custom_field) }
  	context 'get_sub_custom_field_values_by_user' do
  		let(:peter){ create(:peter, company: company) }
  		let!(:custom_field_value){ create(:custom_field_value, user: nick, sub_custom_field: sub_custom_field)}
  		it 'should return cfv for user' do
  			expect(sub_custom_field.get_sub_custom_field_values_by_user(nick.id)).to_not eq(nil) 
  		end
  		it 'should not return cfv for non associated user' do
  			expect(sub_custom_field.get_sub_custom_field_values_by_user(peter.id)).to eq(nil)
  		end
  	end
  	context 'show_sub_custom_fields' do
  		let(:address_field){ create(:custom_field, company: company, field_type: 7) }
  		it 'should return false if custom_field type is not currency or address' do
  			expect(SubCustomField.show_sub_custom_fields(custom_field)).to eq(false)
  		end
  		it 'should return true if custom_field type is currency or address' do
  			expect(SubCustomField.show_sub_custom_fields(address_field)).to eq(true)
  		end
  	end	
  	context 'get_sub_custom_field' do
  		it 'should return scf if cf is present' do
  			expect(SubCustomField.get_sub_custom_field(company, custom_field.name, sub_custom_field.name))
  			.to eq(sub_custom_field)
  		end
  		it 'should return scf if cf passed as default_field' do
  			expect(SubCustomField.get_sub_custom_field(company, nil, sub_custom_field.name, custom_field))
  			.to eq(sub_custom_field)
  		end
  		it 'should return if wrong name of cf is passed' do
  			expect(SubCustomField.get_sub_custom_field(company, "custom_field.name", sub_custom_field.name))
  			.to eq(nil)
  		end
  	end
  end
end

require 'rails_helper'

RSpec.describe CustomTables::AssignCustomFieldValue do

  let(:company) { create(:company, subdomain: 'foo') }
  let(:employee) { create(:user, state: :active, current_stage: :registered, company: company) }
  
  subject(:assign_values_to_user) { ::CustomTables::AssignCustomFieldValue.new }

  describe '#Assign Values To User' do
    context 'should assign values of role information table' do
      before do
        @custom_table = employee.company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information])
        @role_information_ctus = create(:role_information_custom_snapshot, user_id: employee.id, custom_table_id: @custom_table.id, effective_date: Date.today.strftime("%B %d, %Y"))
        @effective_date_field = @custom_table.custom_fields.find_by(name: 'Effective Date')
        @role_information_ctus.custom_snapshots.create(custom_field_id: @effective_date_field.id, custom_field_value: Date.today.strftime("%B %d, %Y"))
        assign_values_to_user.assign_values_to_user(@role_information_ctus.reload)
      end
      
      context 'should assign custom field custom snapshot value' do
        it 'should assign effective date value to user' do
          snapshot_value = CustomSnapshot.where(custom_field_id: @effective_date_field.id, custom_table_user_snapshot_id: @role_information_ctus.id).first.custom_field_value
          expect(employee.get_custom_field_value_text(@effective_date_field.name, false, nil, nil, true, @effective_date_field.id, false, true)).to eq(snapshot_value.to_date.to_s)
        end
      end

      context 'should assign preference fields custom snapshot value to user' do
        it 'should assign manager value to user' do 
          snapshot_value = CustomSnapshot.where(preference_field_id: 'man', custom_table_user_snapshot_id: @role_information_ctus.id).first.custom_field_value
          expect(employee.reload.manager_id).to eq(snapshot_value.to_i)
        end

        it 'should assign title value to user' do 
          snapshot_value = CustomSnapshot.where(preference_field_id: 'jt', custom_table_user_snapshot_id: @role_information_ctus.id).first.custom_field_value
          expect(employee.reload.title).to eq(snapshot_value)
        end

        it 'should assign department value to user' do 
          snapshot_value = CustomSnapshot.where(preference_field_id: 'dpt', custom_table_user_snapshot_id: @role_information_ctus.id).first.custom_field_value
          expect(employee.reload.team_id).to eq(snapshot_value.to_i)
        end

        it 'should assign location value to user' do 
          snapshot_value = CustomSnapshot.where(preference_field_id: 'loc', custom_table_user_snapshot_id: @role_information_ctus.id).first.custom_field_value
          expect(employee.reload.location_id).to eq(snapshot_value.to_i)
        end
      end   
    end

    context 'should assign values of employment status table' do
      before do 
        @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status])
        @employment_status_ctus = create(:employment_status_custom_snapshot, user_id: employee.id, custom_table_id: @custom_table.id, effective_date: Date.today)
        @custom_fields = @custom_table.custom_fields
        @short_text_field = @custom_fields.find_by(field_type: 0)
        @employment_status_field = @custom_fields.find_by(field_type: 13)
        @effective_date_field = @custom_table.custom_fields.find_by(name: 'Effective Date')
        @employment_status_ctus.custom_snapshots.create(custom_field_id: @effective_date_field.id, custom_field_value: Date.today.strftime("%B %d, %Y"))
        @employment_status_ctus.custom_snapshots.create(custom_field_id: @employment_status_field.id, custom_field_value: @employment_status_field.custom_field_options.find_by(option: 'Full Time').try(:id))
        @employment_status_ctus.custom_snapshots.create(custom_field_id: @short_text_field.id, custom_field_value: 'ok')
        assign_values_to_user.assign_values_to_user(@employment_status_ctus.reload)
      end

      context 'should assign custom field custom snapshot value' do
        it 'should assign effective date value to user' do
          snapshot_value = CustomSnapshot.where(custom_field_id: @effective_date_field.id, custom_table_user_snapshot_id: @employment_status_ctus.id).first.custom_field_value
          expect(employee.get_custom_field_value_text(@effective_date_field.name, false, nil, nil, true, @effective_date_field.id, false, true)).to eq(snapshot_value.to_date.to_s)
        end
        
        it 'should assign short text custom field custom snapshot value to user' do 
          snapshot_value = CustomSnapshot.where(custom_field_id: @short_text_field.id, custom_table_user_snapshot_id: @employment_status_ctus.id).first.custom_field_value
          expect(employee.get_custom_field_value_text(@short_text_field.name, false, nil, nil, true, @short_text_field.id, false, true)).to eq(snapshot_value)
        end 

        it 'should assign employment status custom snapshot value to user' do 
          snapshot_value = CustomSnapshot.where(custom_field_id: @employment_status_field.id, custom_table_user_snapshot_id: @employment_status_ctus.id).first.custom_field_value
          expect(employee.get_custom_field_value_text(@employment_status_field.name, false, nil, nil, true, @employment_status_field.id, false, true)).to eq(snapshot_value.to_i)
        end   
      end

      context 'should assign preference fields custom snapshot value to user' do
        it 'should assign manager value to user' do 
          snapshot_value = CustomSnapshot.where(preference_field_id: 'st', custom_table_user_snapshot_id: @employment_status_ctus.id).first.custom_field_value
          expect(employee.reload.state).to eq(snapshot_value)
        end
      end
    end

    context 'should assign values of compensation table' do
      before do 
        @custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:compensation])
        @compensation_ctus = create(:custom_table_user_snapshot, user_id: employee.id, custom_table_id: @custom_table.id, effective_date: Date.today)
        @custom_fields = @custom_table.custom_fields
        @short_text_field = @custom_fields.find_by(field_type: 0)
        @long_text_field = @custom_fields.find_by(field_type: 1)
        @currency_field = @custom_fields.find_by(field_type: 14)
        @effective_date_field = @custom_fields.find_by(name: 'Effective Date')
        @compensation_ctus.custom_snapshots.create(custom_field_id: @effective_date_field.id, custom_field_value: Date.today.strftime("%B %d, %Y"))
        @compensation_ctus.custom_snapshots.create(custom_field_id: @currency_field.id, custom_field_value: 'USD|200')
        @compensation_ctus.custom_snapshots.create(custom_field_id: @short_text_field.id, custom_field_value: 'ok')
        @compensation_ctus.custom_snapshots.create(custom_field_id: @long_text_field.id, custom_field_value: 'ok ok ok ok')
        assign_values_to_user.assign_values_to_user(@compensation_ctus.reload)
      end

      context 'should assign custom field custom snapshot value' do
        it 'should assign effective date value to user' do
          snapshot_value = CustomSnapshot.where(custom_field_id: @effective_date_field.id, custom_table_user_snapshot_id: @compensation_ctus).first.custom_field_value
          expect(employee.get_custom_field_value_text(@effective_date_field.name, false, nil, nil, true, @effective_date_field.id, false, true)).to eq(snapshot_value.to_date.to_s)
        end
        
        it 'should assign currency custom field custom snapshot value to user' do 
          snapshot_value = CustomSnapshot.where(custom_field_id: @currency_field.id, custom_table_user_snapshot_id: @compensation_ctus.id).first.custom_field_value
          expect(employee.get_custom_field_value_text(@currency_field.name, false, nil, nil, true, @currency_field.id, false, true)).to eq(snapshot_value)
        end

        it 'should assign short text custom field custom snapshot value to user' do 
          snapshot_value = CustomSnapshot.where(custom_field: @short_text_field.id, custom_table_user_snapshot_id: @compensation_ctus.id).first.custom_field_value
          expect(employee.get_custom_field_value_text(@short_text_field.name, false, nil, nil, true, @short_text_field.id, false, true)).to eq(snapshot_value)
        end

        it 'should assign long text custom field custom snapshot value to user' do 
          snapshot_value = CustomSnapshot.where(custom_field: @long_text_field.id, custom_table_user_snapshot_id: @compensation_ctus.id).first.custom_field_value
          expect(employee.get_custom_field_value_text(@long_text_field.name, false, nil, nil, true, @long_text_field.id, false, true)).to eq(snapshot_value)
        end   
      end
    end

    context 'should assign values of timeline table' do
      before do 
        @custom_table = create(:timeline_custom_table_with_phone_currency_and_text_field_custom_snapshots, company: company, user: employee)
        @timeline_ctus = @custom_table.custom_table_user_snapshots.find_by(user_id: employee.id)
        @effective_date_field = @custom_table.custom_fields.find_by(name: 'Effective Date')
        @timeline_ctus.custom_snapshots.create(custom_field_id: @effective_date_field.id, custom_field_value: Date.today.strftime("%B %d, %Y"))
        assign_values_to_user.assign_values_to_user(@timeline_ctus)
      end

      context 'should assign custom field custom snapshot value' do
        it 'should assign effective date custom field custom snapshot value to user' do 
          snapshot_value = CustomSnapshot.where(custom_field_id: @effective_date_field.id, custom_table_user_snapshot_id: @timeline_ctus.id).first.custom_field_value
          expect(employee.get_custom_field_value_text(@effective_date_field.name, false, nil, nil, true, @effective_date_field.id, false, true)).to eq(snapshot_value.to_date.to_s)
        end

        it 'should assign currency field custom snapshot value to user' do 
          custom_field = @custom_table.custom_fields.find_by(field_type: 14)
          snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: @timeline_ctus.id).first.custom_field_value
          expect(employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value)
        end

        it 'should assign phone field custom snapshot value to user' do 
          custom_field = @custom_table.custom_fields.find_by(field_type: 8)
          snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: @timeline_ctus.id).first.custom_field_value
          expect(employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value)
        end

        it 'should assign text field custom snapshot value to user' do 
          custom_field = @custom_table.custom_fields.find_by(field_type: 0)
          snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: @timeline_ctus.id).first.custom_field_value
          expect(employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value)
        end
      end 
    end

    context 'should assign values of standard table' do
      before do 
        @custom_table = create(:standarad_custom_table_with_phone_currency_and_text_field_custom_snapshots, company: company, user: employee)
        @timeline_ctus = @custom_table.custom_table_user_snapshots.find_by(user_id: employee.id)
        assign_values_to_user.assign_values_to_user(@timeline_ctus)
      end

      context 'should assign custom field custom snapshot value' do
        it 'should assign currency field custom snapshot value to user' do 
          custom_field = @custom_table.custom_fields.find_by(field_type: 14)
          snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: @timeline_ctus.id).first.custom_field_value
          expect(employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value)
        end

        it 'should assign phone field custom snapshot value to user' do 
          custom_field = @custom_table.custom_fields.find_by(field_type: 8)
          snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: @timeline_ctus.id).first.custom_field_value
          expect(employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value)
        end

        it 'should assign text field custom snapshot value to user' do 
          custom_field = @custom_table.custom_fields.find_by(field_type: 0)
          snapshot_value = CustomSnapshot.where(custom_field_id: custom_field.id, custom_table_user_snapshot_id: @timeline_ctus.id).first.custom_field_value
          expect(employee.get_custom_field_value_text(custom_field.name, false, nil, nil, true, custom_field.id, false, true)).to eq(snapshot_value)
        end
      end 
    end
  end
end

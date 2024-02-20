require 'rails_helper'

RSpec.describe HrisIntegrationsService::Xero::ManageSaplingUserInXero do
  let(:company) { create(:company) }
  let(:location) { create(:location, company: company) }
  let(:xero_integration_inventory) {create(:integration_inventory, display_name: 'Xero', status: 2, category: 0, data_direction: 1, enable_filters: false, api_identifier: 'xero')}
  let(:xero) {create(:integration_instance, api_identifier: 'xero', state: 'active', integration_inventory_id: xero_integration_inventory.id, name: 'Instance no.1', company_id: company.id)}
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company, location: location) } 
  let(:update_user) { create(:user, state: :active, current_stage: :registered, company: company, location: location, xero_id: '123') } 

  before(:all) do
    WebMock.disable_net_connect!
  end

  before(:each) do
    allow_any_instance_of(HrisIntegrationsService::Xero::Helper).to receive(:refresh_token).and_return(xero)
    allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:authenticate_access_token).and_return(true)

  end

  describe '#create_profile' do
    context 'Create Sapling Profile In Xero' do
      before(:each) do
        gender = company.custom_fields.find_by_name('Gender')
        FactoryGirl.create(:custom_field_value, custom_field: gender, user: user, custom_field_option_id: gender.custom_field_options.take.id)
      end

      it 'should create user in Xero' do
        xero.stub(:employee_group) {"xyz"}
        config = xero.integration_inventory.integration_configurations.new
        config.field_name = "Employee Group"
        config.dropdown_options = [{label: "xyz", value: "xyz"}]
        config.integration_inventory_id = xero_integration_inventory.id
        config.category = "credentials"
        config.save!
        ok = double('ok?', ok?: true)
        response = double('body', :body => JSON.generate({'Employees'=>['EmployeeID'=>'456']}), :message => 'OK', :code => 200, :status => ok, :ok? => true)
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(response)

        allow_any_instance_of(HrisIntegrationsService::Xero::Helper).to receive(:fetch_integration).and_return(xero)
        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(user).perform('create')
        expect(user.reload.xero_id).to eq('456')
      end

      it 'should not create user in Xero if data is invalid' do
        xero.stub(:employee_group) {"xyz"}
        config = xero.integration_inventory.integration_configurations.new
        config.field_name = "Employee Group"
        config.dropdown_options = [{label: "xyz", value: "xyz"}]
        config.integration_inventory_id = xero_integration_inventory.id
        config.category = "credentials"
        config.save!
        body = double('body', :body => JSON.generate({'Employees'=>['EmployeeID'=>'456']}), :message => 'Unprocessable Entity', :code => 422)
        response = double('response', response: body)
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(response)

        allow_any_instance_of(HrisIntegrationsService::Xero::Helper).to receive(:fetch_integration).and_return(xero)
        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(user).perform('create')
        expect(user.reload.xero_id).to eq(nil)
      end

      it 'should reutrn 500 if there is some exception' do
        xero.stub(:employee_group) {"xyz"}
        config = xero.integration_inventory.integration_configurations.new
        config.field_name = "Employee Group"
        config.dropdown_options = [{label: "xyz", value: "xyz"}]
        config.integration_inventory_id = xero_integration_inventory.id
        config.category = "credentials"
        config.save!
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_raise(Exception)

        allow_any_instance_of(HrisIntegrationsService::Xero::Helper).to receive(:fetch_integration).and_return(xero)
        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(user).perform('create')
        expect(user.reload.xero_id).to eq(nil)
      end
    end
  end

  describe '#udpate_profile' do
    before(:each) do
      ok = double('ok?', ok?: true)
      @response = double('body', :body => JSON.generate({'Employees'=>['EmployeeID'=>'456']}), :message => 'OK', :code => 200, :status => ok)
    end

    context 'Update name In Xero' do
      it 'should update name in Xero' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(@response)

        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['first_name', 'last_name'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in Xero - First Name, Last Name - Success')
      end

      it 'should reutrn 500 if there is some exception' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_raise(Exception)
        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['first_name', 'last_name'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in Xero - First Name, Last Name - ERROR')
      end
    end

    context 'Update date of birth In Xero' do
      it 'should date of birth in Xero' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(@response)
        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['date of birth'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in Xero - Date Of Birth - Success')
      end

      it 'should reutrn 500 if there is some exception' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_raise(Exception)
        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['date of birth'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in Xero - Date Of Birth - ERROR')
      end
    end

    context 'Update home address In Xero' do
      it 'should home address in Xero' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(@response)
        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['line1', 'line2', 'zip', 'city', 'state'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in Xero - Home Address - Success')
      end

      it 'should reutrn 500 if there is some exception' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_raise(Exception)
        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['line1', 'line2', 'zip', 'city', 'state'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in Xero - Home Address - ERROR')
      end
    end

    context 'Update start_date In Xero' do
      it 'should start_date in Xero' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(@response)

        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['start_date'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in Xero - Start Date - Success')
      end

      it 'should reutrn 500 if there is some exception' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_raise(Exception)
        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['start_date'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in Xero - Start Date - ERROR')
      end
    end

    context 'Update job title In Xero' do
      it 'should job title in Xero' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(@response)

        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['title'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in Xero - Job Title - Success')
      end

      it 'should reutrn 500 if there is some exception' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_raise(Exception)
        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['title'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in Xero - Job Title - ERROR')
      end
    end

    context 'Update personal email In Xero' do
      it 'should personal email in Xero' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(@response)

        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['personal_email'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in Xero - Email Address - Success')
      end

      it 'should reutrn 500 if there is some exception' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_raise(Exception)
        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['personal_email'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in Xero - Email Address - ERROR')
      end
    end

    context 'Update gender In Xero' do
      before(:each) do
        gender = company.custom_fields.find_by_name('Gender')
        FactoryGirl.create(:custom_field_value, custom_field: gender, user: update_user, custom_field_option_id: gender.custom_field_options.take.id)
      end
      it 'should gender in Xero' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(@response)

        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['gender'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in Xero - Gender - Success')
      end

      it 'should reutrn 500 if there is some exception' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_raise(Exception)
        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['gender'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in Xero - Gender - ERROR')
      end
    end

    context 'Update mobile phone number In Xero' do
      it 'should mobile phone number in Xero' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(@response)

        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['mobile phone number'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in Xero - Mobile - Success')
      end

      it 'should reutrn 500 if there is some exception' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_raise(Exception)
        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['mobile phone number'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in Xero - Mobile - ERROR')
      end
    end

    context 'Update home phone number In Xero' do
      it 'should home phone number in Xero' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(@response)

        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['home phone number'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in Xero - Phone - Success')
      end

      it 'should reutrn 500 if there is some exception' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_raise(Exception)
        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['home phone number'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in Xero - Phone - ERROR')
      end
    end

    context 'Update employment status In Xero' do
      it 'should employment status in Xero' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(@response)

        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['employment status'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in Xero - Employement Basis - Success')
      end

      it 'should reutrn 500 if there is some exception' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_raise(Exception)
        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['employment status'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in Xero - Employement Basis - ERROR')
      end
    end

    context 'Update calculation type In Xero' do
      it 'should calculation type in Xero' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(@response)

        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['calculation type'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in Xero - Calculation Type - Success')
      end

      it 'should reutrn 500 if there is some exception' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_raise(Exception)
        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['calculation type'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in Xero - Calculation Type - ERROR')
      end
    end

    context 'Update middle name In Xero' do
      it 'should middle name in Xero' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(@response)

        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['middle name'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in Xero - Middle Name - Success')
      end

      it 'should reutrn 500 if there is some exception' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_raise(Exception)
        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('update', ['middle name'])
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in Xero - Middle Name - ERROR')
      end
    end
  end

  describe '#terminate_user' do
    context 'terminate Sapling Profile In Xero' do
      it 'should terminate user in Xero' do
        ok = double('ok?', ok?: true)
        response = double('body', :body => JSON.generate({'Employees'=>['EmployeeID'=>'456']}), :message => 'OK', :code => 200, :status => ok)

        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_return(response)

        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('terminate')
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(200)
        expect(logging.action).to eq('Update Profile in Xero - Terminate User - Success')
      end

      it 'should reutrn 500 if there is some exception' do
        allow_any_instance_of(HrisIntegrationsService::Xero::HumanResource).to receive(:post).and_raise(Exception)
        ::HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(update_user).perform('terminate')
        logging = company.loggings.where(integration_name: 'Xero').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('Update Profile in Xero - Terminate User - ERROR')
      end
    end
  end
end
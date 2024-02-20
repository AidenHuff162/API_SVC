require 'rails_helper'

RSpec.describe Api::V1::AddressController, type: :controller do
	let(:current_company) { create(:company) }
  let(:current_user) { create(:user, state: :active, current_stage: :registered, company: current_company) }

  let!(:australia) { create(:australia) }
  let!(:argentina) { create(:argentina) }
  let!(:canada) { create(:canada) }
  let!(:united_kingdom) { create(:united_kingdom) }
  let!(:united_states) { create(:united_states) }
  let(:ireland) { create(:ireland) }

  before do
    allow(controller).to receive(:current_user).and_return(current_user)
    allow(controller).to receive(:current_company).and_return(current_company)
  end

  describe 'GET #countries_index' do
  	context 'should not return countries index' do
  		before do
  			allow(controller).to receive(:current_company).and_return(nil)
  		end

  		it "should return not found status" do
	  		get :countries_index, format: :json
	  		expect(response.status).to eq(404)
  		end
  	end

  	context 'should return countries index' do
  		it 'should return all the countries in asc order on the basis of name with basic serializer' do
	  		get :countries_index, format: :json
	  		countries = JSON.parse(response.body)

	  		expect(response.status).to eq(200)
	  		expect(countries.count).to eq(Country.count)
	  		expect(countries).to eq(Country.order(name: :asc).as_json(only: [:id, :name, :subdivision_type, :areacode_type, :city_type, :key]))
  		end
  	end
  end

  describe 'GET #states_index' do
  	before do
  		@us = Country.find_by(name: 'United States')
  		@can = Country.find_by(name: 'Canada')
  		@aus = Country.find_by(name: 'Australia')
  		@uk = Country.find_by(name: 'United Kingdom')
  	end

  	context 'should not return states index' do
  		before do
  			allow(controller).to receive(:current_company).and_return(nil)
  		end

  		it 'should return not found status' do
	  		get :states_index, format: :json
	  		expect(response.status).to eq(404)
  		end
  	end

  	context 'should return states index' do
  		context 'company with no integration' do
  			it 'should return all the states with name serializer' do
					us = Country.find_by(name: 'United States')

					get :states_index, params: { country_id: us.id }, format: :json 
					states = JSON.parse(response.body)

					expect(response.status).to eq(200)
					expect(states.count).to eq(us.states.count)
					expect(states.first.keys).to eq(['id', 'map_value', 'value'])
				end
  		end

  		context 'company with namely integration' do
  			before do
          create(:namely, company: current_company)
        end

  			it 'should return all the states with name serializer' do
					get :states_index, params: { country_id: @us.id }, format: :json 
					states = JSON.parse(response.body)

					expect(response.status).to eq(200)
					expect(states.count).to eq(@us.states.count)
					expect(states.first.keys).to eq(['id', 'map_value', 'value'])
				end

        it 'should return states for Ireland' do
          get :states_index, params: { country_id: ireland.id }, format: :json 
          states = JSON.parse(response.body)

          expect(response.status).to eq(200)
          expect(states.count).to eq(ireland.states.count)
          expect(states.first['value']).to eq('CEN')
        end
  		end

  		context 'company with bamboo integration' do
  			before do
  				current_company = create(:with_bamboo_integration, subdomain: 'bamboo')
  				current_user = create(:user, state: :active, current_stage: :registered, company: current_company)

  				allow(controller).to receive(:current_user).and_return(current_user)
    			allow(controller).to receive(:current_company).and_return(current_company)
  			end

  			context 'should return states with key serializer for united states, canada and australia' do
	  			it 'should return states for united states' do
						get :states_index, params: { country_id: @us.id }, format: :json
						states = JSON.parse(response.body)

						expect(response.status).to eq(200)
						expect(states.count).to eq(@us.states.count)
						expect(states.first.keys).to eq(['id', 'map_value', 'value'])
						expect(states.first['value']).to eq(@us.states.order('id asc').take.key)
					end

					it 'should return states for australia' do
						get :states_index, params: { country_id: @aus.id }, format: :json 
						states = JSON.parse(response.body)

						expect(response.status).to eq(200)
						expect(states.count).to eq(@aus.states.count)
						expect(states.first.keys).to eq(['id', 'map_value', 'value'])
						expect(states.first['value']).to eq(@aus.states.order('id asc').take.key)
					end

					it 'should return states for canada' do
						get :states_index, params: { country_id: @can.id }, format: :json 
						states = JSON.parse(response.body)

						expect(response.status).to eq(200)
						expect(states.count).to eq(@can.states.count)
						expect(states.first.keys).to eq(['id', 'map_value', 'value'])
						expect(states.first['value']).to eq(@can.states.order('id asc').take.key)
					end
				end

				context 'should return states with name serializer for other countries except united states, canada and australia' do
					it 'should return states for united kingdom' do
						get :states_index, params: { country_id: @uk.id }, format: :json 
						states = JSON.parse(response.body)

						expect(response.status).to eq(200)
						expect(states.count).to eq(@uk.states.count)
						expect(states.first.keys).to eq(['id', 'map_value', 'value'])
						expect(states.first['value']).to eq(@uk.states.order('id asc').take.name)
					end
				end
  		end

  		context 'company with adp-us integration' do
  			before do
  				current_company = create(:with_adp_us_integration, subdomain: 'adp-us')
  				current_user = create(:user, state: :active, current_stage: :registered, company: current_company)

  				allow(controller).to receive(:current_user).and_return(current_user)
    			allow(controller).to receive(:current_company).and_return(current_company)
  			end

  			context 'should return states with key serializer for united states and canada' do
	  			it 'should return states for united states' do
						get :states_index, params: { country_id: @us.id }, format: :json 
						states = JSON.parse(response.body)

						expect(response.status).to eq(200)
						expect(states.count).to eq(@us.states.count)
						expect(states.first.keys).to eq(['id', 'map_value', 'value'])
						expect(states.first['value']).to eq(@us.states.order('id asc').take.key)
					end

					it 'should return states for canada' do
						get :states_index, params: { country_id: @can.id }, format: :json 
						states = JSON.parse(response.body)

						expect(response.status).to eq(200)
						expect(states.count).to eq(@can.states.count)
						expect(states.first.keys).to eq(['id', 'map_value', 'value'])
						expect(states.first['value']).to eq(@can.states.order('id asc').take.key)
					end
				end

				context 'should return states with name serializer for other countries except united states and canada' do
					it 'should return states for australia' do
						get :states_index, params: { country_id: @aus.id }, format: :json 
						states = JSON.parse(response.body)

						expect(response.status).to eq(200)
						expect(states.count).to eq(@aus.states.count)
						expect(states.first.keys).to eq(['id', 'map_value', 'value'])
						expect(states.first['value']).to eq(@aus.states.order('id asc').take.name)
					end
				end
  		end

      context 'company with adp-can integration' do
        before do
          current_company = create(:with_adp_can_integration, subdomain: 'adp-can')
          current_user = create(:user, state: :active, current_stage: :registered, company: current_company)

          allow(controller).to receive(:current_user).and_return(current_user)
          allow(controller).to receive(:current_company).and_return(current_company)
        end

        context 'should return states with key serializer for united states and canada' do
          it 'should return states for united states' do
            get :states_index, params: { country_id: @us.id }, format: :json 
            states = JSON.parse(response.body)

            expect(response.status).to eq(200)
            expect(states.count).to eq(@us.states.count)
            expect(states.first.keys).to eq(['id', 'map_value', 'value'])
            expect(states.first['value']).to eq(@us.states.order('id asc').take.key)
          end

          it 'should return states for canada' do
            get :states_index, params: { country_id: @can.id }, format: :json 
            states = JSON.parse(response.body)

            expect(response.status).to eq(200)
            expect(states.count).to eq(@can.states.count)
            expect(states.first.keys).to eq(['id', 'map_value', 'value'])
            expect(states.first['value']).to eq(@can.states.order('id asc').take.key)
          end
        end

        context 'should return states with name serializer for other countries except united states and canada' do
          it 'should return states for australia' do
            get :states_index, params: { country_id: @aus.id }, format: :json 
            states = JSON.parse(response.body)

            expect(response.status).to eq(200)
            expect(states.count).to eq(@aus.states.count)
            expect(states.first.keys).to eq(['id', 'map_value', 'value'])
            expect(states.first['value']).to eq(@aus.states.order('id asc').take.name)
          end
        end
      end

      context 'company with adp-us-and-can integration' do
        before do
          current_company = create(:with_adp_us_and_can_integration, subdomain: 'adp-us-and-can')
          current_user = create(:user, state: :active, current_stage: :registered, company: current_company)

          allow(controller).to receive(:current_user).and_return(current_user)
          allow(controller).to receive(:current_company).and_return(current_company)
        end

        context 'should return states with key serializer for united states and canada' do
          it 'should return states for united states' do
            get :states_index, params: { country_id: @us.id }, format: :json 
            states = JSON.parse(response.body)

            expect(response.status).to eq(200)
            expect(states.count).to eq(@us.states.count)
            expect(states.first.keys).to eq(['id', 'map_value', 'value'])
            expect(states.first['value']).to eq(@us.states.order('id asc').take.key)
          end

          it 'should return states for canada' do
            get :states_index, params: { country_id: @can.id }, format: :json 
            states = JSON.parse(response.body)

            expect(response.status).to eq(200)
            expect(states.count).to eq(@can.states.count)
            expect(states.first.keys).to eq(['id', 'map_value', 'value'])
            expect(states.first['value']).to eq(@can.states.order('id asc').take.key)
          end
        end

        context 'should return states with name serializer for other countries except united states and canada' do
          it 'should return states for australia' do
            get :states_index, params: { country_id: @aus.id }, format: :json 
            states = JSON.parse(response.body)

            expect(response.status).to eq(200)
            expect(states.count).to eq(@aus.states.count)
            expect(states.first.keys).to eq(['id', 'map_value', 'value'])
            expect(states.first['value']).to eq(@aus.states.order('id asc').take.name)
          end
        end
      end

  		context 'company with paylocity integration' do
  			before do
  				current_company = create(:with_paylocity_integration, subdomain: 'paylocity')
  				current_user = create(:user, state: :active, current_stage: :registered, company: current_company)

  				allow(controller).to receive(:current_user).and_return(current_user)
    			allow(controller).to receive(:current_company).and_return(current_company)
  			end

  			context 'should return states with key serializer for united states' do
	  			it 'should return states for united states' do
						get :states_index, params: { country_id: @us.id }, format: :json 
						states = JSON.parse(response.body)

						expect(response.status).to eq(200)
						expect(states.count).to eq(@us.states.count)
						expect(states.first.keys).to eq(['id', 'map_value', 'value'])
						expect(states.first['value']).to eq(@us.states.order('id asc').take.key)
					end
				end

				context 'should return states with name serializer for other countries except united states' do
					it 'should return states for australia' do
						get :states_index, params: { country_id: @aus.id }, format: :json 
						states = JSON.parse(response.body)

						expect(response.status).to eq(200)
						expect(states.count).to eq(@aus.states.count)
						expect(states.first.keys).to eq(['id', 'map_value', 'value'])
						expect(states.first['value']).to eq(@aus.states.order('id asc').take.name)
					end

					it 'should return states for canada' do
						get :states_index, params: { country_id: @can.id }, format: :json 
						states = JSON.parse(response.body)

						expect(response.status).to eq(200)
						expect(states.count).to eq(@can.states.count)
						expect(states.first.keys).to eq(['id', 'map_value', 'value'])
						expect(states.first['value']).to eq(@can.states.order('id asc').take.name)
					end

          it 'should return states for flatfile' do
            get :states_index, params: { flatfile_sates: true }, format: :json 
            states = JSON.parse(response.body)
           
            expect(response.status).to eq(200)
            expect(states.count).to eq(State.count)
            expect(states.first['name']).to eq(State.ascending(:name).take.name)
          end
				end
  		end
  	end
  end
end

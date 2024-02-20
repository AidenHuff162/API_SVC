require 'rails_helper'

RSpec.describe ImportUsersData::UploadProfileData do
  let!(:company) {create(:company)}
  let!(:current_user) { create(:user, state: :active, current_stage: :registered, role: :account_owner, company: company) }  

  describe "flatfile data upload" do
    context 'user_creation_from_flatfile' do      
      it "should_create_the_user" do
        expect(company.reload.users.count).to eq(1)
        args = { company: company, 
              data: [{"First Name"=>"flatfile", "Last Name"=>"test", "Preferred Name"=>"flatfile_test", "Company Email"=>"test@flatfile.com"}], 
              import_method: 'create_user', is_tabular: false, table_name: nil,
              current_user: current_user, upload_date: DateTime.now }
        ::ImportUsersData::UploadProfileData.new(args).perform
        expect(company.reload.users.count).to eq(2)
      end

      it "should_not_create_the_user" do
        expect(company.reload.users.count).to eq(1)
        args = { company: company, 
          data: [{"First Name"=>"", "Last Name"=>"test", "Preferred Name"=>"flatfile_test", "Company Email"=>"test@flatfile.com"}], 
          import_method: 'create_user', is_tabular: false, table_name: nil,
          current_user: current_user, upload_date: DateTime.now }
        ::ImportUsersData::UploadProfileData.new(args).perform
        expect(company.reload.users.count).to eq(1)
      end
    end

    context "Update user using Company Email" do
      context 'Uploading data in Custom Table(Employment Status) through flatfile' do
        it "should create single ctus" do
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.count
          expect(custom_table_user_snapshot).to eq(0)
          args = { company: company, 
            data: [{"Company Email"=>current_user.email, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "ythtyh"=>"zzz", "aaa"=>"zzz", "Status"=>"Active" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Employment Status',
            current_user: current_user, upload_date: DateTime.now }
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.count
          expect(custom_table_user_snapshot).to eq(1)
        end

        it "should verify that the custom_snapshots are not greater than the Custom Table(employment status) fields" do
          args = { company: company, 
            data: [{"Company Email"=>current_user.email, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "Status"=>"Active" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Employment Status',
            current_user: current_user, upload_date: DateTime.now }          
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
          custom_table_user_snapshot.custom_snapshots.create!(custom_field_id: custom_table_user_snapshot.custom_snapshots.first.custom_field_id, custom_field_value: "15/07/2021", preference_field_id: nil, custom_table_user_snapshot_id: 1)
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
        end

        it "should verify that the custom snapshots are not less than the Custom Table(employment status) fields" do
          args = { company: company, 
            data: [{"Company Email"=>current_user.email, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "Status"=>"Active" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Employment Status',
            current_user: current_user, upload_date: DateTime.now }
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
          custom_table_user_snapshot.custom_snapshots.last.delete
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
        end

        it "should replace values with previous values for missing attribues" do
          args = { company: company, 
            data: [{"Company Email"=>current_user.email, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "Status"=>"Active" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Employment Status',
            current_user: current_user, upload_date: DateTime.now }
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
          args[:data] = [{"Company Email"=>current_user.email, "Effective Date"=> "11/06/2021", "Employment Status"=>"Active", "Status"=>"Active" }]
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
        end

        it "should not upload blank Effective Date" do
          args = { company: company, 
            data: [{"Company Email"=>current_user.email, "Effective Date"=> "", "Notes"=>"dummy notes", "Employment Status"=>"Active", "ythtyh"=>"zzz", "aaa"=>"zzz", "Status"=>"Active" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Employment Status',
            current_user: current_user, upload_date: DateTime.now }
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.count
          expect(custom_table_user_snapshot).to eq(0)
          args[:data] = [{"Company Email"=>current_user.email, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "ythtyh"=>"zzz", "aaa"=>"zzz", "Status"=>"Active" }]
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.count
          expect(custom_table_user_snapshot).to eq(1) 
        end

        it "should upload phone custom field data" do
          args = { company: company, 
            data: [{"Company Email"=>current_user.email, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "Status"=>"Active" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Employment Status',
            current_user: current_user, upload_date: DateTime.now }
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
          company.custom_tables.find_by(name: "Employment Status").custom_fields.create!(company_id: company.id, section: nil, name: "Mobile Number", field_type: "phone", collect_from: "admin")
          args[:data] = [{"Company Email"=>current_user.email, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "Status"=>"Active" , "Mobile Number"=>"786575127"}]
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
        end

        it "should upload coworker custom field data" do
          args = { company: company, 
            data: [{"Company Email"=>current_user.email, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "Status"=>"Active"}], 
            import_method: 'update_user', is_tabular: true, table_name: 'Employment Status',
            current_user: current_user, upload_date: DateTime.now }
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
          company.custom_tables.find_by(name: "Employment Status").custom_fields.create!(company_id: company.id, section: nil, name: "CoWorker", field_type: "coworker", collect_from: "admin")
          args[:data] = [{"Company Email"=>current_user.email, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "Status"=>"Active" , "CoWorker"=>"Akbar.gillani+1786@trysapling.com"}]
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
        end

        it "should verify that the Custom Table(employment status) fields are greater than the custom_snapshots" do
          args = { company: company, 
            data: [{"Company Email"=>current_user.email, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "Status"=>"Active"}], 
            import_method: 'update_user', is_tabular: true, table_name: 'Employment Status',
            current_user: current_user, upload_date: DateTime.now }
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
          company.custom_tables.find_by(name: "Employment Status").custom_fields.create!(company_id: company.id, section: nil, name: "CoWorker", field_type: "coworker", collect_from: "admin")
          current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id).custom_snapshots.last.delete
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
        end

      end

      context 'Uploading data in Custom Table(Role Information) through flatfile' do      
        it "should create single ctus" do
          args = { company: company, 
            data: [{"Company Email"=>current_user.email, "Effective Date"=>"11/06/2021", "Department"=>"abc", "Job Title"=>"SSE", "Location"=>"Home Town", "Manager"=>"cbowman@rocketship.com" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Role Information',
            current_user: current_user, upload_date: DateTime.now }          
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.count
          expect(custom_table_user_snapshot).to eq(0)
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.count
          expect(custom_table_user_snapshot).to eq(1)
        end

        it "should verify that the custom_snapshots are not greater than the Custom Table(Role Information) fields" do
          args = { company: company, 
            data: [{"Company Email"=>current_user.email, "Effective Date"=>"11/06/2021", "Department"=>"abc", "Job Title"=>"SSE", "Location"=>"Home Town", "Manager"=>"cbowman@rocketship.com" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Role Information',
            current_user: current_user, upload_date: DateTime.now }          
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Role Information").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Role Information").custom_fields.count + 4)  
          custom_table_user_snapshot.custom_snapshots.create!(custom_field_id: custom_table_user_snapshot.custom_snapshots.first.custom_field_id, custom_field_value: "July 06, 2021", preference_field_id: nil, custom_table_user_snapshot_id: 1)
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Role Information").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Role Information").custom_fields.count + 4) 
        end

        it "should verify that the custom snapshots are not less than the Custom Table(Role Information) fields" do
          args = { company: company, 
            data: [{"Company Email"=>current_user.email, "Effective Date"=>"11/06/2021", "Department"=>"abc", "Job Title"=>"SSE", "Location"=>"Home Town", "Manager"=>"cbowman@rocketship.com" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Role Information',
            current_user: current_user, upload_date: DateTime.now }          
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Role Information").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Role Information").custom_fields.count + 4)  
          custom_table_user_snapshot.custom_snapshots.last.delete
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Role Information").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Role Information").custom_fields.count + 4) 
        end

        it "should replace values with previous values for missing attribues" do
          args = { company: company, 
            data: [{"Company Email"=>current_user.email, "Effective Date"=>"11/06/2021", "Department"=>"abc", "Job Title"=>"SSE", "Location"=>"Home Town", "Manager"=>"cbowman@rocketship.com" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Role Information',
            current_user: current_user, upload_date: DateTime.now }           
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Role Information").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Role Information").custom_fields.count + 4)  
          args[:data] = [{"Company Email"=>current_user.email, "Effective Date"=>"11/06/2021", "Department"=>"abc", "Location"=>"Home Town", "Manager"=>"cbowman@rocketship.com" }]
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Role Information").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Role Information").custom_fields.count + 4) 
        end
      end

      context 'Uploading data in Custom Table(Compensation) through flatfile' do      
        it "should create single ctus" do
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.count
          expect(custom_table_user_snapshot).to eq(0)
          args = { company: company, 
            data: [{"Company Email"=>current_user.email, "Effective Date"=>"11/06/2021", "Pay Rate"=> "88", "Pay Type"=>"Cash", "Pay Schedule"=>"today", "Change Reason"=>"secret", "Notes"=>"public" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Compensation',
            current_user: current_user, upload_date: DateTime.now }          
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.count
          expect(custom_table_user_snapshot).to eq(1)
        end

        it "should verify that the custom_snapshots are not greater than the Custom Table(Compensation) fields" do
          args = { company: company, 
            data: [{"Company Email"=>current_user.email, "Effective Date"=>"11/06/2021", "Pay Rate"=>"8.8", "Pay Type"=>"Cash", "Pay Schedule"=>"today", "Change Reason"=>"secret", "Notes"=>"public" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Compensation',
            current_user: current_user, upload_date: DateTime.now }          
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Compensation").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Compensation").custom_fields.count)
          custom_table_user_snapshot.custom_snapshots.create!(custom_field_id: custom_table_user_snapshot.custom_snapshots.first.custom_field_id, custom_field_value: "20/06/2020", preference_field_id: nil, custom_table_user_snapshot_id: 1)
          args[:data] = [{"Company Email"=>current_user.email, "Effective Date"=>"11/06/2021", "Pay Rate"=>"1.1", "Pay Type"=>"Cash", "Pay Schedule"=>"today", "Change Reason"=>"secret", "Notes"=>"public" }]
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Compensation").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Compensation").custom_fields.count)
        end
        
         it "should verify that the custom snapshots are not less than the Custom Table(Compensation) fields" do
          args = { company: company, 
            data: [{"Company Email"=>current_user.email, "Effective Date"=>"11/06/2021", "Pay Rate"=>"8.8", "Pay Type"=>"Cash", "Pay Schedule"=>"today", "Change Reason"=>"secret", "Notes"=>"public" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Compensation',
            current_user: current_user, upload_date: DateTime.now }           
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Compensation").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Compensation").custom_fields.count)
          custom_table_user_snapshot.custom_snapshots.last.delete
          args[:data] = [{"Company Email"=>current_user.email, "Effective Date"=>"11/06/2021", "Pay Rate"=>"1.1", "Pay Type"=>"Cash", "Pay Schedule"=>"today", "Change Reason"=>"secret", "Notes"=>"public" }]          
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Compensation").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Compensation").custom_fields.count)
        end

        it "should replace values with previous values for missing attribues" do
          args = { company: company, 
            data: [{"Company Email"=>current_user.email, "Effective Date"=>"11/06/2021", "Pay Rate"=>"8.8", "Pay Type"=>"Cash", "Pay Schedule"=>"today", "Change Reason"=>"secret", "Notes"=>"public" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Compensation',
            current_user: current_user, upload_date: DateTime.now }           
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Compensation").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Compensation").custom_fields.count)
          args[:data] = [{"Company Email"=>current_user.email, "Effective Date"=>"11/06/2021", "Pay Rate"=>"1.1", "Pay Type"=>"Cash", "Pay Schedule"=>"today", "Notes"=>"public" }]
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Compensation").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Compensation").custom_fields.count)
        end
      end

      context 'user_updation_from_flatfile' do
        let!(:nick) { create(:user, email: 'nick@test.com', first_name: 'nick', last_name: 'employee', state: :active, current_stage: :registered, role: :employee, company: company) }
        
        it "should_update_the_user" do
          args = { company: company, 
            data: [{"First Name"=>"flatfile", "Last Name"=>"test", "Company Email"=>nick.email}], 
            import_method: 'update_user', is_tabular: false, table_name: nil,
            current_user: current_user, upload_date: DateTime.now } 
          ::ImportUsersData::UploadProfileData.new(args).perform
          expect(nick.reload.first_name).to eq('flatfile')
          expect(nick.reload.last_name).to eq('test')
        end

        it "should_not_update_the_user" do
          args = { company: company, 
            data: [{"First Name"=>"", "Last Name"=>"", "Company Email"=>nick.email}], 
            import_method: 'update_user', is_tabular: false, table_name: nil,
            current_user: current_user, upload_date: DateTime.now }          
          ::ImportUsersData::UploadProfileData.new(args).perform
          expect(nick.reload.first_name).to eq('nick')
          expect(nick.reload.last_name).to eq('employee')
        end
      end
    end

    context "Update user using User ID" do
      context 'Uploading data in Custom Table(Employment Status) through flatfile' do
        it "should create single ctus" do
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.count
          expect(custom_table_user_snapshot).to eq(0)
          args = { company: company, 
            data: [{"User ID"=>current_user.id, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "ythtyh"=>"zzz", "aaa"=>"zzz", "Status"=>"Active" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Employment Status',
            current_user: current_user, upload_date: DateTime.now }           
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.count
          expect(custom_table_user_snapshot).to eq(1)
        end

        it "should verify that the custom_snapshots are not greater than the Custom Table(employment status) fields" do
          args = { company: company, 
            data: [{"User ID"=>current_user.id, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "Status"=>"Active" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Employment Status',
            current_user: current_user, upload_date: DateTime.now }           
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
          custom_table_user_snapshot.custom_snapshots.create!(custom_field_id: custom_table_user_snapshot.custom_snapshots.first.custom_field_id, custom_field_value: "15/07/2021", preference_field_id: nil, custom_table_user_snapshot_id: 1)
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
        end

        it "should verify that the custom snapshots are not less than the Custom Table(employment status) fields" do
          args = { company: company, 
            data: [{"User ID"=>current_user.id, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "Status"=>"Active" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Employment Status',
            current_user: current_user, upload_date: DateTime.now }          
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
          custom_table_user_snapshot.custom_snapshots.last.delete
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
        end

        it "should replace values with previous values for missing attribues" do
         args = { company: company, 
            data: [{"User ID"=>current_user.id, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "Status"=>"Active" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Employment Status',
            current_user: current_user, upload_date: DateTime.now }           
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
          args[:data] = [{"User ID"=>current_user.id, "Effective Date"=> "11/06/2021", "Employment Status"=>"Active", "Status"=>"Active" }]
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
        end

        it "should not upload blank Effective Date" do
         args = { company: company, 
            data: [{"User ID"=>current_user.id, "Effective Date"=> "", "Notes"=>"dummy notes", "Employment Status"=>"Active", "ythtyh"=>"zzz", "aaa"=>"zzz", "Status"=>"Active" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Employment Status',
            current_user: current_user, upload_date: DateTime.now }           
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.count
          expect(custom_table_user_snapshot).to eq(0)
          args[:data] = [{"User ID"=>current_user.id, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "ythtyh"=>"zzz", "aaa"=>"zzz", "Status"=>"Active" }]
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.count
          expect(custom_table_user_snapshot).to eq(1) 
        end

        it "should upload phone custom field data" do
         args = { company: company, 
            data: [{"User ID"=>current_user.id, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "Status"=>"Active" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Employment Status',
            current_user: current_user, upload_date: DateTime.now }
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
          company.custom_tables.find_by(name: "Employment Status").custom_fields.create!(company_id: company.id, section: nil, name: "Mobile Number", field_type: "phone", collect_from: "admin")
          args[:data] = [{"User ID"=>current_user.id, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "Status"=>"Active" , "Mobile Number"=>"786575127"}]
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
        end

        it "should upload coworker custom field data" do
          args = { company: company, 
            data: [{"User ID"=>current_user.id, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "Status"=>"Active"}], 
            import_method: 'update_user', is_tabular: true, table_name: 'Employment Status',
            current_user: current_user, upload_date: DateTime.now }          
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
          company.custom_tables.find_by(name: "Employment Status").custom_fields.create!(company_id: company.id, section: nil, name: "CoWorker", field_type: "coworker", collect_from: "admin")
          args[:data] = [{"User ID"=>current_user.id, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "Status"=>"Active" , "CoWorker"=>"Akbar.gillani+1786@trysapling.com"}]
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
        end

        it "should verify that the Custom Table(employment status) fields are greater than the custom_snapshots" do
          args = { company: company, 
            data: [{"User ID"=>current_user.id, "Effective Date"=> "11/06/2021", "Notes"=>"dummy notes", "Employment Status"=>"Active", "Status"=>"Active"}], 
            import_method: 'update_user', is_tabular: true, table_name: 'Employment Status',
            current_user: current_user, upload_date: DateTime.now }           
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
          company.custom_tables.find_by(name: "Employment Status").custom_fields.create!(company_id: company.id, section: nil, name: "CoWorker", field_type: "coworker", collect_from: "admin")
          current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id).custom_snapshots.last.delete
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Employment Status").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Employment Status").custom_fields.count + 1)  
        end
      end

      context 'Uploading data in Custom Table(Role Information) through flatfile' do      
        it "should create single ctus" do
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.count
          expect(custom_table_user_snapshot).to eq(0)
          args = { company: company, 
            data: [{"User ID"=>current_user.id, "Effective Date"=>"11/06/2021", "Department"=>"abc", "Job Title"=>"SSE", "Location"=>"Home Town", "Manager"=>"cbowman@rocketship.com" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Role Information',
            current_user: current_user, upload_date: DateTime.now }          
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.count
          expect(custom_table_user_snapshot).to eq(1)
        end

        it "should verify that the custom_snapshots are not greater than the Custom Table(Role Information) fields" do
          args = { company: company, 
            data: [{"User ID"=>current_user.id, "Effective Date"=>"11/06/2021", "Department"=>"abc", "Job Title"=>"SSE", "Location"=>"Home Town", "Manager"=>"cbowman@rocketship.com" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Role Information',
            current_user: current_user, upload_date: DateTime.now }          
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Role Information").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Role Information").custom_fields.count + 4)  
          custom_table_user_snapshot.custom_snapshots.create!(custom_field_id: custom_table_user_snapshot.custom_snapshots.first.custom_field_id, custom_field_value: "July 06, 2021", preference_field_id: nil, custom_table_user_snapshot_id: 1)
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Role Information").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Role Information").custom_fields.count + 4) 
        end

        it "should verify that the custom snapshots are not less than the Custom Table(Role Information) fields" do
          args = { company: company, 
            data: [{"User ID"=>current_user.id, "Effective Date"=>"11/06/2021", "Department"=>"abc", "Job Title"=>"SSE", "Location"=>"Home Town", "Manager"=>"cbowman@rocketship.com" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Role Information',
            current_user: current_user, upload_date: DateTime.now }          
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Role Information").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Role Information").custom_fields.count + 4)  
          custom_table_user_snapshot.custom_snapshots.last.delete
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Role Information").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Role Information").custom_fields.count + 4) 
        end

        it "should replace values with previous values for missing attribues" do
          args = { company: company, 
            data: [{"User ID"=>current_user.id, "Effective Date"=>"11/06/2021", "Department"=>"abc", "Job Title"=>"SSE", "Location"=>"Home Town", "Manager"=>"cbowman@rocketship.com" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Role Information',
            current_user: current_user, upload_date: DateTime.now }          
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Role Information").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Role Information").custom_fields.count + 4)  
          args[:data] = [{"User ID"=>current_user.id, "Effective Date"=>"11/06/2021", "Department"=>"abc", "Location"=>"Home Town", "Manager"=>"cbowman@rocketship.com" }]
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Role Information").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Role Information").custom_fields.count + 4) 
        end
      end

      context 'Uploading data in Custom Table(Compensation) through flatfile' do      
        it "should create single ctus" do
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.count
          expect(custom_table_user_snapshot).to eq(0)
          args = { company: company, 
            data: [{"User ID"=>current_user.id, "Effective Date"=>"11/06/2021", "Pay Rate"=> "88", "Pay Type"=>"Cash", "Pay Schedule"=>"today", "Change Reason"=>"secret", "Notes"=>"public" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Compensation',
            current_user: current_user, upload_date: DateTime.now }          
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.count
          expect(custom_table_user_snapshot).to eq(1)
        end

        it "should verify that the custom_snapshots are not greater than the Custom Table(Compensation) fields" do
          args = { company: company, 
            data: [{"User ID"=>current_user.id, "Effective Date"=>"11/06/2021", "Pay Rate"=>"8.8", "Pay Type"=>"Cash", "Pay Schedule"=>"today", "Change Reason"=>"secret", "Notes"=>"public" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Compensation',
            current_user: current_user, upload_date: DateTime.now }           
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Compensation").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Compensation").custom_fields.count)
          custom_table_user_snapshot.custom_snapshots.create!(custom_field_id: custom_table_user_snapshot.custom_snapshots.first.custom_field_id, custom_field_value: "20/06/2020", preference_field_id: nil, custom_table_user_snapshot_id: 1)
          args[:data] = [{"User ID"=>current_user.id, "Effective Date"=>"11/06/2021", "Pay Rate"=>"1.1", "Pay Type"=>"Cash", "Pay Schedule"=>"today", "Change Reason"=>"secret", "Notes"=>"public" }]
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Compensation").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Compensation").custom_fields.count)
        end
        
         it "should verify that the custom snapshots are not less than the Custom Table(Compensation) fields" do
          args = { company: company, 
            data: [{"User ID"=>current_user.id, "Effective Date"=>"11/06/2021", "Pay Rate"=>"8.8", "Pay Type"=>"Cash", "Pay Schedule"=>"today", "Change Reason"=>"secret", "Notes"=>"public" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Compensation',
            current_user: current_user, upload_date: DateTime.now }           
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Compensation").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Compensation").custom_fields.count)
          custom_table_user_snapshot.custom_snapshots.last.delete
          args[:data] = [{"User ID"=>current_user.id, "Effective Date"=>"11/06/2021", "Pay Rate"=>"1.1", "Pay Type"=>"Cash", "Pay Schedule"=>"today", "Change Reason"=>"secret", "Notes"=>"public" }]
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Compensation").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Compensation").custom_fields.count)
        end

        it "should replace values with previous values for missing attribues" do
          args = { company: company, 
            data: [{"User ID"=>current_user.id, "Effective Date"=>"11/06/2021", "Pay Rate"=>"8.8", "Pay Type"=>"Cash", "Pay Schedule"=>"today", "Change Reason"=>"secret", "Notes"=>"public" }], 
            import_method: 'update_user', is_tabular: true, table_name: 'Compensation',
            current_user: current_user, upload_date: DateTime.now }           
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Compensation").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Compensation").custom_fields.count)
          args[:data] = [{"User ID"=>current_user.id, "Effective Date"=>"11/06/2021", "Pay Rate"=>"1.1", "Pay Type"=>"Cash", "Pay Schedule"=>"today", "Notes"=>"public" }]
          ::ImportUsersData::UploadProfileData.new(args).perform
          custom_table_user_snapshot = current_user.custom_table_user_snapshots.find_by(custom_table_id: company.custom_tables.find_by(name: "Compensation").id)
          expect(custom_table_user_snapshot.custom_snapshots.count).to eq(company.custom_tables.find_by(name: "Compensation").custom_fields.count)
        end
      end

      context 'user_updation_from_flatfile' do
        let!(:nick) { create(:user, email: 'nick@test.com', first_name: 'nick', last_name: 'employee', state: :active, current_stage: :registered, role: :employee, company: company) }
        
        it "should_update_the_user" do
          args = { company: company, 
            data: [{"First Name"=>"flatfile", "Last Name"=>"test", "User ID"=>nick.id}], 
            import_method: 'update_user', is_tabular: false, table_name: nil,
            current_user: current_user, upload_date: DateTime.now }  
          ::ImportUsersData::UploadProfileData.new(args).perform
          expect(nick.reload.first_name).to eq('flatfile')
          expect(nick.reload.last_name).to eq('test')
        end

        it "should_not_update_the_user" do
          args = { company: company, 
            data: [{"First Name"=>"", "Last Name"=>"", "User ID"=>nick.id}], 
            import_method: 'update_user', is_tabular: false, table_name: nil,
            current_user: current_user, upload_date: DateTime.now }         
          ::ImportUsersData::UploadProfileData.new(args).perform
          expect(nick.reload.first_name).to eq('nick')
          expect(nick.reload.last_name).to eq('employee')
        end
      end
    end
  end
end

require 'rails_helper'

RSpec.describe ImportUsersData::UploadPermissionData do
  let!(:company) {create(:company)}
  let!(:sarah) { create(:sarah, company: company) }  
  let!(:user) { create(:user, company: company) }  
 
  describe "flatfile pemission update" do
    context "Update permission using Company Email" do
      context 'Updating user permission through flatfile' do
        it "should update user perrmission" do
          updated_role_id = company.user_roles.find_by(role_type: UserRole.role_types[:employee]).id
          data = [{'Company Email' => user.email, 'Permission' => updated_role_id}]
          args = { company: company, data: data, current_user: sarah, upload_date: Date.today.to_s }
          ::ImportUsersData::UploadPermissionData.new(args).perform
          expect(user.reload.user_role_id).to eq(updated_role_id)
        end

        it "should not update user perrmission if email is inavlid" do
          updated_role_id = company.user_roles.find_by(role_type: UserRole.role_types[:employee]).id
          data = [{'Company Email' => 'user@emial.com', 'Permission' => updated_role_id}]
          args = { company: company, data: data, current_user: sarah, upload_date: Date.today.to_s }
          ::ImportUsersData::UploadPermissionData.new(args).perform
          expect(user.reload.user_role_id).to_not eq(updated_role_id)
        end
      end
    end
    
    context "Update permission using User Id" do
      context 'Updating user permission through flatfile' do
        it "should update user perrmission" do
          updated_role_id = company.user_roles.find_by(role_type: UserRole.role_types[:employee]).id
          data = [{'User ID' => user.id, 'Permission' => updated_role_id}]
          args = { company: company, data: data, current_user: sarah, upload_date: Date.today.to_s }
          ::ImportUsersData::UploadPermissionData.new(args).perform
          expect(user.reload.user_role_id).to eq(updated_role_id)
        end

        it "should not update user perrmission if email is inavlid" do
          updated_role_id = company.user_roles.find_by(role_type: UserRole.role_types[:employee]).id
          data = [{'User ID' => 'd834x7', 'Permission' => updated_role_id}]
          args = { company: company, data: data, current_user: sarah, upload_date: Date.today.to_s }
          ::ImportUsersData::UploadPermissionData.new(args).perform
          expect(user.reload.user_role_id).to_not eq(updated_role_id)
        end
      end
    end
  end
end

require 'rails_helper'

RSpec.describe CustomTables::ManageCustomTableUserSnapshots, type: :job do 
  let(:custom_table) {create(:custom_table)}
  before { allow_any_instance_of(CustomTables::SnapshotManagement).to receive(:assign_ctus_values_to_users).and_return(true)}

  it 'should run service and return true if custom_table is present and type is timeline' do
    res = CustomTables::ManageCustomTableUserSnapshots.perform_now(custom_table.id)
    expect(res).to eq(true)
  end

  it 'should not run service and return true if custom_table is not present' do
    res = CustomTables::ManageCustomTableUserSnapshots.perform_now(34345)
    expect(res).to eq(nil)
  end

  it 'should not run service and return true if company is not present' do
    custom_table.company.update_column(:deleted_at, Time.now)
    res = CustomTables::ManageCustomTableUserSnapshots.perform_now(34345)
    expect(res).to eq(nil)
  end

  it 'should not run service and return true if custom_table type is not timeline' do
    custom_table.update(table_type: CustomTable.table_types[:standard])
    res = CustomTables::ManageCustomTableUserSnapshots.perform_now(34345)
    expect(res).to eq(nil)
  end
end
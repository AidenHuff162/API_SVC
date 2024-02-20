require 'rails_helper'

RSpec.describe DeleteCompany, type: :job do
  let!(:company) { create(:company)}

  it 'should delete company' do
    DeleteCompany.new.perform(company.id)
    expect(Company.find_by(id: company.id)).to eq(nil)
  end

end
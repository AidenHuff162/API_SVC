class AddNewStateToCountry < ActiveRecord::Migration[6.0]
  def change
    country = Country.find_by(name: "Chile")
    if country.present?
      state = State.find_by(name: "Los Rios", country_id: country.id)
      State.create(name: "Los Rios", key: "LR", country_id: country.id) unless state.present?
    end
  end
end

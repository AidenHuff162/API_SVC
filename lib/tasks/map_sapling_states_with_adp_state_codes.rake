namespace :map_sapling_states_with_adp_state_codes do

  desc 'Map Sapling States with ADP state codes by name'
  task map_on_the_basis_of_same_name: :environment do
    puts 'Sapling States Sync Started'
    list = HrisIntegrationsService::AdpWorkforceNowU::StaticAdpStateCodesList.new
    @state_names_in_adp = list.static_state_codes[:codes].map {|code| code[:code]}.compact

    State.find_each() do |state|
      state.update_column(:state_codes, {adp_state_code: state.name}) if @state_names_in_adp.include?(state.name)
    end
    puts 'Sapling States are Synced with ADP States'
  end

  desc 'Map Sapling States with ADP state codes by data fixes'
  task map_on_the_basis_data_fix_hash: :environment do
    invalid_state_names = []
    puts 'Mapping Through Data Fix Has Started'
    
    DataFixHash.each do |state|
      sapling_state = State.find_by(name: state[:sapling_state_name])
      next if sapling_state.nil?
      sapling_state.update_column(:state_codes, {adp_state_code: state[:adp_state_code]}) unless sapling_state.state_codes&.has_key?(:adp_state_code)
    end

    puts 'Sapling States are Synced with ADP States'
  end

  desc 'Map All states codes for Austria'
  task map_states_for_austria_to_adp: :environment do
    puts 'Mapping for Austria has started.'
      map_sapling_states_to_adp(AustriaStateFixList)
    puts 'Mapping for Austria completed.'
  end

  desc 'Map All state codes for Costa Rica'
  task map_states_for_costa_rica_to_adp: :environment do
    puts 'Mapping for Costa Rica has started.'
      map_sapling_states_to_adp(CostaRicaStateFixList)
    puts 'Mapping for Costa Rica completed.'
  end

  desc 'Map All state codes for India'
  task map_states_for_india_to_adp: :environment do
    puts 'Mapping for India has started.'
      map_sapling_states_to_adp(IndiaStateFixList)
    puts 'Mapping for India completed.'
  end

  desc 'Map All state codes for Turkey'
  task map_states_for_turkey_to_adp: :environment do
    puts 'Mapping for Turkey has started.'
      map_sapling_states_to_adp(TurkeyStateFixList)
    puts 'Mapping for Turkey completed.'
  end  

  desc 'Map All state codes for Poland'
  task map_states_for_Poland_to_adp: :environment do
    puts 'Mapping for Poland has started.'
      map_sapling_states_to_adp(PolandStateFixList)
    puts 'Mapping for Poland completed.'
  end

  desc 'Map All state codes for Mexico'
  task map_states_for_Mexico_to_adp: :environment do
    puts 'Mapping for Mexico has started.'
      map_sapling_states_to_adp(MexicoStateFixList)
    puts 'Mapping for Mexico completed.'
  end

  desc 'Map All state codes for Spain'
  task map_states_for_Spain_to_adp: :environment do
    puts 'Mapping for Spain has started.'
      map_sapling_states_to_adp(SpainStateFixList)
    puts 'Mapping for Spain completed.'
  end

  def map_sapling_states_to_adp(data_fix_list)
    data_fix_list.each do |state|
      sapling_state = State.find_by(name: state[:sapling_state_name])
      next if sapling_state.nil?
      sapling_state.update_column(:state_codes, {adp_state_code: state[:adp_state_code]}) unless sapling_state.state_codes&.has_key?(:adp_state_code)
    end    
  end

  task all: [:map_on_the_basis_of_same_name, :map_on_the_basis_data_fix_hash]
   
  DataFixHash = 
  [{sapling_state_name: 'Hlavni mesto Praha', adp_state_code: 'Praha, hlavní město'},
     {sapling_state_name: 'Jihocesky kraj', adp_state_code: 'Jihočeský kraj'},
     {sapling_state_name: 'Pardubicky kraj', adp_state_code: 'Pardubický kraj'},
     {sapling_state_name: 'Kraj Vysocina', adp_state_code: 'Vysočina'},
     {sapling_state_name: 'Ustecky kraj', adp_state_code: 'Ústecký kraj'},
     {sapling_state_name: 'Central Bohemia', adp_state_code: 'Středočeský kraj'},
     {sapling_state_name: 'Plzensky kraj', adp_state_code: 'Plzeňský kraj'},
     {sapling_state_name: 'Olomoucky kraj', adp_state_code: 'Olomoucký kraj'},
     {sapling_state_name: 'Moravskoslezsky kraj', adp_state_code: 'Moravskoslezský kraj'},
     {sapling_state_name: 'Liberecky kraj', adp_state_code: 'Liberecký kraj'},
     {sapling_state_name: 'Kralovehradecky kraj', adp_state_code: 'Královéhradecký kraj'},
     {sapling_state_name: 'Karlovarsky kraj', adp_state_code: 'Karlovarský kraj'},
     {sapling_state_name: 'South Moravian', adp_state_code: 'Jihomoravský kraj'},
     {sapling_state_name: 'Bavaria', adp_state_code: 'Bayern'},
     {sapling_state_name: 'Dubai', adp_state_code: 'Dubayy - Dubai'},
     {sapling_state_name: 'Abu Dhabi', adp_state_code: 'Abū Z̧aby - Abu Dhabi'},
     {sapling_state_name: 'Antwerpen (nl)', adp_state_code: 'Antwerpen'},
     {sapling_state_name: 'Brabant Wallon (fr)', adp_state_code: 'Brabant Wallon'},
     {sapling_state_name: 'Brussels', adp_state_code: 'Brussels Hoofdstedelijk Gewest'},
     {sapling_state_name: '"A Coruña', adp_state_code: 'La Coruña'},
     {sapling_state_name: 'Ash Shariqah', adp_state_code: 'Ash Shāriqah - Sharjah'},
     {sapling_state_name: "Ra's al Khaymah", adp_state_code: 'Ra’s al Khaymah'},
     {sapling_state_name: 'Aichi', adp_state_code: 'Aiti '},
     {sapling_state_name: 'Yamanashi', adp_state_code: 'Yamanasi'},
     {sapling_state_name: 'Yamaguchi', adp_state_code: 'Yamaguti'},
     {sapling_state_name: 'Tokushima', adp_state_code: 'Tokusima'},
     {sapling_state_name: 'Shizuoka', adp_state_code: 'Sizuoka'},
     {sapling_state_name: 'Tokyo', adp_state_code: 'Tôkyô'},
     {sapling_state_name: 'Tochigi', adp_state_code: 'Totigi'},
     {sapling_state_name: 'Shimane', adp_state_code: 'Simane'},
     {sapling_state_name: 'Shiga', adp_state_code: 'Siga'},
     {sapling_state_name: 'Osaka', adp_state_code: 'Ôsaka'},
     {sapling_state_name: 'Oita', adp_state_code: 'Ôita'},
     {sapling_state_name: 'Kyoto', adp_state_code: 'Kyôto'},
     {sapling_state_name: 'Kochi', adp_state_code: 'Kôti'},
     {sapling_state_name: 'Kagoshima', adp_state_code: 'Kagosima'},
     {sapling_state_name: 'Ishikawa', adp_state_code: 'Isikawa'},
     {sapling_state_name: 'Hyogo', adp_state_code: 'Hyôgo'},
     {sapling_state_name: 'Hokkaido', adp_state_code: 'Hokkaidô'},
     {sapling_state_name: 'Hiroshima', adp_state_code: 'Hirosima'},
     {sapling_state_name: 'Gifu', adp_state_code: 'Gihu '},
     {sapling_state_name: 'Fukushima', adp_state_code: 'Hukusima'},
     {sapling_state_name: 'Fukuoka', adp_state_code: 'Hukuoka'},
     {sapling_state_name: 'Fukui', adp_state_code: 'Hukui'},
     {sapling_state_name: 'Chiba', adp_state_code: 'Tiba'},
     {sapling_state_name: 'Bedfordshire', adp_state_code: 'Central Bedfordshire'},
     {sapling_state_name: 'Berkshire', adp_state_code: 'West Berkshire'},
     {sapling_state_name: 'Bridgend [Pen-y-bont ar Ogwr GB-POG]', adp_state_code: 'Bridgend'},
     {sapling_state_name: 'Caerphilly [Caerffili GB-CAF]', adp_state_code: 'Caerphilly'},
     {sapling_state_name: 'Cardiff [Caerdydd GB-CRD]', adp_state_code: 'Cardiff'},
     {sapling_state_name: 'Carmarthenshire [Sir Gaerfyrddin GB-GFY]', adp_state_code: 'Carmarthenshire'},
     {sapling_state_name: 'Ceredigion [Sir Ceredigion]', adp_state_code: 'Ceredigion'},
     {sapling_state_name: 'Cheshire', adp_state_code: 'Cheshire West and Chester'},
     {sapling_state_name: 'Denbighshire [Sir Ddinbych GB-DDB]', adp_state_code: 'Denbighshire'},
     {sapling_state_name: 'Dungannon', adp_state_code: 'Dungannon and South Tyrone'},
     {sapling_state_name: 'Durham', adp_state_code: 'Durham, County'},
     {sapling_state_name: 'Flintshire [Sir y Fflint GB-FFL]', adp_state_code: 'Flintshire'},
     {sapling_state_name: 'Greater Manchester', adp_state_code: 'Manchester'},
     {sapling_state_name: 'Herefordshire, County of', adp_state_code: 'Herefordshire'},
     {sapling_state_name: 'Isle of Anglesey [Sir Ynys Môn GB-YNM]', adp_state_code: 'Isle of Anglesey'},
     {sapling_state_name: 'Isles of Scilly', adp_state_code: 'Cornwall'},
     {sapling_state_name: 'Kingston upon Hull, City of', adp_state_code: 'Kingston upon Hull'},
     {sapling_state_name: 'London', adp_state_code: 'London, City of'},
     {sapling_state_name: 'Merthyr Tydfil [Merthyr Tudful GB-MTU]', adp_state_code: 'Merthyr Tydfil'},
     {sapling_state_name: 'Middlesex', adp_state_code: 'London, City of'},
     {sapling_state_name: 'Monmouthshire [Sir Fynwy GB-FYN]', adp_state_code: 'Monmouthshire'},
     {sapling_state_name: 'Newport [Casnewydd GB-CNW]', adp_state_code: 'Newport'},
     {sapling_state_name: 'Newry and Mourne', adp_state_code: 'Newry and Mourne District'},
     {sapling_state_name: 'Rhondda, Cynon, Taff [Rhondda, Cynon,Taf]', adp_state_code: 'Rhondda Cynon Taff'},
     {sapling_state_name: 'Swansea [Abertawe GB-ATA]', adp_state_code: 'Swansea'},
     {sapling_state_name: 'Torfaen [Tor-faen]', adp_state_code: 'Torfaen'},
     {sapling_state_name: 'Vale of Glamorgan, The [Bro Morgannwg GB-BMG]', adp_state_code: 'Vale of Glamorgan'},
     {sapling_state_name: 'Wrexham [Wrecsam GB-WRC]', adp_state_code: 'Wrexham'},
     {sapling_state_name: 'Pembrokeshire [Sir Benfro GB-BNF]', adp_state_code: 'Pembrokeshire'},
     {sapling_state_name: 'Neath Port Talbot [Castell-nedd Port Talbot GB-CTL]', adp_state_code: 'Neath Port Talbot'},
     {sapling_state_name: 'Capital federal', adp_state_code: 'Buenos Aires City'},
     {sapling_state_name: 'Entre Ríos', adp_state_code: ' Entre Ríos'},
     {sapling_state_name: 'Province of the Western Cape', adp_state_code: 'Western Cape'},
     {sapling_state_name: 'Province of North West', adp_state_code: 'North West'},
     {sapling_state_name: 'Orange Free State', adp_state_code: 'Free State'}
  ]

  AustriaStateFixList = [
    {sapling_state_name: 'Vienna', adp_state_code: 'Wien'},
    {sapling_state_name: 'Carinthia', adp_state_code: 'Kärnten'},
    {sapling_state_name: 'Lower Austria', adp_state_code: 'Niederösterreich'},
    {sapling_state_name: 'Upper Austria', adp_state_code: 'Oberösterreich'},
    {sapling_state_name: 'Styria', adp_state_code: 'Steiermark'},
    {sapling_state_name: 'Burgenland', adp_state_code: 'Burgenland'},
    {sapling_state_name: 'Salzburg', adp_state_code: 'Salzburg'},
    {sapling_state_name: 'Vorarlberg', adp_state_code: 'Vorarlberg'},
    {sapling_state_name: 'Tyrol', adp_state_code: 'Tirol'}
  ]

  CostaRicaStateFixList = [
    {sapling_state_name: 'Provincia de Alajuela', adp_state_code: 'Alajuela'},
    {sapling_state_name: 'Provincia de Cartago', adp_state_code: 'Cartago'},
    {sapling_state_name: 'Provincia de Heredia', adp_state_code: 'Heredia'},
    {sapling_state_name: 'Provincia de Limon', adp_state_code: 'Limón'},
    {sapling_state_name: 'Provincia de Puntarenas', adp_state_code: 'Puntarenas'},
    {sapling_state_name: 'Provincia de San Jose', adp_state_code: 'San José'},
    {sapling_state_name: 'Provincia de Guanacaste', adp_state_code: 'Guanacaste'}
  ]

  IndiaStateFixList = [
    {sapling_state_name: 'Pondicherry', adp_state_code: 'PY Puducherry or Pondicherry'},
    {sapling_state_name: 'Uttaranchal', adp_state_code: 'Uttarakhand'},
    {sapling_state_name: 'Orissa', adp_state_code: 'Odisha'},
    {sapling_state_name: 'Chandigarh', adp_state_code: 'Guanacaste'}
  ]

  TurkeyStateFixList = [
    {sapling_state_name: 'Adiyaman', adp_state_code: 'Adıyaman'},
    {sapling_state_name: 'Diyarbakir', adp_state_code: 'Diyarbakır'},
    {sapling_state_name: 'Guemueshane', adp_state_code: 'Gümüşhane'},
    {sapling_state_name: 'Istanbul', adp_state_code: 'İstanbul'},
    {sapling_state_name: 'Izmir', adp_state_code: 'İzmir'},
    {sapling_state_name: 'Duezce', adp_state_code: 'Düzce'},
    {sapling_state_name: 'Nevsehir', adp_state_code: 'Nevşehir'},
    {sapling_state_name: 'Nigde', adp_state_code: 'Niğde'},
    {sapling_state_name: 'Karabuek', adp_state_code: 'Karabük'}
  ]

  PolandStateFixList = [
    {sapling_state_name: 'Masovian Voivodeship', adp_state_code: 'Mazowieckie'},
    {sapling_state_name: 'Podlasie', adp_state_code: 'Podlaskie'},
    {sapling_state_name: 'Pomeranian Voivodeship', adp_state_code: 'Pomorskie'},
    {sapling_state_name: 'Subcarpathian Voivodeship', adp_state_code: 'Podkarpackie'},
    {sapling_state_name: 'Silesian Voivodeship', adp_state_code: 'Śląskie'},
    {sapling_state_name: 'Warmian-Masurian Voivodeship', adp_state_code: 'Warmińsko-mazurskie'},
    {sapling_state_name: 'Greater Poland Voivodeship', adp_state_code: 'Wielkopolskie'},
    {sapling_state_name: 'Kujawsko-Pomorskie', adp_state_code: 'Kujawsko-pomorskie'},
    {sapling_state_name: 'Lubusz', adp_state_code: 'Lubuskie'},
    {sapling_state_name: 'Łódź Voivodeship', adp_state_code: 'Łódzkie'},
    {sapling_state_name: 'Lesser Poland Voivodeship', adp_state_code: 'Małopolskie'},
    {sapling_state_name: 'Lublin Voivodeship', adp_state_code: 'Lubelskie'},
    {sapling_state_name: 'Lower Silesian Voivodeship', adp_state_code: 'Dolnośląskie'},
    {sapling_state_name: 'Opole Voivodeship', adp_state_code: 'Opolskie'},
    {sapling_state_name: 'West Pomeranian Voivodeship', adp_state_code: 'Zachodniopomorskie'}
  ]

  MexicoStateFixList = [
    {sapling_state_name: 'Estado de Baja California', adp_state_code: 'Baja California'},
    {sapling_state_name: 'Coahuila', adp_state_code: 'Coahuila de Zaragoza'},
    {sapling_state_name: 'Mexico City', adp_state_code: 'Ciudad de México'},
    {sapling_state_name: 'Estado de Mexico', adp_state_code: 'México'},
    {sapling_state_name: 'Michoacán', adp_state_code: 'Michoacán de Ocampo'},
    {sapling_state_name: 'Querétaro', adp_state_code: 'Querétaro de Arteaga'},
    {sapling_state_name: 'Veracruz', adp_state_code: 'Veracruz de Ignacio de la Llave'},
    {sapling_state_name: 'Distrito Federal', adp_state_code: 'Ciudad de México'}
  ]

  SpainStateFixList = [
    {sapling_state_name: 'A Coruña', adp_state_code: 'La Coruña'},
    {sapling_state_name: 'Baleares', adp_state_code: 'Balearic Islands'},
    {sapling_state_name: 'Vizcaya', adp_state_code: 'Biscay'},
  ]
end
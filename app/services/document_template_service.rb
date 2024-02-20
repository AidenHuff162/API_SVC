class DocumentTemplateService
  def initialize(template)
    @template = template
  end

  def call
    document_template
  end

  private

  attr_reader :template

  def document_template
    data = Dropbox::Sign::TemplateCreateEmbeddedDraftRequest.new
    data.client_id = Sapling::Application::HELLOSIGN_CLIENT_ID
    data.title = template.document.title
    data.message = template.document.description
    data.signer_roles = template.get_signer_roles
    data.test_mode = template.company.get_hellosign_test_mode

    if !Rails.env.development? && !Rails.env.test?
      data.file_urls = [template.document&.attached_file&.url_for_hellosign]
    else
      data.files = [File.new(template.document&.attached_file&.url_for_hellosign, 'r')]
    end

    data.merge_fields = fields(template)
    data.form_fields_per_document = get_form_fields_per_document(template)

    template_api = Dropbox::Sign::TemplateApi.new
    template_api.api_client.config.username = ENV['HELLOSIGN_API_KEY']
    result = template_api.template_create_embedded_draft(data)

    template.hellosign_template_edit_url = result.template.edit_url
    template.new_template_id = result.template.template_id
    template
  end

  def get_form_fields_per_document(template)
    template_api = Dropbox::Sign::TemplateApi.new
    template_api.api_client.config.username = ENV['HELLOSIGN_API_KEY_US']
    result = template_api.template_get(template.hellosign_template_id)
    data = []

    result.template.documents[0].form_fields.each do |field|
      data << { "document_index": 0,
                "api_id": field.api_id,
                "name": field.name,
                "type": field.type,
                "x": field.x,
                "y": field.y,
                "width": field.width,
                "height": field.height,
                "required": field.required,
                "signer": (field.signer.to_i - 1) }
    end

    result.template.documents[0].custom_fields.each do |field|
      name = field.name&.length > 40 ? field.name.slice(0, 40) : field.name

      data << { "document_index": 0,
                "api_id": field.api_id,
                "name": name,
                "type": 'text',
                "x": field.x,
                "y": field.y,
                "width": field.width,
                "height": field.height,
                "required": field.required,
                "placeholder": "Sender - #{field.name}",
                "signer": 0 }
    end

    data
  end

  def fields(template)
    fields = template.fields_data
    template.company.custom_fields.where.not(name: 'Effective Date').pluck(:name).each do |field_name|
      fields += "{\"name\":\"#{field_name}\" , \"type\":\"text\"},"
    end
    fields = "[#{fields.chomp(',')}]"
    JSON.parse(fields).uniq.to_json
  end
end

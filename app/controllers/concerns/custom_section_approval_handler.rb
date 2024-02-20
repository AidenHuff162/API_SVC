module CustomSectionApprovalHandler
  extend ActiveSupport::Concern

  def prepare_fields_for_cs_approval(params, user_id, is_default_field = true, controller)
    return nil unless params[:custom_section_approval].present?
    fields = create_fields_for_cs_approval(params, user_id, is_default_field)
    return unless fields.present?

    case controller
    when 'custom_field', 'user_role', 'user_profile'
      return fields[:changed_fields]
    when 'users'
      return [fields[:custom_section_id], fields[:changed_fields]]
    end
  end

  private

  def create_fields_for_cs_approval(params, user_id, is_default_field)
    custom_section = params[:custom_section_id].present? ? current_company.custom_sections.find_by(id: params[:custom_section_id]) : nil
    return nil unless custom_section.present?

    custom_section_approval_management = CustomSections::CustomSectionApprovalManagement.new(current_company, user_id)
    changed_section_custom_fields = nil

    if is_default_field
      changed_section_custom_fields = custom_section_approval_management.default_fields_changed(params, custom_section.id)
    else
      changed_section_custom_fields = custom_section_approval_management.prepare_changed_custom_fields(params, custom_section.id)
    end
    
    return nil unless changed_section_custom_fields.present? && custom_section.is_approval_required.present?

    return { changed_fields: changed_section_custom_fields, custom_section_id: custom_section.id }
  end
end

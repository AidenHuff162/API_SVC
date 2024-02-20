class CustomSectionApprovalsCollection < BaseCollection
  private

  def relation
    @relation ||= CustomSectionApproval.all
  end

  def ensure_filters
    updates_page_filter
  end

  def updates_page_filter
    if params[:updates_page].present?
      if params[:isSuperAdmin].present?
        filter { |relation| relation.joins("LEFT JOIN custom_sections on custom_sections.id = custom_section_approvals.custom_section_id").where("
          custom_sections.company_id = ? AND (custom_sections.is_approval_required = TRUE AND custom_section_approvals.state = ?)",
          params[:company_id], CustomSectionApproval.states[:requested]
          )}
      else
        query = "(approval_chains.approval_type = ? AND cs_approval_chains.state = ?
          AND (
            (? IN
              (SELECT users.manager_id FROM users WHERE(users.id = custom_section_approvals.user_id))
              AND '1' = ANY(approval_chains.approval_ids)
              AND approval_chains.id IN
              (SELECT cs_approval_chains.approval_chain_id FROM cs_approval_chains
               WHERE(cs_approval_chains.state = 1 AND cs_approval_chains.custom_section_approval_id = custom_section_approvals.id)
               ORDER BY cs_approval_chains.id ASC limit(1)
              )
            )
            OR
            (? IN
              (SELECT users.manager_id FROM users WHERE id IN ( SELECT users.manager_id FROM users WHERE(users.id = custom_section_approvals.user_id)))
              AND '2' = ANY(approval_chains.approval_ids)
              AND approval_chains.id IN
              (SELECT cs_approval_chains.approval_chain_id FROM cs_approval_chains
               WHERE(cs_approval_chains.state = 1 AND cs_approval_chains.custom_section_approval_id = custom_section_approvals.id)
               ORDER BY cs_approval_chains.id ASC limit(1)
              )
            )
            OR
            (? IN
              (SELECT users.manager_id FROM users WHERE id IN ( SELECT users.manager_id FROM users WHERE id IN (SELECT users.manager_id FROM users WHERE(users.id = custom_section_approvals.user_id))))
              AND '3' = ANY(approval_chains.approval_ids)
              AND approval_chains.id IN
              (SELECT cs_approval_chains.approval_chain_id FROM cs_approval_chains
               WHERE(cs_approval_chains.state = 1 AND cs_approval_chains.custom_section_approval_id = custom_section_approvals.id)
               ORDER BY cs_approval_chains.id ASC limit(1)
              )
            )
            OR
            (? IN
              (SELECT users.manager_id FROM users WHERE id IN ( SELECT users.manager_id FROM users WHERE id IN (SELECT users.manager_id FROM users WHERE id IN (SELECT users.manager_id FROM users WHERE(users.id = custom_section_approvals.user_id)))))
              AND '4' = ANY(approval_chains.approval_ids)
              AND approval_chains.id IN
              (SELECT cs_approval_chains.approval_chain_id FROM cs_approval_chains
               WHERE(cs_approval_chains.state = 1 AND cs_approval_chains.custom_section_approval_id = custom_section_approvals.id)
               ORDER BY cs_approval_chains.id ASC limit(1)
              )
            )
          )
        )
        OR (approval_chains.approval_type = ?
          AND cs_approval_chains.state = ?
          AND (
            (? IN
              (SELECT users.manager_id FROM users WHERE(users.id = custom_section_approvals.requester_id))
              AND '1' = ANY(approval_chains.approval_ids)
              AND approval_chains.id IN
              (SELECT cs_approval_chains.approval_chain_id FROM cs_approval_chains
               WHERE(cs_approval_chains.state = 1 AND cs_approval_chains.custom_section_approval_id = custom_section_approvals.id)
               ORDER BY cs_approval_chains.id ASC limit(1)
              )
            )
            OR
            (? IN
              (SELECT users.manager_id FROM users WHERE id IN ( SELECT users.manager_id FROM users WHERE(users.id = custom_section_approvals.requester_id)))
              AND '2' = ANY(approval_chains.approval_ids)
              AND approval_chains.id IN
              (SELECT cs_approval_chains.approval_chain_id FROM cs_approval_chains
               WHERE(cs_approval_chains.state = 1 AND cs_approval_chains.custom_section_approval_id = custom_section_approvals.id)
               ORDER BY cs_approval_chains.id ASC limit(1)
              )
            )
            OR
            (? IN
              (SELECT users.manager_id FROM users WHERE id IN ( SELECT users.manager_id FROM users WHERE id IN (SELECT users.manager_id FROM users WHERE(users.id = custom_section_approvals.requester_id))))
              AND '3' = ANY(approval_chains.approval_ids)
              AND approval_chains.id IN
              (SELECT cs_approval_chains.approval_chain_id FROM cs_approval_chains
               WHERE(cs_approval_chains.state = 1 AND cs_approval_chains.custom_section_approval_id = custom_section_approvals.id)
               ORDER BY cs_approval_chains.id ASC limit(1)
              )
            )
            OR
            (? IN
              (SELECT users.manager_id FROM users WHERE id IN ( SELECT users.manager_id FROM users WHERE id IN (SELECT users.manager_id FROM users WHERE id IN (SELECT users.manager_id FROM users WHERE(users.id = custom_section_approvals.requester_id)))))
              AND '4' = ANY(approval_chains.approval_ids)
              AND approval_chains.id IN
              (SELECT cs_approval_chains.approval_chain_id FROM cs_approval_chains
               WHERE(cs_approval_chains.state = 1 AND cs_approval_chains.custom_section_approval_id = custom_section_approvals.id)
               ORDER BY cs_approval_chains.id ASC limit(1)
              )
            )
          )
        )
        OR (approval_chains.approval_type = ? AND cs_approval_chains.state = ? AND ? IN
          (SELECT approval_chains.approval_ids from approval_chains where approval_chains.id IN
            (SELECT cs_approval_chains.approval_chain_id FROM cs_approval_chains
             WHERE(cs_approval_chains.state = ? AND cs_approval_chains.custom_section_approval_id = custom_section_approvals.id)
             ORDER BY cs_approval_chains.id ASC limit(1)
            )
          )
        )
        OR (approval_chains.approval_type = ? AND cs_approval_chains.state = ? AND (SELECT count(approval_chains) from approval_chains where (cast(? as varchar)= ANY (approval_chains.approval_ids)) AND (approval_chains.id IN
          (Select cs_approval_chains.approval_chain_id from cs_approval_chains where(cs_approval_chains.state = ? AND cs_approval_chains.custom_section_approval_id =
          custom_section_approvals.id) order by cs_approval_chains.id asc limit(1)))) > 0
        )     
        OR 
        (approval_chains.approval_type = ? AND cs_approval_chains.state = ? AND '{bdy}' IN
            (SELECT approval_chains.approval_ids from approval_chains where approval_chains.id IN
              (SELECT cs_approval_chains.approval_chain_id FROM cs_approval_chains
               WHERE(cs_approval_chains.state = ? AND cs_approval_chains.custom_section_approval_id = custom_section_approvals.id)
               ORDER BY cs_approval_chains.id ASC limit(1)
              )
            ) AND ? IN (SELECT users.buddy_id FROM users WHERE(users.id = custom_section_approvals.user_id))             
        )
        OR 
        (approval_chains.approval_type = ? AND cs_approval_chains.state = ? AND custom_section_approvals.user_id = ?)"
        CustomField.where(company_id: params[:company_id], field_type: CustomField.field_types[:coworker]).try(:each) do |field|
          query += "OR 
          (approval_chains.approval_type = '#{ApprovalChain.approval_types[:coworker]}' AND cs_approval_chains.state = '#{CsApprovalChain.states[:requested]}' AND '{#{field.id}}' IN
              (SELECT approval_chains.approval_ids from approval_chains where approval_chains.id IN
                (SELECT cs_approval_chains.approval_chain_id FROM cs_approval_chains
                 WHERE(cs_approval_chains.state = '#{CsApprovalChain.states[:requested]}' AND cs_approval_chains.custom_section_approval_id = custom_section_approvals.id)
                 ORDER BY cs_approval_chains.id ASC limit(1)
                )
              ) AND '#{params[:current_user_id]}' IN (SELECT coworker_id FROM custom_field_values WHERE(custom_section_approvals.user_id = custom_field_values.user_id AND custom_field_values.custom_field_id = #{field.id}))
               
          )"
        end
        filter { |relation| relation.joins("LEFT JOIN cs_approval_chains on cs_approval_chains.custom_section_approval_id = custom_section_approvals.id").joins("LEFT 
          JOIN approval_chains on (approval_chains.approvable_id = custom_section_approvals.id OR approval_chains.approvable_id = custom_section_approvals.custom_section_id) 
          AND (approval_chains.approvable_type = 'CustomSectionApproval' OR approval_chains.approvable_type = 'CustomSection') AND cs_approval_chains.approval_chain_id = approval_chains.id").where(query, 
          ApprovalChain.approval_types[:manager], CsApprovalChain.states[:requested], params[:current_user_id], params[:current_user_id], params[:current_user_id], params[:current_user_id],
          ApprovalChain.approval_types[:requestor_manager], CsApprovalChain.states[:requested], params[:current_user_id], params[:current_user_id], params[:current_user_id], params[:current_user_id],
          ApprovalChain.approval_types[:person], CsApprovalChain.states[:requested], "{#{params[:current_user_id]}}", CsApprovalChain.states[:requested], 
          ApprovalChain.approval_types[:permission], CsApprovalChain.states[:requested], params[:current_user_role], CsApprovalChain.states[:requested], 
          ApprovalChain.approval_types[:coworker], CsApprovalChain.states[:requested], CsApprovalChain.states[:requested], params[:current_user_id],
          ApprovalChain.approval_types[:individual], CsApprovalChain.states[:requested], params[:current_user_id]).select("DISTINCT ON (custom_section_approvals.id) custom_section_approvals.*")
          }
      end
    end
  end
end

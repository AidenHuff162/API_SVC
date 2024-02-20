class CustomTableUserSnapshotsCollection < BaseCollection
  private

  def relation
    @relation ||= CustomTableUserSnapshot.all
  end

  def ensure_filters
    updates_page_filter
  end

  def updates_page_filter
    if params[:updates_page].present?
      if params[:isSuperAdmin].present?
        filter { |relation| relation.joins("LEFT JOIN custom_tables on custom_tables.id = custom_table_user_snapshots.custom_table_id").where("
          custom_tables.company_id = ? AND (custom_tables.is_approval_required = TRUE AND custom_table_user_snapshots.request_state = ?)",
          params[:company_id], CustomTableUserSnapshot.request_states[:requested]
          )}
      else
        query = "(approval_chains.approval_type = ? AND ctus_approval_chains.request_state = ?
          AND (
            (? IN
              (SELECT users.manager_id FROM users WHERE(users.id = custom_table_user_snapshots.user_id))
              AND '1' = ANY(approval_chains.approval_ids)
              AND approval_chains.id IN
              (SELECT ctus_approval_chains.approval_chain_id FROM ctus_approval_chains
               WHERE(ctus_approval_chains.request_state = 1 AND ctus_approval_chains.custom_table_user_snapshot_id = custom_table_user_snapshots.id)
               ORDER BY ctus_approval_chains.id ASC limit(1)
              )
            )
            OR
            (? IN
              (SELECT users.manager_id FROM users WHERE id IN ( SELECT users.manager_id FROM users WHERE(users.id = custom_table_user_snapshots.user_id)))
              AND '2' = ANY(approval_chains.approval_ids)
              AND approval_chains.id IN
              (SELECT ctus_approval_chains.approval_chain_id FROM ctus_approval_chains
               WHERE(ctus_approval_chains.request_state = 1 AND ctus_approval_chains.custom_table_user_snapshot_id = custom_table_user_snapshots.id)
               ORDER BY ctus_approval_chains.id ASC limit(1)
              )
            )
            OR
            (? IN
              (SELECT users.manager_id FROM users WHERE id IN ( SELECT users.manager_id FROM users WHERE id IN (SELECT users.manager_id FROM users WHERE(users.id = custom_table_user_snapshots.user_id))))
              AND '3' = ANY(approval_chains.approval_ids)
              AND approval_chains.id IN
              (SELECT ctus_approval_chains.approval_chain_id FROM ctus_approval_chains
               WHERE(ctus_approval_chains.request_state = 1 AND ctus_approval_chains.custom_table_user_snapshot_id = custom_table_user_snapshots.id)
               ORDER BY ctus_approval_chains.id ASC limit(1)
              )
            )
            OR
            (? IN
              (SELECT users.manager_id FROM users WHERE id IN ( SELECT users.manager_id FROM users WHERE id IN (SELECT users.manager_id FROM users WHERE id IN (SELECT users.manager_id FROM users WHERE(users.id = custom_table_user_snapshots.user_id)))))
              AND '4' = ANY(approval_chains.approval_ids)
              AND approval_chains.id IN
              (SELECT ctus_approval_chains.approval_chain_id FROM ctus_approval_chains
               WHERE(ctus_approval_chains.request_state = 1 AND ctus_approval_chains.custom_table_user_snapshot_id = custom_table_user_snapshots.id)
               ORDER BY ctus_approval_chains.id ASC limit(1)
              )
            )
          )
        )
        OR (approval_chains.approval_type = ?
          AND ctus_approval_chains.request_state = ?
          AND (
            (? IN
              (SELECT users.manager_id FROM users WHERE(users.id = custom_table_user_snapshots.requester_id))
              AND '1' = ANY(approval_chains.approval_ids)
              AND approval_chains.id IN
              (SELECT ctus_approval_chains.approval_chain_id FROM ctus_approval_chains
               WHERE(ctus_approval_chains.request_state = 1 AND ctus_approval_chains.custom_table_user_snapshot_id = custom_table_user_snapshots.id)
               ORDER BY ctus_approval_chains.id ASC limit(1)
              )
            )
            OR
            (? IN
              (SELECT users.manager_id FROM users WHERE id IN ( SELECT users.manager_id FROM users WHERE(users.id = custom_table_user_snapshots.requester_id)))
              AND '2' = ANY(approval_chains.approval_ids)
              AND approval_chains.id IN
              (SELECT ctus_approval_chains.approval_chain_id FROM ctus_approval_chains
               WHERE(ctus_approval_chains.request_state = 1 AND ctus_approval_chains.custom_table_user_snapshot_id = custom_table_user_snapshots.id)
               ORDER BY ctus_approval_chains.id ASC limit(1)
              )
            )
            OR
            (? IN
              (SELECT users.manager_id FROM users WHERE id IN ( SELECT users.manager_id FROM users WHERE id IN (SELECT users.manager_id FROM users WHERE(users.id = custom_table_user_snapshots.requester_id))))
              AND '3' = ANY(approval_chains.approval_ids)
              AND approval_chains.id IN
              (SELECT ctus_approval_chains.approval_chain_id FROM ctus_approval_chains
               WHERE(ctus_approval_chains.request_state = 1 AND ctus_approval_chains.custom_table_user_snapshot_id = custom_table_user_snapshots.id)
               ORDER BY ctus_approval_chains.id ASC limit(1)
              )
            )
            OR
            (? IN
              (SELECT users.manager_id FROM users WHERE id IN ( SELECT users.manager_id FROM users WHERE id IN (SELECT users.manager_id FROM users WHERE id IN (SELECT users.manager_id FROM users WHERE(users.id = custom_table_user_snapshots.requester_id)))))
              AND '4' = ANY(approval_chains.approval_ids)
              AND approval_chains.id IN
              (SELECT ctus_approval_chains.approval_chain_id FROM ctus_approval_chains
               WHERE(ctus_approval_chains.request_state = 1 AND ctus_approval_chains.custom_table_user_snapshot_id = custom_table_user_snapshots.id)
               ORDER BY ctus_approval_chains.id ASC limit(1)
              )
            )
          )
        )
        OR (approval_chains.approval_type = ? AND ctus_approval_chains.request_state = ? AND ? IN
          (SELECT approval_chains.approval_ids from approval_chains where approval_chains.id IN
            (SELECT ctus_approval_chains.approval_chain_id FROM ctus_approval_chains
             WHERE(ctus_approval_chains.request_state = ? AND ctus_approval_chains.custom_table_user_snapshot_id = custom_table_user_snapshots.id)
             ORDER BY ctus_approval_chains.id ASC limit(1)
            )
          )
        )
        OR (approval_chains.approval_type = ? AND ctus_approval_chains.request_state = ? AND (SELECT count(approval_chains) from approval_chains where (cast(? as varchar)= ANY (approval_chains.approval_ids)) AND (approval_chains.id IN
          (Select ctus_approval_chains.approval_chain_id from ctus_approval_chains where(ctus_approval_chains.request_state = ? AND ctus_approval_chains.custom_table_user_snapshot_id =
          custom_table_user_snapshots.id) order by ctus_approval_chains.id asc limit(1)))) > 0
        )     
        OR 
        (approval_chains.approval_type = ? AND ctus_approval_chains.request_state = ? AND '{bdy}' IN
            (SELECT approval_chains.approval_ids from approval_chains where approval_chains.id IN
              (SELECT ctus_approval_chains.approval_chain_id FROM ctus_approval_chains
               WHERE(ctus_approval_chains.request_state = ? AND ctus_approval_chains.custom_table_user_snapshot_id = custom_table_user_snapshots.id)
               ORDER BY ctus_approval_chains.id ASC limit(1)
              )
            ) AND ? IN (SELECT users.buddy_id FROM users WHERE(users.id = custom_table_user_snapshots.user_id))             
        )
        OR 
        (approval_chains.approval_type = ? AND ctus_approval_chains.request_state = ? AND custom_table_user_snapshots.user_id = ?)"
        CustomField.where(company_id: params[:company_id], field_type: CustomField.field_types[:coworker]).try(:each) do |field|
          query += "OR 
          (approval_chains.approval_type = '#{ApprovalChain.approval_types[:coworker]}' AND ctus_approval_chains.request_state = '#{CtusApprovalChain.request_states[:requested]}' AND '{#{field.id}}' IN
              (SELECT approval_chains.approval_ids from approval_chains where approval_chains.id IN
                (SELECT ctus_approval_chains.approval_chain_id FROM ctus_approval_chains
                 WHERE(ctus_approval_chains.request_state = '#{CtusApprovalChain.request_states[:requested]}' AND ctus_approval_chains.custom_table_user_snapshot_id = custom_table_user_snapshots.id)
                 ORDER BY ctus_approval_chains.id ASC limit(1)
                )
              ) AND '#{params[:current_user_id]}' IN (SELECT coworker_id FROM custom_field_values WHERE(custom_table_user_snapshots.user_id = custom_field_values.user_id AND custom_field_values.custom_field_id = #{field.id}))
               
          )"
        end

        filter { |relation| relation.joins("LEFT JOIN ctus_approval_chains on ctus_approval_chains.custom_table_user_snapshot_id = custom_table_user_snapshots.id").joins("LEFT
         JOIN approval_chains on (approval_chains.approvable_id = custom_table_user_snapshots.id OR approval_chains.approvable_id = custom_table_user_snapshots.custom_table_id) AND (approval_chains.approvable_type = 'CustomTableUserSnapshot' OR approval_chains.approvable_type = 'CustomTable') AND
            ctus_approval_chains.approval_chain_id = approval_chains.id").where(query, ApprovalChain.approval_types[:manager], CtusApprovalChain.request_states[:requested], params[:current_user_id], params[:current_user_id], params[:current_user_id], params[:current_user_id],
            ApprovalChain.approval_types[:requestor_manager], CtusApprovalChain.request_states[:requested], params[:current_user_id], params[:current_user_id], params[:current_user_id], params[:current_user_id],
            ApprovalChain.approval_types[:person], CtusApprovalChain.request_states[:requested], "{#{params[:current_user_id]}}", CtusApprovalChain.request_states[:requested], 
            ApprovalChain.approval_types[:permission], CtusApprovalChain.request_states[:requested], params[:current_user_role], CtusApprovalChain.request_states[:requested], 
            ApprovalChain.approval_types[:coworker], CtusApprovalChain.request_states[:requested], CtusApprovalChain.request_states[:requested], params[:current_user_id],
            ApprovalChain.approval_types[:individual], CtusApprovalChain.request_states[:requested], params[:current_user_id]).select("DISTINCT ON (custom_table_user_snapshots.id) custom_table_user_snapshots.*")
          }
      end
    end
  end
end

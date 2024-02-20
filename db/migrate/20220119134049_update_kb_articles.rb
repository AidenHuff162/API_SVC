class UpdateKbArticles < ActiveRecord::Migration[5.1]
  def change
    updated_kb_links = {
      small_improvements: "https://kallidus.zendesk.com/hc/en-us/articles/360019470257", 
      learn_upon: "https://kallidus.zendesk.com/hc/en-us/articles/360019473957", 
      gusto: "https://kallidus.zendesk.com/hc/en-us/articles/360019689758", 
      namely: "https://kallidus.zendesk.com/hc/en-us/articles/360018774117", 
      lever: "https://kallidus.zendesk.com/hc/en-us/articles/360019469917", 
      paylocity: "https://kallidus.zendesk.com/hc/en-us/articles/360020673457",  
      paychex: "https://kallidus.zendesk.com/hc/en-us/articles/360018908418", 
      lattice: "https://kallidus.zendesk.com/hc/en-us/articles/360019611498", 
      peakon: "https://kallidus.zendesk.com/hc/en-us/articles/360019615698", 
      fifteen_five: "https://kallidus.zendesk.com/hc/en-us/articles/360019615618", 
      deputy: "https://kallidus.zendesk.com/hc/en-us/articles/360018774337", 
      trinet: "https://kallidus.zendesk.com/hc/en-us/articles/360018670517",
      lessonly: "https://kallidus.zendesk.com/hc/en-us/articles/360019473937"
    }

    IntegrationInventory.find_each do |integration|
      integration.update_columns(knowledge_base_url: updated_kb_links[integration.api_identifier.to_sym])
    end
  end
end

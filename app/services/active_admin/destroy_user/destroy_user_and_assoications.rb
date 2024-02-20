module ActiveAdmin
  module DestroyUser
    class DestroyUserAndAssoications
      attr_reader :user_id

      def initialize user_id        
        @user = User.with_deleted.find(user_id)
      end

      def perform
        destroy_all_user_associations
        set_nullify_to_all_user_associations
        @user.really_destroy!
      end

      private

      def destroy_all_user_associations
        destroy_has_many_associations
        destroy_has_one_associations
      end

      def destroy_has_many_associations
        find_associated_classes(:has_many, :destroy).each do |association|          
          if supports_soft_deletion?(association)            
            really_destroy_associated_objects(association)
          else
            records = @user.try(association.name)
            records.destroy_all if records.present?
          end
        end
      end

      def destroy_has_one_associations
        find_associated_classes(:has_one, :destroy).each do |association|
          records = association.class_name.constantize.unscope(where: :deleted_at).where(association.foreign_key => @user.id)          
          if supports_soft_deletion?(association)
            records.each do |record|
              record.really_destroy! 
            end
          else
            records.each do |record|
              record.destroy 
            end
          end
        end
      end

      def find_associated_classes(association, dependency) 
        User.reflect_on_all_associations(association).map{|a| a if a.options[:dependent] == dependency }.compact                
      end

      def set_nullify_to_all_user_associations
        set_nullify_to_has_many_associations
        set_nullify_to_has_one_associations           
      end

      def set_nullify_to_has_many_associations
        find_associated_classes(:has_many,:nullify).each do |association|
          if supports_soft_deletion?(association)
            nullify_associated_objects_including_soft_deleted(association)
          else
            records = @user.try(association.name)
            records.update_all(association.foreign_key=>nil) if records.present?            
          end 
        end
      end

      def set_nullify_to_has_one_associations
        find_associated_classes(:has_one,:nullify).each do |association|              
          records=association.class_name.constantize.unscope(where: :deleted_at).where(association.foreign_key=>@user.id)                    
          records.update_all(association.foreign_key=>nil) if records.present?
        end        
      end

      def really_destroy_associated_objects association
        records = @user.send(association.name).unscope(where: :deleted_at).to_a rescue []                
        records.each do |record|                    
          if(association.class_name=="AssignedPtoPolicy")
            record.skip_before_destroy_callback=true
          end
          record.really_destroy!
        end
      end

      def nullify_associated_objects_including_soft_deleted association
        if association.class_name.camelize=='PaperworkRequest'
         @user.try(association.name).unscope(where: :deleted_at).unscope(where: :state).each do |record|                    
          record.update_column(association.foreign_key,nil)
         end
        else
         @user.try(association.name).unscope(where: :deleted_at).each do |record|                    
          record.update_column(association.foreign_key,nil)
         end
        end
      end

      def supports_soft_deletion? association
        association.class_name.camelize.constantize.column_names.include? 'deleted_at'
      end
    end
  end
end
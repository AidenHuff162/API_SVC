class PaperworkPacketConnection < ApplicationRecord
  acts_as_paranoid
  belongs_to :connectable, :polymorphic => true
  belongs_to :paperwork_packet
end

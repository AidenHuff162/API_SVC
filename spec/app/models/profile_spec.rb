require 'rails_helper'
require 'cancan/matchers'

RSpec.describe Profile, type: :model do
  let(:company) { create(:company) }
  let(:sarah) { create(:user, company: company) }
  let(:nick) { create(:nick, company: company) }
  let(:peter) { create(:peter, company: company) }
  let(:tim) { create(:tim, company: company) }
  let(:employee) { create(:user, company: company) }

  describe 'Associations' do
    it { is_expected.to belong_to(:user)}
    it { is_expected.to have_many(:field_histories)}
  end

  describe 'ability' do
    let(:company2){ create(:company, subdomain: 'factoryhelper')}
    let(:sarah2) { create(:user, company: company2) }

    before do
      nick.reload
    end

    context 'should manage' do
      context 'if current user is account owner' do
        subject(:ability) { Ability.new(sarah) }

        context 'manages own profile' do
          it {should be_able_to(:manage, sarah.profile)}
        end

        context 'manages admin profile' do
          it {should be_able_to(:manage, peter.profile)}
        end

        context 'manages manager profile' do
          it {should be_able_to(:manage, nick.manager.profile)}
        end

        context 'manages employee profile' do
          it {should be_able_to(:manage, tim.profile)}
        end
      end

      context 'if current user is admin' do
        subject(:ability) { Ability.new(peter) }
        
        context 'manages own profile' do
          it {should be_able_to(:manage, peter.profile)}
        end
        
        context 'manages super admin profile' do
          it {should be_able_to(:manage, sarah.profile)}
        end
        
        context 'manages manager profile' do
          it {should be_able_to(:manage, nick.manager.profile)}
        end
        
        context 'manages employee profile' do
          it {should be_able_to(:manage, tim.profile)}
        end
      end

      context 'if current user is manager' do
        subject(:ability) { Ability.new(nick.manager) }

        context 'manages own profile' do
          it {should be_able_to(:manage, nick.manager.profile)}
        end

        context 'updates managed employee profile' do
          it {should be_able_to(:update, nick.profile)}
        end
      end

      context 'if current user is employee' do
        subject(:ability) { Ability.new(tim) }
        
        context 'manages own profile' do
          it {should be_able_to(:manage, tim.profile)}
        end
      end
    end

    context 'should not manage' do
      context 'if current user is account owner' do
        subject(:ability) { Ability.new(sarah) }

        context 'should not manage profile for other company' do
          it {should_not be_able_to(:manage, sarah2.profile)}
        end
      end

      context 'if current user is admin' do
        subject(:ability) { Ability.new(peter) }

        context 'should not manage profile for other company' do
          it {should_not be_able_to(:manage, sarah2.profile)}
        end
      end

      context 'if current user is manager' do
        subject(:ability) { Ability.new(nick.manager) }

        context 'should not manage profile for other company' do
          it {should_not be_able_to(:manage, sarah2.profile)}
        end

        context 'should not manage profile of super admin' do
          it {should_not be_able_to(:manage, sarah.profile)}
        end

        context 'should not manage profile of admin' do
          it {should_not be_able_to(:manage, peter.profile)}
        end

        context 'should not manage profile of employee not being managed' do
          it {should_not be_able_to(:manage, tim.profile)}
        end
      end
      
      context 'if current user is employee' do
        subject(:ability) { Ability.new(tim) }

        context 'should not manage profile for other company' do
          it {should_not be_able_to(:manage, sarah2.profile)}
        end

        context 'should not manage profile of super admin' do
          it {should_not be_able_to(:manage, sarah.profile)}
        end

        context 'should not manage profile of admin' do
          it {should_not be_able_to(:manage, peter.profile)}
        end

        context 'should not manage profile of manager' do
          it {should_not be_able_to(:manage, nick.manager.profile)}
        end

        context 'should not manage profile of other employee' do
          it {should_not be_able_to(:manage, nick.profile)}
        end
      end
    end
  end

  describe 'column specifications' do
    it { is_expected.to have_db_column(:about_you).of_type(:text).with_options(presence: true) }
    it { is_expected.to have_db_column(:facebook).of_type(:string).with_options(presence: true) }
    it { is_expected.to have_db_column(:twitter).of_type(:string).with_options(presence: true) }
    it { is_expected.to have_db_column(:linkedin).of_type(:string).with_options(presence: true) }
    it { is_expected.to have_db_column(:github).of_type(:string).with_options(presence: true) }
    it { is_expected.to have_db_column(:user_id).of_type(:integer).with_options(presence: true)  }
    
    it { is_expected.to have_db_index(:deleted_at) }
    it { is_expected.to have_db_index(:user_id) }
  end

  describe "attributes accessors" do
    subject { Profile.new }

    it "should check updating integration to be true" do
      subject.updating_integration = true
      expect(subject.updating_integration).to eq(true)
    end
  end

  describe 'callbacks' do
    before do
      User.current = sarah
      @profile = sarah.profile
    end

    context 'track changed fields if auditing fields are updated' do
      before do
        @profile.update(about_you: 'hello', facebook: 'fb_user', twitter: '@ser', linkedin: 'username', github: 'hello')
      end

      it 'creates field history for auditable fields' do
        expect(@profile.field_histories.size).to eq(5)
      end

      it 'creates field history with correct field changer' do
        field_changer_array = @profile.field_histories.map{|h| h.field_changer_id}.uniq
        expect(field_changer_array.to_sentence.to_i).to eq(sarah.id)
      end
    end

    context 'does not track changed fields if auditing fields are not updated' do
      before do
        @profile.update(about_you: nil, facebook: nil, twitter: nil, linkedin: nil, github: nil)
      end

      it 'creates field history for auditable fields' do
        expect(@profile.field_histories.size).to eq(0)
      end

      it 'creates field history with correct field changer' do
        field_changer_array = @profile.field_histories.map{|h| h.field_changer_id}.uniq
        expect(field_changer_array.to_sentence.to_i).to eq(0)
      end
    end
  end
  describe 'after auditable fields are updated' do
    let(:company){ create(:company) }
    let(:sarah){ create(:user, company: company) }
    before do
      User.current = sarah
      @profile = sarah.profile
      @profile.update(about_you: 'hello', facebook: 'fb_user', twitter: '@ser', linkedin: 'username', github: 'hello')
    end

    it 'creates field history for auditable fields' do
      expect(@profile.field_histories.size).to eq(5)
    end

    it 'creates field history with correct field changer' do
      field_changer_array = @profile.field_histories.map{|h| h.field_changer_id}.uniq
      expect(field_changer_array.to_sentence.to_i).to eq(sarah.id)
    end
  end
end

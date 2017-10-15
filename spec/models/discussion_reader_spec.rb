require 'rails_helper'

describe DiscussionReader do

  let(:user) { FactoryGirl.create :user }
  let(:other_user) { FactoryGirl.create :user }
  let(:group) { FactoryGirl.create :formal_group }
  let(:discussion) { FactoryGirl.create :discussion, group: group }
  let(:membership) { FactoryGirl.create :membership, user: user, group: group, volume: :normal }
  let(:reader) { DiscussionReader.for(user: user, discussion: discussion) }

  describe 'volume' do
    it 'can change its volume' do
      reader.set_volume! :loud
      expect(reader.reload.volume.to_sym).to eq :loud
    end

    it 'defaults to the memberships volume when nil' do
      expect(membership.volume).to eq reader.volume
    end
  end

  describe 'viewed!' do
    it 'publishes a simple serialized discussion' do
      expect(MessageChannelService).to receive(:publish)
      reader.viewed!(1)
    end
  end

  describe 'dismissed!' do
    it 'publishes a simple serialized discussion' do
      expect(MessageChannelService).to receive(:publish)
      reader.dismiss!
    end
  end

  describe 'viewed' do
    let(:older_item) { CommentService.create(comment: build(:comment, discussion: discussion, created_at: 5.days.ago), actor: user) }
    let(:newer_item) { CommentService.create(comment: build(:comment, discussion: discussion, created_at: 2.days.ago), actor: user) }
    before do
      group.add_member! user
      reader.update(last_read_at: 6.days.ago, read_items_count: 0)
    end

    it 'updates the counts correctly from existing last_read_at' do
      reader.viewed!([newer_item, older_item].map(&:sequence_id))
      expect(reader.read_items_count).to eq 2
      expect(reader.last_read_at > 1.minute.ago)
    end

    it 'updates the existing counts correctly' do
      reader.viewed!(newer_item.sequence_id)
      expect(reader.has_read?(older_item.sequence_id)).to be false
      expect(reader.has_read?(newer_item.sequence_id)).to be true
      expect(reader.read_items_count).to eq 1
    end

    it 'does not do anything for an old last_read_at' do
      reader.viewed!(older_item.sequence_id)
      expect(reader.read_items_count).to eq 1
      reader.viewed!(older_item.sequence_id)
      expect(reader.read_items_count).to eq 1
    end
  end

  describe "mark_as_read" do
    it 'creates a range' do
      reader.mark_as_read(1)
      expect(reader.read_sequence_id_ranges).to eq "1,1"
    end

    it 'extends a range' do
      reader.mark_as_read(1)
      reader.mark_as_read(2)
      expect(reader.read_sequence_id_ranges).to eq "1,2"
    end

    it 'extends a range' do
      reader.mark_as_read(1)
      reader.mark_as_read(2)
      reader.mark_as_read(3)
      expect(reader.read_sequence_id_ranges).to eq "1,3"
    end

    it 'handles complex' do
      reader.mark_as_read([1,1,2,3,6,7,8,10])
      expect(reader.read_sequence_id_ranges).to eq "1,3 6,8 10,10"
    end

    it 'ignores already marked as read' do
      reader.mark_as_read(1)
      reader.mark_as_read(1)
      expect(reader.read_sequence_id_ranges).to eq "1,1"
    end
  end
end
